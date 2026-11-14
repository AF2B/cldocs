;;;; cldocs.lisp --- Top-level package of CLDocs.

(defpackage #:cldocs
  (:use #:cl)
  (:export #:+version+
           #:version))

(in-package #:cldocs)

(alexandria:define-constant +version+ "0.1.0"
  :test #'string=
  :documentation "Current CLDocs version; keep in sync with cldocs.asd.")

(defun version ()
  "Return the CLDocs version string."
  +version+)
