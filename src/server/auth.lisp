;;;; auth.lisp --- Sessions, CSRF tokens and the GitHub OAuth exchange.
;;;;
;;;; Session tokens are random and only their SHA-256 digest is stored, so a
;;;; leaked database cannot be replayed as cookies. OAuth requests no scopes:
;;;; CLDocs only learns the public numeric id and login of the account.
;;;; Reference: GitHub docs, "Authorizing OAuth apps".

(defpackage #:cldocs/auth
  (:use #:cl)
  (:import-from #:cldocs/conditions
                #:oauth-failure)
  (:import-from #:cldocs/config
                #:config-base-url
                #:config-github-client-id
                #:config-github-client-secret)
  (:import-from #:cldocs/db
                #:db-execute
                #:db-insert
                #:db-row)
  (:export #:+session-lifetime-seconds+
           #:*github-token-fetcher*
           #:*github-user-fetcher*
           #:generate-token
           #:token-shape-p
           #:token-hash
           #:constant-time-string=
           #:create-session
           #:session-user
           #:destroy-session
           #:csrf-token
           #:authorize-url
           #:callback-url
           #:complete-oauth))

(in-package #:cldocs/auth)

(alexandria:define-constant +session-lifetime-seconds+ 604800
  :test #'eql
  :documentation "How long a session stays valid, seven days.")

(defparameter *token-bytes* 32
  "Random bytes in a session or state token.")

(defparameter *token-hex-length* 64
  "Length of a token written as hexadecimal text.")

(defparameter *csrf-suffix* ":csrf"
  "Text mixed into the session digest to derive its CSRF token.")

(defparameter *callback-path* "/oauth/callback"
  "Path GitHub redirects back to after authorisation.")

(defparameter *authorize-endpoint* "https://github.com/login/oauth/authorize"
  "Where users are sent to approve the OAuth application.")

(defparameter *token-endpoint* "https://github.com/login/oauth/access_token"
  "Where an authorisation code is exchanged for an access token.")

(defparameter *user-endpoint* "https://api.github.com/user"
  "Where the signed-in account's public profile is read.")

(defparameter *http-timeout-seconds* 10
  "Connect and read timeout for calls to GitHub.")

(defparameter *max-code-length* 200
  "Longest authorisation code accepted from the callback.")

(defun generate-token ()
  "Return a new unguessable token as 64 lowercase hexadecimal characters."
  (ironclad:byte-array-to-hex-string (ironclad:random-data *token-bytes*)))

(defun token-shape-p (text)
  "Return true when TEXT looks like a token produced by GENERATE-TOKEN.

- TEXT: a string from a cookie or form, or NIL."
  (and (stringp text)
       (= (length text) *token-hex-length*)
       (every (lambda (char) (digit-char-p char 16)) text)
       (string= text (string-downcase text))))

(defun token-hash (token)
  "Return the SHA-256 digest of TOKEN as lowercase hexadecimal text.

- TOKEN: a string that satisfies TOKEN-SHAPE-P."
  (ironclad:byte-array-to-hex-string
   (ironclad:digest-sequence :sha256 (ironclad:ascii-string-to-byte-array token))))

(defun constant-time-string= (left right)
  "Compare two strings without leaking where they first differ.

- LEFT: a string, or NIL.
- RIGHT: a string, or NIL."
  (and (stringp left)
       (stringp right)
       (let ((a (sb-ext:string-to-octets left :external-format :utf-8))
             (b (sb-ext:string-to-octets right :external-format :utf-8)))
         (and (= (length a) (length b))
              (ironclad:constant-time-equal a b)))))

;;; Sessions

(defun create-session (database user-id now)
  "Start a session for USER-ID and return its secret token.

Expired sessions are purged as a side effect.

- DATABASE: a DATABASE.
- USER-ID: the signed-in user.
- NOW: the current universal time."
  (let ((token (generate-token)))
    (db-execute database "DELETE FROM sessions WHERE expires_at <= ?" now)
    (db-insert database
               "INSERT INTO sessions (token_hash, user_id, expires_at) VALUES (?, ?, ?)"
               (token-hash token) user-id (+ now +session-lifetime-seconds+))
    token))

(defun session-user (database token now)
  "Return the user plist owning the live session TOKEN, or NIL.

- DATABASE: a DATABASE.
- TOKEN: the cookie value, or NIL.
- NOW: the current universal time."
  (when (token-shape-p token)
    (let ((row (db-row database
                       "SELECT u.id, u.github_id, u.login, u.role
                          FROM sessions s JOIN users u ON u.id = s.user_id
                         WHERE s.token_hash = ? AND s.expires_at > ?"
                       (token-hash token) now)))
      (when row
        (destructuring-bind (id github-id login role) row
          (list :id id :github-id github-id :login login :role role))))))

(defun destroy-session (database token)
  "End the session TOKEN; unknown tokens are ignored.

- DATABASE: a DATABASE.
- TOKEN: the cookie value, or NIL."
  (when (token-shape-p token)
    (db-execute database "DELETE FROM sessions WHERE token_hash = ?" (token-hash token))))

(defun csrf-token (session-token)
  "Return the CSRF token bound to SESSION-TOKEN.

It can only be computed by someone who holds the session cookie.

- SESSION-TOKEN: the cookie value, a string satisfying TOKEN-SHAPE-P."
  (ironclad:byte-array-to-hex-string
   (ironclad:digest-sequence
    :sha256
    (ironclad:ascii-string-to-byte-array
     (concatenate 'string (token-hash session-token) *csrf-suffix*)))))

;;; GitHub OAuth

(defun callback-url (config)
  "Return the absolute OAuth callback URL of this server.

- CONFIG: a CONFIG."
  (concatenate 'string (string-right-trim "/" (config-base-url config)) *callback-path*))

(defun authorize-url (config state)
  "Return the GitHub URL that starts the sign-in with the anti-forgery STATE.

- CONFIG: a CONFIG with OAuth credentials.
- STATE: the random state token also kept in a cookie."
  (format nil "~A?client_id=~A&redirect_uri=~A&state=~A"
          *authorize-endpoint*
          (hunchentoot:url-encode (config-github-client-id config))
          (hunchentoot:url-encode (callback-url config))
          (hunchentoot:url-encode state)))

(defun fail (reason)
  "Signal OAUTH-FAILURE for REASON.

- REASON: a short explanation without secrets."
  (error 'oauth-failure :reason reason))

(defun fetch-access-token (config code)
  "Exchange the authorisation CODE for an access token through GitHub.

- CONFIG: a CONFIG with OAuth credentials.
- CODE: the authorisation code from the callback."
  (let* ((body (handler-case
                   (dex:post *token-endpoint*
                             :headers '(("Accept" . "application/json"))
                             :content (list (cons "client_id" (config-github-client-id config))
                                            (cons "client_secret" (config-github-client-secret config))
                                            (cons "code" code)
                                            (cons "redirect_uri" (callback-url config)))
                             :connect-timeout *http-timeout-seconds*
                             :read-timeout *http-timeout-seconds*)
                 (error () (fail "token request failed"))))
         (token (gethash "access_token" (com.inuoe.jzon:parse body))))
    (unless (stringp token)
      (fail "no access token in the response"))
    token))

(defun fetch-github-user (access-token)
  "Read the public profile of the account that owns ACCESS-TOKEN.

Returns the numeric account id and the login as two values.

- ACCESS-TOKEN: an OAuth access token."
  (let* ((body (handler-case
                   (dex:get *user-endpoint*
                            :headers (list (cons "Accept" "application/vnd.github+json")
                                           (cons "Authorization"
                                                 (format nil "Bearer ~A" access-token)))
                            :connect-timeout *http-timeout-seconds*
                            :read-timeout *http-timeout-seconds*)
                 (error () (fail "profile request failed"))))
         (profile (com.inuoe.jzon:parse body))
         (id (gethash "id" profile))
         (login (gethash "login" profile)))
    (unless (and (integerp id) (stringp login))
      (fail "unexpected profile response"))
    (values id login)))

(defvar *github-token-fetcher* #'fetch-access-token
  "Function of a CONFIG and a code that returns an access token; replaced in tests.")

(defvar *github-user-fetcher* #'fetch-github-user
  "Function of an access token that returns the account id and login; replaced in tests.")

(defun complete-oauth (config code)
  "Finish the sign-in for the authorisation CODE and return the account id and login.

Signals OAUTH-FAILURE when GitHub refuses or answers unexpectedly.

- CONFIG: a CONFIG with OAuth credentials.
- CODE: the authorisation code from the callback."
  (unless (and (stringp code)
               (plusp (length code))
               (<= (length code) *max-code-length*)
               (every #'alphanumericp code))
    (fail "malformed authorisation code"))
  (funcall *github-user-fetcher*
           (funcall *github-token-fetcher* config code)))
