;;;; check.lisp --- Load CLDocs and run its tests; fail on any warning.
;;;; Usage: sbcl --non-interactive --load scripts/check.lisp

(defpackage #:cldocs/scripts/check
  (:use #:cl))

(in-package #:cldocs/scripts/check)

(defparameter *quicklisp-setup* (merge-pathnames "quicklisp/setup.lisp"
                                                 (user-homedir-pathname))
  "Location of the Quicklisp client setup file.")

(defparameter *project-root*
  (uiop:pathname-parent-directory-pathname
   (uiop:pathname-directory-pathname *load-truename*))
  "Root directory of the CLDocs checkout.")

(defvar *warnings* '()
  "Warnings collected while loading CLDocs, newest first.")

(defun record-warning (condition)
  "Remember CONDITION and muffle it.

- CONDITION: the WARNING or STYLE-WARNING being signalled."
  (push (princ-to-string condition) *warnings*)
  (muffle-warning condition))

(defun main ()
  "Force-load CLDocs, run the tests and exit non-zero on any warning or failure."
  (load *quicklisp-setup*)
  (push *project-root* asdf:*central-registry*)
  (ql:quickload '("alexandria" "fiveam") :silent t)
  (handler-bind ((warning #'record-warning))
    (asdf:load-system "cldocs" :force t)
    (asdf:load-system "cldocs/tests" :force t))
  (when *warnings*
    (format *error-output* "~&~D warning(s) while loading:~%~{  - ~A~%~}"
            (length *warnings*) (reverse *warnings*))
    (uiop:quit 1))
  (format t "~&Load clean: 0 WARNING / 0 STYLE-WARNING.~%")
  (unless (asdf:test-system "cldocs")
    (uiop:quit 1)))

(main)
