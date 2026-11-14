;;;; definition.lisp --- The DEFINITION record and its plist serialisation.

(defpackage #:cldocs/definition
  (:use #:cl)
  (:import-from #:cldocs/kinds
                #:definition-kind-p)
  (:export #:definition
           #:make-definition
           #:definition-package
           #:definition-name
           #:definition-kind
           #:definition-lambda-list
           #:definition-docstring
           #:definition-origin
           #:definition-clhs-page
           #:definition->plist
           #:plist->definition))

(in-package #:cldocs/definition)

(defstruct (definition (:copier nil))
  "One documented definition of a symbol (a symbol may have several).

- PACKAGE: name of the home package, a string.
- NAME: symbol name, a string.
- KIND: one of CLDOCS/KINDS:+DEFINITION-KINDS+.
- LAMBDA-LIST: printed lambda list or NIL.
- DOCSTRING: documentation string or NIL.
- ORIGIN: :SBCL for the image itself, otherwise the ASDF system name.
- CLHS-PAGE: page below the HyperSpec Body/ directory, or NIL."
  (package nil :type string :read-only t)
  (name nil :type string :read-only t)
  (kind nil :type keyword :read-only t)
  (lambda-list nil :type (or null string) :read-only t)
  (docstring nil :type (or null string) :read-only t)
  (origin :sbcl :type (or keyword string) :read-only t)
  (clhs-page nil :type (or null string) :read-only t))

(defun definition->plist (definition)
  "Return DEFINITION as a plist with a fixed key order; NIL slots are omitted.

- DEFINITION: a DEFINITION record."
  (loop for (key value) in `((:name ,(definition-name definition))
                             (:kind ,(definition-kind definition))
                             (:lambda-list ,(definition-lambda-list definition))
                             (:docstring ,(definition-docstring definition))
                             (:origin ,(definition-origin definition))
                             (:clhs-page ,(definition-clhs-page definition)))
        when value
          append (list key value)))

(defun plist->definition (plist package)
  "Build a DEFINITION from PLIST, the inverse of DEFINITION->PLIST.

- PLIST: a plist as produced by DEFINITION->PLIST.
- PACKAGE: name of the package the plist belongs to."
  (let ((kind (getf plist :kind)))
    (check-type kind (satisfies definition-kind-p))
    (make-definition :package package
                     :name (getf plist :name)
                     :kind kind
                     :lambda-list (getf plist :lambda-list)
                     :docstring (getf plist :docstring)
                     :origin (getf plist :origin :sbcl)
                     :clhs-page (getf plist :clhs-page))))
