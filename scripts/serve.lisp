;;;; serve.lisp --- Run the CLDocs server (site + community API).
;;;; Usage: sbcl --non-interactive --load scripts/serve.lisp
;;;; Configuration comes from CLDOCS_* environment variables, see
;;;; src/server/config.lisp. Without CLDOCS_SITE_DIRECTORY it serves build/site/.

(defpackage #:cldocs/scripts/serve
  (:use #:cl))

(in-package #:cldocs/scripts/serve)

(defparameter *quicklisp-setup* (merge-pathnames "quicklisp/setup.lisp"
                                                 (user-homedir-pathname))
  "Location of the Quicklisp client setup file.")

(defparameter *project-root*
  (uiop:pathname-parent-directory-pathname
   (uiop:pathname-directory-pathname *load-truename*))
  "Root directory of the CLDocs checkout.")

(defparameter *default-site* "build/site/"
  "Site directory below the project root when none is configured.")

;;; Later forms name CLDocs symbols, so the system is loaded before they are read.
(load *quicklisp-setup*)
(push *project-root* asdf:*central-registry*)
(ql:quickload "cldocs/server" :silent t)

(defun main ()
  "Start the server and sleep forever."
  (let* ((config (cldocs/config:config-from-environment))
         (site (or (cldocs/config:config-site-directory config)
                   (merge-pathnames *default-site* *project-root*))))
    (setf (cldocs/config:config-site-directory config) site)
    (let ((server (cldocs/web:start-server config)))
      (format t "~&CLDocs listening on http://127.0.0.1:~D/~%"
              (cldocs/web:server-port server))
      (loop (sleep 3600)))))

(main)
