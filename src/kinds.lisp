;;;; kinds.lisp --- Closed set of definition kinds documented by CLDocs.

(defpackage #:cldocs/kinds
  (:use #:cl)
  (:export #:+definition-kinds+
           #:definition-kind-p
           #:definition-kind-rank))

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
      :type
      :symbol)
  :test #'equal
  :documentation "Every kind of definition a symbol page can describe.
:SYMBOL marks a symbol with no definition of its own (for example a
declaration identifier or a lambda list keyword).")

(defun definition-kind-p (object)
  "Return true when OBJECT is a member of +DEFINITION-KINDS+.

- OBJECT: any Lisp object to classify."
  (and (member object +definition-kinds+) t))

(defun definition-kind-rank (kind)
  "Return the display position of KIND within +DEFINITION-KINDS+.

- KIND: a keyword that must satisfy DEFINITION-KIND-P."
  (check-type kind (satisfies definition-kind-p))
  (position kind +definition-kinds+))
