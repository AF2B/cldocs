;;;; auth-test.lisp --- Tests for configuration, sessions, CSRF and OAuth plumbing.

(defpackage #:cldocs/tests/auth
  (:use #:cl #:fiveam))

(in-package #:cldocs/tests/auth)

(def-suite* auth-suite :in cldocs/tests/suite:all-tests)

(defun oauth-config ()
  "Return a config with OAuth credentials for tests."
  (cldocs/config:make-config :base-url "https://docs.example"
                             :github-client-id "client-id"
                             :github-client-secret "client-secret"))

;;; Configuration

(test dev-login-is-refused-away-from-localhost
  (signals cldocs/conditions:insecure-configuration
    (cldocs/config:validate-config
     (cldocs/config:make-config :base-url "https://docs.example" :dev-login-p t)))
  (is (cldocs/config:validate-config
       (cldocs/config:make-config :base-url "http://localhost:8080" :dev-login-p t))))

(test oauth-credentials-must-come-as-a-pair
  (signals cldocs/conditions:insecure-configuration
    (cldocs/config:validate-config
     (cldocs/config:make-config :github-client-id "only-the-id")))
  (is (cldocs/config:validate-config (oauth-config))))

(test https-base-urls-turn-on-secure-cookies
  (is (cldocs/config:config-secure-cookies-p (oauth-config)))
  (is (not (cldocs/config:config-secure-cookies-p
            (cldocs/config:make-config :base-url "http://localhost:8080")))))

(test moderator-lookup-ignores-case
  (let ((config (cldocs/config:make-config :moderators '("Ada" "grace"))))
    (is (cldocs/config:config-moderator-p config "ada"))
    (is (cldocs/config:config-moderator-p config "GRACE"))
    (is (not (cldocs/config:config-moderator-p config "eve")))))

;;; Tokens and sessions

(test tokens-are-random-hex-of-the-expected-shape
  (let ((a (cldocs/auth:generate-token))
        (b (cldocs/auth:generate-token)))
    (is (cldocs/auth:token-shape-p a))
    (is (string/= a b))
    (is (= 64 (length a)))))

(test malformed-tokens-are-rejected-before-touching-the-database
  (dolist (bad (list nil "" "short" (make-string 64 :initial-element #\Z)
                     (make-string 64 :initial-element #\A) 42))
    (is (not (cldocs/auth:token-shape-p bad)))))

(test sessions-live-expire-and-can-be-destroyed
  (cldocs/tests/contributions:call-with-memory-database
   (lambda (database)
     (let* ((now cldocs/tests/contributions:+start-time+)
            (user (cldocs/tests/contributions:make-test-user database "ada"))
            (token (cldocs/auth:create-session database (cldocs/contributions:user-id user) now)))
       (is (string= "ada" (cldocs/contributions:user-login
                           (cldocs/auth:session-user database token (1+ now)))))
       (is (null (cldocs/auth:session-user
                  database token (+ now cldocs/auth:+session-lifetime-seconds+ 1))))
       (is (null (cldocs/auth:session-user database (cldocs/auth:generate-token) now)))
       (cldocs/auth:destroy-session database token)
       (is (null (cldocs/auth:session-user database token (1+ now))))))))

(test only-digests-of-session-tokens-are-stored
  (cldocs/tests/contributions:call-with-memory-database
   (lambda (database)
     (let* ((user (cldocs/tests/contributions:make-test-user database "ada"))
            (token (cldocs/auth:create-session
                    database
                    (cldocs/contributions:user-id user)
                    cldocs/tests/contributions:+start-time+))
            (stored (first (cldocs/db:db-row database "SELECT token_hash FROM sessions"))))
       (is (string/= token stored))
       (is (string= (cldocs/auth:token-hash token) stored))))))

(test csrf-tokens-are-bound-to-the-session
  (let ((a (cldocs/auth:generate-token))
        (b (cldocs/auth:generate-token)))
    (is (string= (cldocs/auth:csrf-token a) (cldocs/auth:csrf-token a)))
    (is (string/= (cldocs/auth:csrf-token a) (cldocs/auth:csrf-token b)))
    (is (string/= a (cldocs/auth:csrf-token a)))))

(test constant-time-comparison-handles-mismatches-and-non-strings
  (is (cldocs/auth:constant-time-string= "abc" "abc"))
  (is (not (cldocs/auth:constant-time-string= "abc" "abd")))
  (is (not (cldocs/auth:constant-time-string= "abc" "abcd")))
  (is (not (cldocs/auth:constant-time-string= nil "abc")))
  (is (not (cldocs/auth:constant-time-string= "abc" nil))))

;;; OAuth

(test authorize-url-carries-client-callback-and-encoded-state
  (let ((url (cldocs/auth:authorize-url (oauth-config) "a b&c")))
    (is (uiop:string-prefix-p "https://github.com/login/oauth/authorize?" url))
    (is (search "client_id=client-id" url))
    (is (search "redirect_uri=https%3A%2F%2Fdocs.example%2Foauth%2Fcallback" url))
    (is (search "state=a%20b%26c" url))
    (is (not (search "client-secret" url)))))

(test oauth-completion-uses-the-injected-fetchers
  (let ((cldocs/auth:*github-token-fetcher* (lambda (config code)
                                              (declare (ignore config))
                                              (format nil "token-for-~A" code)))
        (cldocs/auth:*github-user-fetcher* (lambda (token)
                                             (values 7 (format nil "user-of-~A" token)))))
    (multiple-value-bind (id login) (cldocs/auth:complete-oauth (oauth-config) "abc123")
      (is (= 7 id))
      (is (string= "user-of-token-for-abc123" login)))))

(test malformed-authorisation-codes-never-reach-github
  (let* ((called nil)
         (cldocs/auth:*github-token-fetcher* (lambda (config code)
                                               (declare (ignore config code))
                                               (setf called t)
                                               "token")))
    (dolist (bad (list nil "" "has space" "semi;colon" (make-string 201 :initial-element #\a)))
      (signals cldocs/conditions:oauth-failure
        (cldocs/auth:complete-oauth (oauth-config) bad)))
    (is (not called))))
