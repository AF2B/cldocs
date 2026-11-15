;;;; config.lisp --- Server configuration, read from the environment.
;;;;
;;;; Secrets (the GitHub client secret) live only in environment variables,
;;;; never in files and never in logs.

(defpackage #:cldocs/config
  (:use #:cl)
  (:import-from #:cldocs/conditions
                #:insecure-configuration)
  (:export #:config
           #:make-config
           #:config-base-url
           #:config-port
           #:config-database-path
           #:config-site-directory
           #:config-github-client-id
           #:config-github-client-secret
           #:config-moderators
           #:config-dev-login-p
           #:config-oauth-enabled-p
           #:config-secure-cookies-p
           #:config-moderator-p
           #:validate-config
           #:config-from-environment))

(in-package #:cldocs/config)

(defparameter *loopback-prefixes*
  '("http://localhost" "http://127.0.0.1" "http://[::1]")
  "Base URL prefixes that identify a purely local server.")

(defparameter *https-prefix* "https://"
  "Base URL prefix that turns on the Secure cookie attribute.")

(defparameter *default-base-url* "http://localhost:8080"
  "Public address of the server when none is configured.")

(defparameter *default-port* 8080
  "Port the server listens on when none is configured.")

(defparameter *default-database* "cldocs.sqlite"
  "SQLite file used when none is configured.")

(defparameter *environment-names*
  '(:base-url "CLDOCS_BASE_URL"
    :port "CLDOCS_PORT"
    :database "CLDOCS_DATABASE"
    :site "CLDOCS_SITE_DIRECTORY"
    :client-id "CLDOCS_GITHUB_CLIENT_ID"
    :client-secret "CLDOCS_GITHUB_CLIENT_SECRET"
    :moderators "CLDOCS_MODERATORS"
    :dev-login "CLDOCS_DEV_LOGIN")
  "Environment variable that carries each setting.")

(defstruct (config (:copier nil))
  "Everything the server needs to start.

- BASE-URL: public address, used to build the OAuth callback.
- PORT: TCP port to listen on.
- DATABASE-PATH: SQLite file, or \":memory:\".
- SITE-DIRECTORY: generated static site served at /, or NIL.
- GITHUB-CLIENT-ID / GITHUB-CLIENT-SECRET: OAuth application credentials.
- MODERATORS: GitHub logins allowed to moderate.
- DEV-LOGIN-P: enables /dev-login; only valid for a loopback base URL."
  (base-url *default-base-url* :type string)
  (port *default-port* :type (integer 0 65535))
  (database-path *default-database* :type string)
  (site-directory nil :type (or null pathname))
  (github-client-id nil :type (or null string))
  (github-client-secret nil :type (or null string))
  (moderators '() :type list)
  (dev-login-p nil :type boolean))

(defun config-oauth-enabled-p (config)
  "Return true when both GitHub OAuth credentials are configured.

- CONFIG: a CONFIG."
  (and (config-github-client-id config)
       (config-github-client-secret config)
       t))

(defun config-secure-cookies-p (config)
  "Return true when cookies must carry the Secure attribute.

- CONFIG: a CONFIG."
  (uiop:string-prefix-p *https-prefix* (config-base-url config)))

(defun config-moderator-p (config login)
  "Return true when LOGIN is listed as a moderator, ignoring letter case.

- CONFIG: a CONFIG.
- LOGIN: a GitHub login, a string."
  (and (member login (config-moderators config) :test #'string-equal) t))

(defun loopback-url-p (url)
  "Return true when URL points at this machine only.

- URL: a base URL, a string."
  (some (lambda (prefix) (uiop:string-prefix-p prefix url))
        *loopback-prefixes*))

(defun validate-config (config)
  "Return CONFIG when it is safe to run, otherwise signal INSECURE-CONFIGURATION.

- CONFIG: a CONFIG."
  (when (and (config-dev-login-p config)
             (not (loopback-url-p (config-base-url config))))
    (error 'insecure-configuration
           :reason "dev login is only allowed with a localhost base URL"))
  (when (and (or (config-github-client-id config) (config-github-client-secret config))
             (not (config-oauth-enabled-p config)))
    (error 'insecure-configuration
           :reason "GitHub client id and secret must be set together"))
  config)

(defun environment (key)
  "Return the non-empty value of the environment setting KEY, or NIL.

- KEY: a keyword from *ENVIRONMENT-NAMES*."
  (let ((value (uiop:getenv (getf *environment-names* key))))
    (and value (string/= value "") value)))

(defun split-logins (text)
  "Split the comma separated TEXT into trimmed, non-empty logins.

- TEXT: a string such as \"ada, grace\", or NIL."
  (when text
    (remove "" (mapcar (lambda (item) (string-trim " " item))
                       (uiop:split-string text :separator '(#\,)))
            :test #'string=)))

(defun config-from-environment ()
  "Build a validated CONFIG from the CLDOCS_* environment variables."
  (validate-config
   (make-config :base-url (or (environment :base-url) *default-base-url*)
                :port (if (environment :port)
                          (parse-integer (environment :port))
                          *default-port*)
                :database-path (or (environment :database) *default-database*)
                :site-directory (when (environment :site)
                                  (uiop:ensure-directory-pathname (environment :site)))
                :github-client-id (environment :client-id)
                :github-client-secret (environment :client-secret)
                :moderators (split-logins (environment :moderators))
                :dev-login-p (and (environment :dev-login) t))))
