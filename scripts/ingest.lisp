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

(defun main ()
  "Ingest every configured data set and report what was written."
  (load *quicklisp-setup*)
  (push *project-root* asdf:*central-registry*)
  (ql:quickload "cldocs" :silent t)
  (format t "~&COMMON-LISP: ~D definitions~%"
          (uiop:symbol-call '#:cldocs/ingest '#:ingest-common-lisp)))

(main)
