;;;; kinds.lisp --- Closed set of definition kinds documented by CLDocs.

(defpackage #:cldocs/kinds
  (:use #:cl)
  (:export #:+definition-kinds+
           #:definition-kind-p))

(in-package #:cldocs/kinds)

(alexandria:define-constant +definition-kinds+
    '(:function
      :generic-function
      :macro
      :special-operator
      :variable
      :constant
      :class
      :condition
      :type)
  :test #'equal
  :documentation "Every kind of definition a symbol page can describe.")

(defun definition-kind-p (object)
  "Return true when OBJECT is a member of +DEFINITION-KINDS+.

- OBJECT: any Lisp object to classify."
  (and (member object +definition-kinds+) t))
