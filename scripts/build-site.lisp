;;;; build-site.lisp --- Generate the static site into build/site/.
;;;; Usage: sbcl --non-interactive --load scripts/build-site.lisp
;;;; Set CLDOCS_OUTPUT to write somewhere else than build/site/.

;;; A bare SBCL has no ASDF/UIOP until it is required; later forms name UIOP symbols.
(require :asdf)

(defpackage #:cldocs/scripts/build-site
  (:use #:cl))

(in-package #:cldocs/scripts/build-site)

(defparameter *quicklisp-setup* (merge-pathnames "quicklisp/setup.lisp"
                                                 (user-homedir-pathname))
  "Location of the Quicklisp client setup file.")

(defparameter *project-root*
  (uiop:pathname-parent-directory-pathname
   (uiop:pathname-directory-pathname *load-truename*))
  "Root directory of the CLDocs checkout.")

(defparameter *default-output* "build/site/"
  "Output directory below the project root when none is given.")

(defparameter *output-variable* "CLDOCS_OUTPUT"
  "Environment variable that overrides the output directory.")

(defun main ()
  "Build the site and report the number of pages written."
  (load *quicklisp-setup*)
  (push *project-root* asdf:*central-registry*)
  (uiop:symbol-call '#:ql '#:quickload "cldocs" :silent t)
  (let* ((override (uiop:getenv *output-variable*))
         (output (if (and override (string/= override ""))
                     (uiop:ensure-directory-pathname override)
                     (merge-pathnames *default-output* *project-root*))))
    (format t "~&Wrote ~D pages to ~A~%"
            (uiop:symbol-call '#:cldocs/site '#:build-site output)
            output)))

(main)
