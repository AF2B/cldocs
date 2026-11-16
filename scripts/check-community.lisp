;;;; check-community.lisp --- Validate every file in community/examples/.
;;;; Usage: sbcl --non-interactive --load scripts/check-community.lisp
;;;; Exit status 0 when every file is valid, 1 otherwise.

;;; A bare SBCL has no ASDF/UIOP until it is required; later forms name UIOP symbols.
(require :asdf)

(defpackage #:cldocs/scripts/check-community
  (:use #:cl))

(in-package #:cldocs/scripts/check-community)

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
  "Print the problems of every contributed file and exit non-zero when any exist."
  (let ((files (cldocs/community:community-example-files))
        (failures 0))
    (dolist (file files)
      (let ((problems (cldocs/community:validate-community-file file)))
        (when problems
          (incf failures)
          (format t "~&~A~%~{  - ~A~%~}" (enough-namestring file *project-root*) problems))))
    (format t "~&~D file~:P checked, ~D with problems.~%" (length files) failures)
    (uiop:quit (if (zerop failures) 0 1))))

(main)
