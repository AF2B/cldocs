;;;; record-examples.lisp --- Run data/examples-src and store the results.
;;;; Usage: sbcl --non-interactive --load scripts/record-examples.lisp

(defpackage #:cldocs/scripts/record-examples
  (:use #:cl))

(in-package #:cldocs/scripts/record-examples)

(defparameter *quicklisp-setup* (merge-pathnames "quicklisp/setup.lisp"
                                                 (user-homedir-pathname))
  "Location of the Quicklisp client setup file.")

(defparameter *project-root*
  (uiop:pathname-parent-directory-pathname
   (uiop:pathname-directory-pathname *load-truename*))
  "Root directory of the CLDocs checkout.")

(defun packages ()
  "Return COMMON-LISP followed by every package of data/systems.sexp."
  (cons "COMMON-LISP"
        (loop for entry in (uiop:symbol-call '#:cldocs/systems '#:configured-systems)
              append (getf entry :packages))))

(defun main ()
  "Record every configured package and report how many examples were written."
  (load *quicklisp-setup*)
  (push *project-root* asdf:*central-registry*)
  (uiop:symbol-call '#:ql '#:quickload "cldocs" :silent t)
  (dolist (package (packages))
    (format t "~&~A: ~D examples recorded~%"
            package
            (uiop:symbol-call '#:cldocs/examples '#:record-examples package))))

(main)
