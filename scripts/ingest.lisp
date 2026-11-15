;;;; ingest.lisp --- Regenerate the versioned data set from this SBCL image.
;;;; Usage: sbcl --non-interactive --load scripts/ingest.lisp

(defpackage #:cldocs/scripts/ingest
  (:use #:cl))

(in-package #:cldocs/scripts/ingest)

(defparameter *quicklisp-setup* (merge-pathnames "quicklisp/setup.lisp"
                                                 (user-homedir-pathname))
  "Location of the Quicklisp client setup file.")

(defparameter *project-root*
  (uiop:pathname-parent-directory-pathname
   (uiop:pathname-directory-pathname *load-truename*))
  "Root directory of the CLDocs checkout.")

;;; Later forms name CLDocs symbols, so the system is loaded before they are read.
(load *quicklisp-setup*)
(push *project-root* asdf:*central-registry*)
(ql:quickload "cldocs" :silent t)

(defun main ()
  "Ingest COMMON-LISP, then every configured library, and report each outcome."
  (format t "~&COMMON-LISP: ~D definitions~%" (cldocs/ingest:ingest-common-lisp))
  (loop for (system . status) in (cldocs/ingest:ingest-configured-systems *project-root*)
        do (format t "~&~A: ~(~A~)~%" system status)))

(main)
