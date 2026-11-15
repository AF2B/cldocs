;;;; server-test.lisp --- Integration tests against a real Hunchentoot instance.

(defpackage #:cldocs/tests/server
  (:use #:cl #:fiveam)
  (:export #:call-with-server
           #:http
           #:response-status
           #:response-headers
           #:response-body
           #:sign-in))

(in-package #:cldocs/tests/server)

(def-suite* server-suite :in cldocs/tests/suite:all-tests)

(defvar *now* cldocs/tests/contributions:+start-time+
  "Clock value seen by the server under test.")

(defparameter *test-base-url* "http://localhost:8080"
  "Public address the test configuration claims; the real port is ephemeral.")

(defparameter *anonymous-error* "unauthenticated"
  "Error code the API reports to signed-out users.")

(defstruct (response (:copier nil))
  "What the test client received.

- STATUS: the HTTP status code.
- HEADERS: a hash table of lowercase header names.
- BODY: the response body as a string."
  status
  headers
  body)

;;; Fixtures

(defun call-with-server (function &key (dev-login t) oauth)
  "Run FUNCTION with a server on an ephemeral port, then stop it.

- FUNCTION: a function of one argument, the SERVER.
- DEV-LOGIN: true to enable /dev-login.
- OAUTH: true to configure fake GitHub OAuth credentials."
  (let* ((config (cldocs/config:make-config
                  :base-url *test-base-url*
                  :port 0
                  :database-path ":memory:"
                  :site-directory (cldocs/tests/site:built-site)
                  :moderators '("mod")
                  :dev-login-p dev-login
                  :github-client-id (when oauth "test-client")
                  :github-client-secret (when oauth "test-secret")))
         (server (cldocs/web:start-server config :clock (lambda () *now*))))
    (setf *now* cldocs/tests/contributions:+start-time+)
    (unwind-protect (funcall function server)
      (cldocs/web:stop-server server))))

(defun http (server
             method
             path
             &key
               cookies
               headers
               content)
  "Send a request to SERVER without following redirects.

- SERVER: the running SERVER.
- METHOD: :GET, :POST and so on.
- PATH: the request path including any query string.
- COOKIES: an alist of cookie names and values to send.
- HEADERS: an alist of extra request headers.
- CONTENT: the request body string, or NIL."
  (let ((url (format nil "http://127.0.0.1:~D~A" (cldocs/web:server-port server) path))
        (all-headers (append headers
                             (when cookies
                               (list (cons "Cookie"
                                           (format nil "~{~A~^; ~}"
                                                   (loop for (name . value) in cookies
                                                         collect (format nil "~A=~A" name value)))))))))
    (handler-case
        (multiple-value-bind (body status response-headers)
            (dex:request url
                         :method method
                         :headers all-headers
                         :content content
                         :max-redirects 0
                         :force-string t)
          (make-response :status status :headers response-headers :body body))
      (dex:http-request-failed (failure)
        (make-response :status (dex:response-status failure)
                       :headers (dex:response-headers failure)
                       :body (dex:response-body failure))))))

(defun header (response name)
  "Return the value of the header NAME of RESPONSE, or NIL.

- RESPONSE: a RESPONSE.
- NAME: a lowercase header name."
  (gethash name (response-headers response)))

(defun set-cookie-lines (response)
  "Return every Set-Cookie header value of RESPONSE as a list of strings.

- RESPONSE: a RESPONSE."
  (let ((value (header response "set-cookie")))
    (cond ((null value) '())
          ((listp value) value)
          (t (uiop:split-string value :separator '(#\Newline))))))

(defun merge-cookies (cookies response)
  "Return COOKIES updated with the Set-Cookie headers of RESPONSE.

Cookies expired by the server are dropped.

- COOKIES: an alist of names and values.
- RESPONSE: a RESPONSE."
  (let ((jar (copy-alist cookies)))
    (dolist (line (set-cookie-lines response) jar)
      (let* ((pair (subseq line 0 (position #\; line)))
             (separator (position #\= pair))
             (name (subseq pair 0 separator))
             (value (subseq pair (1+ separator))))
        (setf jar (remove name jar :key #'car :test #'string=))
        (when (and (string/= value "") (not (search "Max-Age=0" line)))
          (push (cons name value) jar))))))

(defun json-of (response)
  "Parse the body of RESPONSE as JSON.

- RESPONSE: a RESPONSE with a JSON body."
  (com.inuoe.jzon:parse (response-body response)))

(defun json-text (&rest keys-and-values)
  "Serialise alternating string keys and values as a JSON object.

- KEYS-AND-VALUES: alternating key strings and values."
  (let ((table (make-hash-table :test #'equal)))
    (loop for (key value) on keys-and-values by #'cddr
          do (setf (gethash key table) value))
    (com.inuoe.jzon:stringify table)))

(defun sign-in (server login)
  "Sign in as LOGIN through /dev-login.

Returns the cookie alist and the CSRF token as two values.

- SERVER: the running SERVER.
- LOGIN: the development login."
  (let* ((response (http server :get (format nil "/dev-login?as=~A" login)))
         (cookies (merge-cookies '() response))
         (me (json-of (http server :get "/api/me" :cookies cookies)))
         (csrf (gethash "csrf" (gethash "user" me))))
    (values cookies csrf)))

(defun json-headers (&optional csrf)
  "Return request headers for a JSON POST, with the CSRF header when given.

- CSRF: the CSRF token, or NIL."
  (append '(("Content-Type" . "application/json"))
          (when csrf (list (cons "X-CSRF-Token" csrf)))))

(defun contribution-json (&key
                            (body "(car '(a b))")
                            (kind "example")
                            (symbol "CAR")
                            (terms t))
  "Return the JSON text of a submission for COMMON-LISP:CAR by default.

- BODY: the contribution text.
- KIND: \"example\" or \"note\".
- SYMBOL: the documented symbol name.
- TERMS: whether the terms were accepted."
  (json-text "package" "COMMON-LISP"
             "symbol" symbol
             "kind" kind
             "body" body
             "terms" terms))

(defun submit (server
               cookies
               csrf
               &rest arguments)
  "Post a contribution as the signed-in user and return the RESPONSE.

- SERVER: the running SERVER.
- COOKIES: the session cookies.
- CSRF: the CSRF token.
- ARGUMENTS: keyword arguments for CONTRIBUTION-JSON."
  (http server :post "/api/contributions"
        :cookies cookies
        :headers (json-headers csrf)
        :content (apply #'contribution-json arguments)))

(defun approve-all-pending (server)
  "Approve every pending contribution directly in the database.

- SERVER: the running SERVER."
  (let* ((database (cldocs/web:app-database (cldocs/web:server-app server)))
         (moderator (cldocs/tests/contributions:make-test-user database "mod" :moderator t)))
    (dolist (item (cldocs/contributions:pending-contributions database))
      (cldocs/contributions:moderate-contribution
       database moderator (getf item :id) :approve nil *now*))))

(defun listed-bodies (server)
  "Return the bodies of the approved contributions the API lists for CAR.

- SERVER: the running SERVER."
  (map 'list
       (lambda (item) (gethash "body" item))
       (json-of (http server :get "/api/contributions?package=COMMON-LISP&symbol=CAR"))))

;;; Static site and headers

(test every-response-carries-the-security-headers
  (call-with-server
   (lambda (server)
     (dolist (path '("/healthz" "/" "/nope/" "/api/me" "/api/nope" "/assets/site.css"))
       (let ((response (http server :get path)))
         (let ((policy (header response "content-security-policy")))
           (is (search "default-src 'none'" policy) "CSP missing on ~A" path)
           (is (not (search "unsafe-inline" policy)))
           (is (not (search "unsafe-eval" policy))))
         (is (string= "nosniff" (header response "x-content-type-options")))
         (is (string= "DENY" (header response "x-frame-options")))
         (is (string= "same-origin" (header response "referrer-policy"))))))))

(test the-generated-site-is-served-at-the-root
  (call-with-server
   (lambda (server)
     (is (= 200 (response-status (http server :get "/"))))
     (let ((page (http server :get "/sym/common-lisp/car/")))
       (is (= 200 (response-status page)))
       (is (search "text/html" (header page "content-type")))
       (is (search "(car list)" (response-body page))))
     (is (search "text/css" (header (http server :get "/assets/site.css") "content-type")))
     (is (string= "ok" (response-body (http server :get "/healthz")))))))

(test unknown-paths-get-the-404-page-with-a-404-status
  (call-with-server
   (lambda (server)
     (let ((response (http server :get "/no/such/page/")))
       (is (= 404 (response-status response)))
       (is (search "Not found" (response-body response)))))))

(test path-traversal-never-leaves-the-site-directory
  (call-with-server
   (lambda (server)
     (dolist (path '("/%2e%2e/%2e%2e/etc/passwd" "/..%2f..%2fetc/passwd"
                     "/assets/%2e%2e/%2e%2e/%2e%2e/etc/passwd" "/a%00b"))
       (let ((response (http server :get path)))
         (is (= 404 (response-status response)) "~A answered ~A" path (response-status response))
         (is (not (search "root:" (response-body response)))))))))

(test api-routes-report-unknown-paths-and-wrong-methods-as-json
  (call-with-server
   (lambda (server)
     (let ((missing (http server :get "/api/nope")))
       (is (= 404 (response-status missing)))
       (is (string= "not-found" (gethash "error" (json-of missing)))))
     (let ((wrong (http server :post "/api/me")))
       (is (= 405 (response-status wrong)))))))

;;; Anonymous access

(test anonymous-visitors-see-no-user-and-cannot-submit
  (call-with-server
   (lambda (server)
     (is (eq 'null (gethash "user" (json-of (http server :get "/api/me")))))
     (let ((response (http server :post "/api/contributions"
                           :headers (json-headers)
                           :content (contribution-json))))
       (is (= 401 (response-status response)))
       (is (string= *anonymous-error* (gethash "error" (json-of response))))))))

;;; Sign-in

(test dev-login-creates-a-hardened-session
  (call-with-server
   (lambda (server)
     (let* ((response (http server :get "/dev-login?as=ada&next=/sym/common-lisp/car/"))
            (line (first (set-cookie-lines response))))
       (is (= 303 (response-status response)))
       (is (string= "/sym/common-lisp/car/" (header response "location")))
       (is (search "HttpOnly" line))
       (is (search "SameSite=Lax" line))
       (is (not (search "Secure" line)))
       (multiple-value-bind (cookies csrf) (sign-in server "ada")
         (is (stringp csrf))
         (let ((user (gethash "user" (json-of (http server :get "/api/me" :cookies cookies)))))
           (is (string= "ada" (gethash "login" user)))
           (is (string= "member" (gethash "role" user)))))))))

(test configured-moderators-get-the-moderator-role
  (call-with-server
   (lambda (server)
     (let ((cookies (sign-in server "mod")))
       (is (string= "moderator"
                    (gethash "role" (gethash "user"
                                             (json-of (http server :get "/api/me"
                                                            :cookies cookies))))))))))

(test dev-login-is-absent-unless-enabled
  (call-with-server
   (lambda (server)
     (is (= 404 (response-status (http server :get "/dev-login?as=ada")))))
   :dev-login nil))

(test dev-login-rejects-odd-names-and-offsite-redirects
  (call-with-server
   (lambda (server)
     (is (= 400 (response-status (http server :get "/dev-login?as=bad%20name"))))
     (is (= 400 (response-status (http server :get "/dev-login"))))
     (dolist (next '("//evil.example" "https://evil.example" "/ok%0d%0aSet-Cookie:x=y"))
       (let ((response (http server :get (format nil "/dev-login?as=ada&next=~A" next))))
         (is (= 303 (response-status response)))
         (is (string= "/" (header response "location"))
             "~A redirected to ~A" next (header response "location")))))))

(test sessions-expire-with-the-clock
  (call-with-server
   (lambda (server)
     (let ((cookies (sign-in server "ada")))
       (is (not (eq 'null (gethash "user" (json-of (http server :get "/api/me" :cookies cookies))))))
       (incf *now* (1+ cldocs/auth:+session-lifetime-seconds+))
       (is (eq 'null (gethash "user" (json-of (http server :get "/api/me" :cookies cookies)))))))))

(test forged-or-malformed-session-cookies-are-ignored
  (call-with-server
   (lambda (server)
     (dolist (value (list (make-string 64 :initial-element #\a) "nonsense" "'; DROP TABLE users;--"))
       (is (eq 'null (gethash "user"
                              (json-of (http server :get "/api/me"
                                             :cookies (list (cons "cldocs_session" value)))))))))))

(test logout-needs-the-csrf-token-and-ends-the-session
  (call-with-server
   (lambda (server)
     (multiple-value-bind (cookies csrf) (sign-in server "ada")
       (is (= 403 (response-status (http server :post "/api/logout"
                                         :cookies cookies
                                         :headers (json-headers)
                                         :content "{}"))))
       (let ((response (http server :post "/api/logout"
                             :cookies cookies
                             :headers (json-headers csrf)
                             :content "{}")))
         (is (= 200 (response-status response)))
         (is (eq 'null (gethash "user" (json-of (http server :get "/api/me" :cookies cookies))))))))))

;;; OAuth

(defun call-with-fake-github (function
                              &key
                                (id 77)
                                (login "octo"))
  "Call FUNCTION with the GitHub fetchers replaced by fakes, restoring them afterwards.

The server runs in other threads, so the global values are replaced rather
than rebound.

- FUNCTION: a function of no arguments.
- ID: account id the fake profile reports.
- LOGIN: login the fake profile reports."
  (let ((old-token cldocs/auth:*github-token-fetcher*)
        (old-user cldocs/auth:*github-user-fetcher*))
    (setf cldocs/auth:*github-token-fetcher* (lambda (config code)
                                               (declare (ignore config code))
                                               "fake-token")
          cldocs/auth:*github-user-fetcher* (lambda (token)
                                              (declare (ignore token))
                                              (values id login)))
    (unwind-protect (funcall function)
      (setf cldocs/auth:*github-token-fetcher* old-token
            cldocs/auth:*github-user-fetcher* old-user))))

(test login-redirects-to-github-with-a-state-cookie
  (call-with-server
   (lambda (server)
     (let* ((response (http server :get "/login?next=/sym/common-lisp/car/"))
            (location (header response "location"))
            (cookies (merge-cookies '() response)))
       (is (= 302 (response-status response)))
       (is (uiop:string-prefix-p "https://github.com/login/oauth/authorize?" location))
       (is (search "client_id=test-client" location))
       (is (not (search "test-secret" location)))
       (is (assoc "cldocs_oauth_state" cookies :test #'string=))
       (is (search (cdr (assoc "cldocs_oauth_state" cookies :test #'string=)) location))))
   :oauth t))

(test login-explains-itself-when-oauth-is-not-configured
  (call-with-server
   (lambda (server)
     (is (= 503 (response-status (http server :get "/login")))))))

(test callback-completes-the-sign-in-with-a-matching-state
  (call-with-fake-github
   (lambda ()
     (call-with-server
      (lambda (server)
        (let* ((start (http server :get "/login?next=/sym/common-lisp/car/"))
               (cookies (merge-cookies '() start))
               (state (cdr (assoc "cldocs_oauth_state" cookies :test #'string=)))
               (done (http server :get (format nil "/oauth/callback?code=abc123&state=~A" state)
                           :cookies cookies))
               (session (merge-cookies cookies done)))
          (is (= 303 (response-status done)))
          (is (string= "/sym/common-lisp/car/" (header done "location")))
          (let ((user (gethash "user" (json-of (http server :get "/api/me" :cookies session)))))
            (is (string= "mod" (gethash "login" user)))
            (is (string= "moderator" (gethash "role" user))))
          (is (null (assoc "cldocs_oauth_state" session :test #'string=)))))
      :oauth t))
   :id 77
   :login "mod"))

(test callback-refuses-a-missing-or-wrong-state
  (call-with-fake-github
   (lambda ()
     (call-with-server
      (lambda (server)
        (let* ((start (http server :get "/login"))
               (cookies (merge-cookies '() start)))
          (is (= 400 (response-status (http server :get "/oauth/callback?code=abc123&state=wrong"
                                            :cookies cookies))))
          (is (= 400 (response-status (http server :get "/oauth/callback?code=abc123"
                                            :cookies cookies))))
          (is (= 400 (response-status (http server :get "/oauth/callback?code=abc123&state=nope"))))
          (is (eq 'null (gethash "user" (json-of (http server :get "/api/me" :cookies cookies)))))))
      :oauth t))))

(test callback-reports-github-failures-without-leaking-details
  (let ((old cldocs/auth:*github-token-fetcher*))
    (setf cldocs/auth:*github-token-fetcher*
          (lambda (config code)
            (declare (ignore config code))
            (error 'cldocs/conditions:oauth-failure :reason "secret-internal-detail")))
    (unwind-protect
         (call-with-server
          (lambda (server)
            (let* ((start (http server :get "/login"))
                   (cookies (merge-cookies '() start))
                   (state (cdr (assoc "cldocs_oauth_state" cookies :test #'string=)))
                   (response (http server :get (format nil "/oauth/callback?code=abc&state=~A" state)
                                   :cookies cookies)))
              (is (= 502 (response-status response)))
              (is (not (search "secret-internal-detail" (response-body response))))))
          :oauth t)
      (setf cldocs/auth:*github-token-fetcher* old))))

;;; Contributions

(test submissions-need-csrf-json-and-an-accepted-schema
  (call-with-server
   (lambda (server)
     (multiple-value-bind (cookies csrf) (sign-in server "ada")
       (is (= 403 (response-status (http server :post "/api/contributions"
                                         :cookies cookies
                                         :headers (json-headers)
                                         :content (contribution-json)))))
       (is (= 403 (response-status (http server :post "/api/contributions"
                                         :cookies cookies
                                         :headers (json-headers (make-string 64 :initial-element #\0))
                                         :content (contribution-json)))))
       (is (= 415 (response-status (http server :post "/api/contributions"
                                         :cookies cookies
                                         :headers (list (cons "Content-Type" "text/plain")
                                                        (cons "X-CSRF-Token" csrf))
                                         :content (contribution-json)))))
       (is (= 400 (response-status (http server :post "/api/contributions"
                                         :cookies cookies
                                         :headers (json-headers csrf)
                                         :content "{not json"))))
       (is (= 400 (response-status (http server :post "/api/contributions"
                                         :cookies cookies
                                         :headers (json-headers csrf)
                                         :content "[1,2,3]"))))
       (is (= 413 (response-status (http server :post "/api/contributions"
                                         :cookies cookies
                                         :headers (json-headers csrf)
                                         :content (contribution-json
                                                   :body (make-string 20000
                                                                      :initial-element #\a))))))))))

(test valid-submissions-wait-for-moderation-before-appearing
  (call-with-server
   (lambda (server)
     (multiple-value-bind (cookies csrf) (sign-in server "ada")
       (let ((response (submit server cookies csrf)))
         (is (= 201 (response-status response)))
         (is (string= "pending" (gethash "status" (json-of response)))))
       (is (null (listed-bodies server)))
       (approve-all-pending server)
       (is (equal '("(car '(a b))") (listed-bodies server)))
       (let ((item (first (coerce (json-of (http server :get
                                                 "/api/contributions?package=COMMON-LISP&symbol=CAR"))
                                  'list))))
         (is (string= "ada" (gethash "author" item)))
         (is (string= "example" (gethash "kind" item)))
         (is (integerp (gethash "created_at" item)))
         (is (< (gethash "created_at" item) 3000000000)))))))

(test content-rules-surface-as-400s-with-a-code
  (call-with-server
   (lambda (server)
     (multiple-value-bind (cookies csrf) (sign-in server "ada")
       (flet ((code (&rest arguments)
                (let ((response (apply #'submit server cookies csrf arguments)))
                  (list (response-status response) (gethash "error" (json-of response))))))
         (is (equal '(400 "unknown-symbol") (code :symbol "NOT-A-SYMBOL")))
         (is (equal '(400 "terms-not-accepted") (code :terms nil)))
         (is (equal '(400 "body-empty") (code :body "")))
         (is (equal '(400 "unknown-kind") (code :kind "video"))))))))

(test script-payloads-are-stored-and-served-only-as-json-data
  (call-with-server
   (lambda (server)
     (multiple-value-bind (cookies csrf) (sign-in server "ada")
       (let ((payload "<script>alert(1)</script><img src=x onerror=alert(2)>"))
         (is (= 201 (response-status (submit server cookies csrf :body payload :kind "note"))))
         (approve-all-pending server)
         (let ((response (http server :get "/api/contributions?package=COMMON-LISP&symbol=CAR")))
           (is (search "application/json" (header response "content-type")))
           (is (equal (list payload) (listed-bodies server)))
           (is (string= "nosniff" (header response "x-content-type-options")))))))))

(test the-api-refuses-unknown-symbols-when-listing
  (call-with-server
   (lambda (server)
     (is (= 400 (response-status (http server :get "/api/contributions?package=X&symbol=Y"))))
     (is (= 400 (response-status (http server :get "/api/contributions")))))))

(test submission-quota-answers-429-with-retry-after
  (call-with-server
   (lambda (server)
     (multiple-value-bind (cookies csrf) (sign-in server "ada")
       (dotimes (count cldocs/contributions:+max-submissions-per-window+)
         (is (= 201 (response-status (submit server cookies csrf)))))
       (let ((response (submit server cookies csrf)))
         (is (= 429 (response-status response)))
         (is (plusp (parse-integer (header response "retry-after")))))
       (incf *now* (+ cldocs/contributions:+rate-window-seconds+ 1))
       (is (= 201 (response-status (submit server cookies csrf))))))))

(test flagging-and-withdrawing-go-through-csrf-protected-endpoints
  (call-with-server
   (lambda (server)
     (multiple-value-bind (author-cookies author-csrf) (sign-in server "ada")
       (let ((id (gethash "id" (json-of (submit server author-cookies author-csrf)))))
         (approve-all-pending server)
         (multiple-value-bind (flagger-cookies flagger-csrf) (sign-in server "eve")
           (is (= 403 (response-status (http server :post "/api/flags"
                                             :cookies flagger-cookies
                                             :headers (json-headers)
                                             :content (json-text "id" id "reason" "spam")))))
           (is (= 200 (response-status (http server :post "/api/flags"
                                             :cookies flagger-cookies
                                             :headers (json-headers flagger-csrf)
                                             :content (json-text "id" id "reason" "spam")))))
           (is (= 403 (response-status (http server :post "/api/withdraw"
                                             :cookies flagger-cookies
                                             :headers (json-headers flagger-csrf)
                                             :content (json-text "id" id)))))
           (is (= 400 (response-status (http server :post "/api/flags"
                                             :cookies flagger-cookies
                                             :headers (json-headers flagger-csrf)
                                             :content (json-text "id" "one" "reason" "x"))))))
         (is (= 200 (response-status (http server :post "/api/withdraw"
                                           :cookies author-cookies
                                           :headers (json-headers author-csrf)
                                           :content (json-text "id" id)))))
         (is (null (listed-bodies server)))
         (is (= 404 (response-status (http server :post "/api/withdraw"
                                           :cookies author-cookies
                                           :headers (json-headers author-csrf)
                                           :content (json-text "id" 99999))))))))))
