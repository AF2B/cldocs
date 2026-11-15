;;;; web.lisp --- HTTP server: JSON API, sign-in and the static site.
;;;;
;;;; One Hunchentoot acceptor serves the generated site and the API from the
;;;; same origin, so the strict Content-Security-Policy can stay "self" and
;;;; cookies never travel cross-site. References: Hunchentoot manual,
;;;; OWASP cheat sheets for CSRF, session management and CSP.

(defpackage #:cldocs/web
  (:use #:cl)
  (:import-from #:cldocs/admin
                #:render-admin)
  (:import-from #:cldocs/auth
                #:authorize-url
                #:complete-oauth
                #:constant-time-string=
                #:create-session
                #:csrf-token
                #:destroy-session
                #:generate-token
                #:session-user
                #:token-shape-p
                #:+session-lifetime-seconds+)
  (:import-from #:cldocs/conditions
                #:contribution-not-found
                #:invalid-contribution
                #:invalid-contribution-detail
                #:invalid-contribution-reason
                #:not-allowed
                #:oauth-failure
                #:rate-limited
                #:rate-limited-retry-after
                #:unauthenticated)
  (:import-from #:cldocs/config
                #:config-base-url
                #:config-database-path
                #:config-dev-login-p
                #:config-moderator-p
                #:config-oauth-enabled-p
                #:config-port
                #:config-secure-cookies-p
                #:config-site-directory)
  (:import-from #:cldocs/contributions
                #:approved-contributions
                #:flag-contribution
                #:moderate-contribution
                #:pending-contributions
                #:recent-approved-contributions
                #:submit-contribution
                #:upsert-user
                #:user-id
                #:user-login
                #:user-moderator-p
                #:user-role
                #:withdraw-contribution)
  (:import-from #:cldocs/db
                #:close-database
                #:open-database)
  (:import-from #:cldocs/render
                #:render-message)
  (:import-from #:cldocs/store
                #:read-package-data
                #:stored-package-names)
  (:export #:app
           #:make-app
           #:start-server
           #:stop-server
           #:server-port
           #:server-app
           #:app-database
           #:app-config))

(in-package #:cldocs/web)

(defparameter *session-cookie* "cldocs_session"
  "Cookie holding the session token.")

(defparameter *state-cookie* "cldocs_oauth_state"
  "Cookie holding the OAuth anti-forgery state while GitHub is consulted.")

(defparameter *next-cookie* "cldocs_next"
  "Cookie remembering where to return after sign-in.")

(defparameter *state-lifetime-seconds* 600
  "How long an OAuth round trip may take.")

(defparameter *csrf-header* "X-CSRF-Token"
  "Header that carries the CSRF token on JSON requests.")

(defparameter *json-type* "application/json; charset=utf-8"
  "Content type of every API response.")

(defparameter *html-type* "text/html; charset=utf-8"
  "Content type of server-rendered pages.")

(defparameter *max-request-bytes* 16384
  "Largest request body accepted by the API.")

(defparameter *json-max-depth* 8
  "Deepest JSON nesting accepted in a request body.")

(defparameter *dev-login-pattern-length* 39
  "Longest GitHub login, also the cap for development logins.")

(defparameter *content-security-policy*
  (format nil "~{~A~^; ~}"
          '("default-src 'none'"
            "script-src 'self'"
            "style-src 'self'"
            "font-src 'self'"
            "img-src 'self' data:"
            "connect-src 'self'"
            "form-action 'self'"
            "frame-ancestors 'none'"
            "base-uri 'none'"))
  "Policy that only allows resources from the server's own origin.")

(defparameter *hsts-value* "max-age=31536000; includeSubDomains"
  "Strict-Transport-Security value, sent only over HTTPS.")

(defparameter *reason-statuses*
  '((:payload-too-large . 413)
    (:unsupported-media-type . 415))
  "HTTP status for rule violations that are not plain 400s.")

(defvar *app* nil
  "The APP serving the current request.")

(alexandria:define-constant +unix-epoch-offset+ 2208988800
  :test #'eql
  :documentation "Seconds between the universal time epoch (1900) and the Unix epoch (1970).")

(defstruct (app (:copier nil))
  "Everything a request handler needs.

- CONFIG: the validated CONFIG.
- DATABASE: the open DATABASE.
- KNOWN-SYMBOLS: table of (package . symbol) conses that have a page.
- CLOCK: function of no arguments returning the universal time."
  config
  database
  known-symbols
  (clock #'get-universal-time))

(defstruct (server (:copier nil))
  "A running server: the Hunchentoot acceptor and its APP."
  acceptor
  app)

(defclass app-acceptor (hunchentoot:acceptor)
  ((app :initarg :app :reader acceptor-app))
  (:documentation "Acceptor that dispatches every request to HANDLE-REQUEST."))

;;; Responses

(defun json-object (&rest keys-and-values)
  "Build a JSON object table from alternating string keys and values.

- KEYS-AND-VALUES: alternating key strings and values."
  (let ((table (make-hash-table :test #'equal)))
    (loop for (key value) on keys-and-values by #'cddr
          do (setf (gethash key table) value))
    table))

(defun respond (status content-type body)
  "Set the response STATUS and CONTENT-TYPE and return BODY.

- STATUS: an HTTP status code.
- CONTENT-TYPE: the response content type.
- BODY: the response body, a string."
  (setf (hunchentoot:return-code*) status
        (hunchentoot:content-type*) content-type)
  body)

(defun respond-json (data &key (status 200))
  "Send DATA as JSON with STATUS and no caching.

- DATA: a JSON-serialisable value built from tables, vectors and atoms.
- STATUS: the HTTP status code."
  (setf (hunchentoot:header-out :cache-control) "no-store")
  (respond status *json-type* (com.inuoe.jzon:stringify data)))

(defun respond-error (status code &optional detail)
  "Send a JSON error body.

- STATUS: the HTTP status code.
- CODE: a short machine readable error code.
- DETAIL: a human readable explanation, or NIL."
  (respond-json (json-object "error" code "detail" (or detail 'null)) :status status))

(defun respond-page (status title message)
  "Send a small HTML page with TITLE and MESSAGE.

- STATUS: the HTTP status code.
- TITLE: the page heading.
- MESSAGE: the explanation shown below it."
  (respond status *html-type* (render-message title message)))

(defun redirect (location &optional (status 303))
  "Redirect to the local path LOCATION.

- LOCATION: a path starting with a single slash.
- STATUS: the HTTP redirect status."
  (setf (hunchentoot:header-out :location) location
        (hunchentoot:return-code*) status)
  "")

(defun set-security-headers ()
  "Add the security headers every response carries."
  (setf (hunchentoot:header-out :content-security-policy) *content-security-policy*
        (hunchentoot:header-out :x-content-type-options) "nosniff"
        (hunchentoot:header-out :referrer-policy) "same-origin"
        (hunchentoot:header-out :x-frame-options) "DENY")
  (when (config-secure-cookies-p (app-config *app*))
    (setf (hunchentoot:header-out :strict-transport-security) *hsts-value*)))

;;; Cookies and sessions

(defun now ()
  "Return the current universal time according to the app clock."
  (funcall (app-clock *app*)))

(defun set-cookie (name value max-age)
  "Set the cookie NAME with the secure defaults.

- NAME: cookie name.
- VALUE: cookie value.
- MAX-AGE: lifetime in seconds."
  (hunchentoot:set-cookie name
                          :value value
                          :path "/"
                          :max-age max-age
                          :secure (config-secure-cookies-p (app-config *app*))
                          :http-only t
                          :same-site "Lax"))

(defun clear-cookie (name)
  "Expire the cookie NAME.

- NAME: cookie name."
  (set-cookie name "" 0))

(defun session-token ()
  "Return the session token sent by the browser, or NIL when absent or malformed."
  (let ((token (hunchentoot:cookie-in *session-cookie*)))
    (and (token-shape-p token) token)))

(defun current-user ()
  "Return the signed-in user plist for this request, or NIL."
  (let ((token (session-token)))
    (and token
         (session-user (app-database *app*) token (now)))))

(defun require-user ()
  "Return the signed-in user or signal UNAUTHENTICATED."
  (or (current-user)
      (error 'unauthenticated)))

(defun require-csrf (supplied)
  "Signal NOT-ALLOWED unless SUPPLIED matches the CSRF token of this session.

- SUPPLIED: the token sent by the client, or NIL."
  (let ((token (session-token)))
    (unless (and token
                 (constant-time-string= supplied (csrf-token token)))
      (error 'not-allowed :action "csrf"))))

(defun start-session (user)
  "Create a session for USER and send its cookie.

- USER: a user plist."
  (set-cookie *session-cookie*
              (create-session (app-database *app*) (user-id user) (now))
              +session-lifetime-seconds+))

;;; Request bodies

(defun reject (reason &optional detail)
  "Signal INVALID-CONTRIBUTION for REASON.

- REASON: a keyword naming the broken rule.
- DETAIL: a human readable explanation, or NIL."
  (error 'invalid-contribution :reason reason :detail detail))

(defun read-json-body ()
  "Return the parsed JSON object of the request body.

Signals INVALID-CONTRIBUTION for a wrong content type, a body over the size
limit, malformed JSON or anything that is not an object."
  (let ((type (hunchentoot:header-in* :content-type))
        (length (hunchentoot:header-in* :content-length)))
    (unless (and type (uiop:string-prefix-p "application/json" type))
      (reject :unsupported-media-type))
    (when (or (null length)
              (not (every #'digit-char-p length))
              (> (parse-integer length) *max-request-bytes*))
      (reject :payload-too-large))
    (let ((parsed (handler-case
                      (com.inuoe.jzon:parse (hunchentoot:raw-post-data :force-text t)
                                            :max-depth *json-max-depth*)
                    (error () (reject :bad-json)))))
      (unless (typep parsed 'hash-table)
        (reject :bad-json "expected a JSON object"))
      parsed)))

(defun json-string (object key)
  "Return the string stored under KEY in OBJECT, or NIL when it is not a string.

- OBJECT: a parsed JSON object.
- KEY: the member name."
  (let ((value (gethash key object)))
    (and (stringp value) value)))

(defun parse-kind (text)
  "Return the contribution kind keyword for TEXT, or NIL.

- TEXT: \"example\" or \"note\"."
  (cond ((equal text "example") :example)
        ((equal text "note") :note)))

;;; Handlers: API

(defun known-symbol-p (package symbol)
  "Return true when SYMBOL of PACKAGE has a documentation page.

- PACKAGE: package name, a string.
- SYMBOL: symbol name, a string."
  (and (gethash (cons package symbol) (app-known-symbols *app*)) t))

(defun handle-me ()
  "Report who is signed in and hand out the CSRF token."
  (let ((user (current-user))
        (token (session-token)))
    (respond-json
     (json-object "user"
                  (if user
                      (json-object "login" (user-login user)
                                   "role" (user-role user)
                                   "csrf" (csrf-token token))
                      'null)))))

(defun query-parameter (name)
  "Return the query-string parameter NAME, or NIL.

- NAME: the parameter name."
  (hunchentoot:get-parameter name))

(defun contribution-json (contribution)
  "Return the public JSON view of a contribution plist.

- CONTRIBUTION: a plist from the contributions layer."
  (json-object "id" (getf contribution :id)
               "kind" (getf contribution :kind)
               "body" (getf contribution :body)
               "author" (getf contribution :author)
               "created_at" (- (getf contribution :created-at) +unix-epoch-offset+)))

(defun handle-list-contributions ()
  "List the approved contributions of the symbol named in the query string."
  (let ((package (query-parameter "package"))
        (symbol (query-parameter "symbol")))
    (unless (and package symbol (known-symbol-p package symbol))
      (reject :unknown-symbol))
    (respond-json
     (map 'vector
          #'contribution-json
          (approved-contributions (app-database *app*) package symbol)))))

(defun handle-submit-contribution ()
  "Store a new pending contribution from the JSON request body."
  (let* ((user (require-user))
         (header (hunchentoot:header-in* :x-csrf-token)))
    (require-csrf header)
    (let* ((body (read-json-body))
           (id (submit-contribution (app-database *app*)
                                    :user-id (user-id user)
                                    :kind (parse-kind (json-string body "kind"))
                                    :package (json-string body "package")
                                    :symbol (json-string body "symbol")
                                    :body (json-string body "body")
                                    :terms-accepted (eq (gethash "terms" body) t)
                                    :known-symbol-p #'known-symbol-p
                                    :now (now))))
      (respond-json (json-object "id" id "status" "pending") :status 201))))

(defun json-id (body)
  "Return the integer under \"id\" in BODY or signal INVALID-CONTRIBUTION.

- BODY: a parsed JSON object."
  (let ((id (gethash "id" body)))
    (unless (integerp id)
      (reject :bad-id))
    id))

(defun handle-flag ()
  "Flag an approved contribution on behalf of the signed-in user."
  (let ((user (require-user)))
    (require-csrf (hunchentoot:header-in* :x-csrf-token))
    (let* ((body (read-json-body))
           (status (flag-contribution (app-database *app*)
                                      user
                                      (json-id body)
                                      (json-string body "reason")
                                      (now))))
      (respond-json (json-object "status" (string-downcase (symbol-name status)))))))

(defun handle-withdraw ()
  "Let the author withdraw their own contribution."
  (let ((user (require-user)))
    (require-csrf (hunchentoot:header-in* :x-csrf-token))
    (let ((status (withdraw-contribution (app-database *app*)
                                         user
                                         (json-id (read-json-body))
                                         (now))))
      (respond-json (json-object "status" (string-downcase (symbol-name status)))))))

(defun handle-logout ()
  "End the session; the CSRF token travels in the header."
  (require-user)
  (require-csrf (hunchentoot:header-in* :x-csrf-token))
  (destroy-session (app-database *app*) (session-token))
  (clear-cookie *session-cookie*)
  (respond-json (json-object "ok" t)))

;;; Handlers: sign-in

(defun safe-next-path (text)
  "Return TEXT when it is a local path that cannot redirect off-site, else \"/\".

- TEXT: the requested return path, or NIL."
  (if (and (stringp text)
           (plusp (length text))
           (char= (char text 0) #\/)
           (not (find-if (lambda (char) (member char '(#\\ #\Newline #\Return #\Tab)))
                         text))
           (not (uiop:string-prefix-p "//" text)))
      text
      "/"))

(defun handle-login ()
  "Send the browser to GitHub, remembering where to come back to."
  (let ((config (app-config *app*)))
    (if (not (config-oauth-enabled-p config))
        (respond-page 503 "Sign-in unavailable"
                      "GitHub sign-in is not configured on this server.")
        (let ((state (generate-token)))
          (set-cookie *state-cookie* state *state-lifetime-seconds*)
          (set-cookie *next-cookie*
                      (safe-next-path (query-parameter "next"))
                      *state-lifetime-seconds*)
          (redirect (authorize-url config state) 302)))))

(defun sign-in (github-id login)
  "Create or refresh the user for a verified GitHub account and start a session.

- GITHUB-ID: the numeric GitHub account id.
- LOGIN: the GitHub login."
  (let ((user (upsert-user (app-database *app*)
                           github-id
                           login
                           (config-moderator-p (app-config *app*) login)
                           (now))))
    (start-session user)
    user))

(defun finish-sign-in ()
  "Clear the OAuth cookies and return to the page the user came from."
  (let ((next (safe-next-path (hunchentoot:cookie-in *next-cookie*))))
    (clear-cookie *state-cookie*)
    (clear-cookie *next-cookie*)
    (redirect next)))

(defun handle-oauth-callback ()
  "Complete the GitHub sign-in after the user approved the application."
  (let ((expected (hunchentoot:cookie-in *state-cookie*))
        (supplied (query-parameter "state")))
    (if (not (and (token-shape-p expected)
                  (constant-time-string= expected supplied)))
        (respond-page 400 "Sign-in failed" "The sign-in request could not be verified.")
        (multiple-value-bind (github-id login)
            (complete-oauth (app-config *app*) (query-parameter "code"))
          (sign-in github-id login)
          (finish-sign-in)))))

(defun development-github-id (login)
  "Return a negative, stable fake account id derived from LOGIN.

Negative ids can never collide with real GitHub accounts.

- LOGIN: the development login."
  (- (1+ (ironclad:octets-to-integer
          (subseq (ironclad:digest-sequence
                   :sha256 (sb-ext:string-to-octets login :external-format :utf-8))
                  0 6)))))

(defun development-login-p (text)
  "Return true when TEXT is an acceptable development login.

- TEXT: the requested login, or NIL."
  (and (stringp text)
       (<= 1 (length text) *dev-login-pattern-length*)
       (every (lambda (char) (or (alphanumericp char) (char= char #\-))) text)))

(defun handle-dev-login ()
  "Sign in as a fake user; only available when explicitly enabled on localhost."
  (let ((login (query-parameter "as")))
    (cond ((not (config-dev-login-p (app-config *app*)))
           (respond-page 404 "Not found" "No such page."))
          ((not (development-login-p login))
           (respond-page 400 "Bad request" "Give a login with ?as=name."))
          (t
           (sign-in (development-github-id login) login)
           (redirect (safe-next-path (query-parameter "next")))))))

;;; Static site

(defparameter *index-file* "index.html"
  "File served for directory paths.")

(defparameter *not-found-file* "404.html"
  "Page served with a 404 status for unknown paths.")

(defun safe-relative-path (path)
  "Return PATH without its leading slash, or NIL when it could escape the site.

- PATH: the request path."
  (cond ((find-if (lambda (char) (member char '(#\% #\\ #\Nul))) path) nil)
        ((search ".." path) nil)
        (t (let ((relative (string-left-trim "/" path)))
             (if (or (string= relative "")
                     (char= (char relative (1- (length relative))) #\/))
                 (concatenate 'string relative *index-file*)
                 relative)))))

(defun site-file (relative)
  "Return the existing file RELATIVE below the site directory, or NIL.

- RELATIVE: a safe relative path."
  (let ((root (config-site-directory (app-config *app*))))
    (when (and root relative)
      (let ((file (probe-file (merge-pathnames relative root))))
        (and file
             (pathname-name file)
             (uiop:subpathp file (truename root))
             file)))))

(defun serve-static (path)
  "Serve the generated site file for PATH, or a 404 page.

- PATH: the request path."
  (let ((file (site-file (safe-relative-path path))))
    (cond (file
           (hunchentoot:handle-static-file file))
          (t
           (let ((missing (site-file *not-found-file*)))
             (setf (hunchentoot:return-code*) 404)
             (if missing
                 (hunchentoot:handle-static-file missing)
                 (respond-page 404 "Not found" "No such page.")))))))

;;; Routing

(defun form-parameter (name)
  "Return the POST form parameter NAME, or NIL.

- NAME: the parameter name."
  (hunchentoot:post-parameter name))

(defun handle-admin ()
  "Show the moderation queue to moderators and refuse everyone else."
  (let ((user (current-user)))
    (cond ((null user)
           (respond-page 401 "Sign in required" "Sign in with a moderator account."))
          ((not (user-moderator-p user))
           (respond-page 403 "Forbidden" "This page is for moderators."))
          (t
           (respond 200 *html-type*
                    (render-admin (pending-contributions (app-database *app*))
                                  (recent-approved-contributions (app-database *app*))
                                  (csrf-token (session-token))))))))

(defun parse-action (text)
  "Return the moderation action keyword named by TEXT, or NIL.

- TEXT: \"approve\", \"reject\" or \"hide\"."
  (cond ((equal text "approve") :approve)
        ((equal text "reject") :reject)
        ((equal text "hide") :hide)))

(defun handle-admin-moderate ()
  "Apply a moderation decision posted from the admin page."
  (let ((user (require-user)))
    (require-csrf (form-parameter "csrf"))
    (let ((id (ignore-errors (parse-integer (or (form-parameter "id") "")))))
      (handler-case
          (progn
            (unless id
              (reject :bad-id))
            (moderate-contribution (app-database *app*)
                                   user
                                   id
                                   (parse-action (form-parameter "action"))
                                   (form-parameter "reason")
                                   (now))
            (redirect "/admin"))
        (invalid-contribution (condition)
          (respond-page 400 "Cannot do that"
                        (format nil "Rejected: ~(~A~)."
                                (invalid-contribution-reason condition))))))))

(defparameter *routes*
  '((:get "/api/me" handle-me)
    (:get "/api/contributions" handle-list-contributions)
    (:post "/api/contributions" handle-submit-contribution)
    (:post "/api/flags" handle-flag)
    (:post "/api/withdraw" handle-withdraw)
    (:post "/api/logout" handle-logout)
    (:get "/login" handle-login)
    (:get "/oauth/callback" handle-oauth-callback)
    (:get "/dev-login" handle-dev-login)
    (:get "/admin" handle-admin)
    (:post "/admin/moderate" handle-admin-moderate)
    (:get "/healthz" handle-health))
  "Exact-match routes: method, path and handler function name.")

(defun handle-health ()
  "Answer the liveness probe."
  (respond 200 "text/plain; charset=utf-8" "ok"))

(defun find-route (method path)
  "Return the handler for METHOD and PATH, :METHOD-NOT-ALLOWED or NIL.

- METHOD: :GET, :POST and so on.
- PATH: the request path."
  (let ((matching (remove-if-not (lambda (route) (string= path (second route)))
                                 *routes*)))
    (cond ((null matching) nil)
          ((find method matching :key #'first)
           (third (find method matching :key #'first)))
          (t :method-not-allowed))))

(defun reason-status (reason)
  "Return the HTTP status for the contribution rule REASON.

- REASON: a keyword."
  (or (cdr (assoc reason *reason-statuses*)) 400))

(defun call-with-error-mapping (function)
  "Call FUNCTION and turn expected failures into HTTP responses.

Unexpected errors are logged without request data and reported as a plain 500.

- FUNCTION: a function of no arguments returning the response body."
  (handler-case (funcall function)
    (invalid-contribution (condition)
      (respond-error (reason-status (invalid-contribution-reason condition))
                     (string-downcase (symbol-name (invalid-contribution-reason condition)))
                     (invalid-contribution-detail condition)))
    (unauthenticated ()
      (respond-error 401 "unauthenticated" "Sign in to do this."))
    (not-allowed ()
      (respond-error 403 "forbidden" "You are not allowed to do this."))
    (contribution-not-found ()
      (respond-error 404 "not-found" "No such contribution."))
    (rate-limited (condition)
      (setf (hunchentoot:header-out :retry-after)
            (princ-to-string (rate-limited-retry-after condition)))
      (respond-error 429 "rate-limited" "Too many submissions, try again later."))
    (oauth-failure ()
      (respond-page 502 "Sign-in failed" "GitHub could not confirm your identity."))
    (error (condition)
      (hunchentoot:log-message* :error "unhandled ~A" (type-of condition))
      (respond-error 500 "internal-error" nil))))

(defun dispatch ()
  "Route the current request to its handler and return the response body."
  (let* ((method (hunchentoot:request-method*))
         (path (hunchentoot:script-name*))
         (route (find-route method path)))
    (cond ((eq route :method-not-allowed)
           (respond-error 405 "method-not-allowed" nil))
          (route
           (funcall route))
          ((and (member method '(:get :head))
                (not (uiop:string-prefix-p "/api/" path)))
           (serve-static path))
          (t
           (respond-error 404 "not-found" nil)))))

(defun handle-request ()
  "Handle the current request with security headers and error mapping."
  (set-security-headers)
  (call-with-error-mapping #'dispatch))

(defmethod hunchentoot:acceptor-dispatch-request ((acceptor app-acceptor) request)
  (declare (ignore request))
  (let ((*app* (acceptor-app acceptor)))
    (handle-request)))

;;; Lifecycle

(defun load-known-symbols ()
  "Return a table of every (package . symbol) pair that has a documentation page."
  (let ((table (make-hash-table :test #'equal)))
    (dolist (package-name (stored-package-names) table)
      (dolist (definition (read-package-data package-name))
        (setf (gethash (cons package-name (cldocs/definition:definition-name definition))
                       table)
              t)))))

(defun start-server (config
                     &key
                       (clock #'get-universal-time))
  "Open the database, start listening and return a SERVER.

- CONFIG: a validated CONFIG.
- CLOCK: function of no arguments returning the universal time; tests replace it."
  (let* ((app (make-app :config config
                        :database (open-database (config-database-path config))
                        :known-symbols (load-known-symbols)
                        :clock clock))
         (acceptor (make-instance 'app-acceptor
                                  :app app
                                  :address "127.0.0.1"
                                  :port (config-port config)
                                  :access-log-destination nil
                                  :message-log-destination *error-output*)))
    (hunchentoot:start acceptor)
    (make-server :acceptor acceptor :app app)))

(defun stop-server (server)
  "Stop listening and close the database.

- SERVER: a SERVER returned by START-SERVER."
  (hunchentoot:stop (server-acceptor server))
  (close-database (app-database (server-app server))))

(defun server-port (server)
  "Return the TCP port SERVER actually listens on.

- SERVER: a SERVER returned by START-SERVER."
  (hunchentoot:acceptor-port (server-acceptor server)))
