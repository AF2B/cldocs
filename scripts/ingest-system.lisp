;;;; ingest-system.lisp --- Child image: ingest the one system named by CLDOCS_SYSTEM.
;;;; Started by CLDOCS/INGEST:INGEST-CONFIGURED-SYSTEMS; not meant to be run by hand.
;;;; Exit status: 0 ingested, 3 skipped on purpose, 1 failed.

;;; A bare SBCL has no ASDF/UIOP until it is required; later forms name UIOP symbols.
(require :asdf)

(defpackage #:cldocs/scripts/ingest-system
  (:use #:cl))

(in-package #:cldocs/scripts/ingest-system)

(defparameter *quicklisp-setup* (merge-pathnames "quicklisp/setup.lisp"
                                                 (user-homedir-pathname))
  "Location of the Quicklisp client setup file.")

(defparameter *project-root*
  (uiop:pathname-parent-directory-pathname
   (uiop:pathname-directory-pathname *load-truename*))
  "Root directory of the CLDocs checkout.")

(defparameter *system-variable* "CLDOCS_SYSTEM"
  "Environment variable naming the system to ingest.")

(defparameter *failure-exit-code* 1
  "Exit status when ingestion fails.")

;;; Later forms name CLDocs symbols, so the system is loaded before they are read.
(load *quicklisp-setup*)
(push *project-root* asdf:*central-registry*)
(ql:quickload "cldocs" :silent t)

(defun packages-of (system-name)
  "Return the packages configured for SYSTEM-NAME, or exit when it is unlisted.

- SYSTEM-NAME: the ASDF system name, a string."
  (let ((entry (find system-name
                     (cldocs/systems:configured-systems)
                     :key (lambda (plist) (getf plist :system))
                     :test #'string=)))
    (unless entry
      (format *error-output* "~&System ~A is not listed in data/systems.sexp.~%"
              system-name)
      (uiop:quit *failure-exit-code*))
    (getf entry :packages)))

(defun skip-and-report (condition)
  "Report CONDITION and take the SKIP-SYSTEM restart.

- CONDITION: the CLDOCS-ERROR that makes the system unusable."
  (format *error-output* "~&Skipping: ~A~%" condition)
  (invoke-restart 'cldocs/ingest:skip-system))

(defun main ()
  "Ingest the configured system and exit with a status describing the outcome."
  (let* ((system-name (uiop:getenv *system-variable*))
         (written (handler-bind ((cldocs/conditions:cldocs-error #'skip-and-report))
                    (cldocs/ingest:ingest-system system-name
                                                 (packages-of system-name)))))
    (cond (written
           (format t "~&~A: ~D definitions~%" system-name written)
           (uiop:quit 0))
          (t
           (uiop:quit cldocs/ingest:+skipped-exit-code+)))))

(main)
