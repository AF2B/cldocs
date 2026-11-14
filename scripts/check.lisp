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

(defparameter *project-systems* '("cldocs" "cldocs/tests")
  "Systems whose compilation must be free of warnings.")

(defvar *warnings* '()
  "Warnings collected while loading CLDocs, newest first.")

(defun project-file-p ()
  "Return true when the file being compiled or loaded belongs to this checkout.

Compiled files are cached under a path that embeds the source path, so the
checkout root is found inside the cache path as well."
  (let ((pathname (or *compile-file-truename* *load-truename*)))
    (and pathname
         (search (namestring *project-root*) (namestring pathname))
         t)))

(defun record-warning (condition)
  "Remember CONDITION when it comes from CLDocs code, and muffle it.

Warnings from third-party systems are not ours to fix and are only muffled.

- CONDITION: the WARNING or STYLE-WARNING being signalled."
  (when (project-file-p)
    (push (princ-to-string condition) *warnings*))
  (muffle-warning condition))

(defun install-dependencies ()
  "Download and compile third-party dependencies in a child SBCL.

Doing this in a separate process keeps their output out of this image, so the
forced load below sees only warnings caused by CLDocs itself."
  (uiop:run-program
   (list "sbcl" "--noinform" "--non-interactive"
         "--load" (namestring *quicklisp-setup*)
         "--eval" (format nil "(push ~S asdf:*central-registry*)"
                          *project-root*)
         "--eval" "(ql:quickload \"cldocs/tests\" :silent t)")
   :output nil
   :error-output *error-output*))

(defun main ()
  "Force-load CLDocs, run the tests and exit non-zero on any warning or failure."
  (install-dependencies)
  (load *quicklisp-setup*)
  (push *project-root* asdf:*central-registry*)
  (handler-bind ((warning #'record-warning))
    (asdf:load-system "cldocs/tests" :force *project-systems*))
  (when *warnings*
    (format *error-output* "~&~D warning(s) while loading:~%~{  - ~A~%~}"
            (length *warnings*) (reverse *warnings*))
    (uiop:quit 1))
  (format t "~&Load clean: 0 WARNING / 0 STYLE-WARNING.~%")
  (unless (asdf:test-system "cldocs")
    (uiop:quit 1)))

(main)
