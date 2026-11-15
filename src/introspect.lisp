;;;; introspect.lisp --- Extract definition metadata from the running SBCL image.
;;;;
;;;; References: CLHS 11.1 (Package System), SBCL manual "sb-introspect",
;;;; SBCL manual "sb-cltl2" (CLtL2 environment access).

(defpackage #:cldocs/introspect
  (:use #:cl)
  (:import-from #:cldocs/clhs
                #:clhs-page)
  (:import-from #:cldocs/conditions
                #:package-not-found)
  (:import-from #:cldocs/definition
                #:make-definition)
  (:import-from #:cldocs/kinds
                #:definition-kind-rank)
  (:export #:symbol-kinds
           #:render-lambda-list
           #:symbol-definitions
           #:ingest-package))

(in-package #:cldocs/introspect)

(defparameter *clhs-package-name* "COMMON-LISP"
  "Only symbols of this package are linked to the HyperSpec.")

(defun function-kind (symbol)
  "Return the function-like kind of SYMBOL, or NIL when it names no function.

- SYMBOL: the symbol to inspect."
  (cond ((special-operator-p symbol) :special-operator)
        ((macro-function symbol) :macro)
        ((fboundp symbol)
         (if (typep (fdefinition symbol) 'generic-function)
             :generic-function
             :function))))

(defun variable-kind (symbol)
  "Return :VARIABLE or :CONSTANT when SYMBOL names one, otherwise NIL.

- SYMBOL: the symbol to inspect."
  (case (sb-cltl2:variable-information symbol)
    (:special :variable)
    (:constant :constant)))

(defun type-kind (symbol)
  "Return :CLASS, :CONDITION or :TYPE when SYMBOL names a type, otherwise NIL.

- SYMBOL: the symbol to inspect."
  (let ((class (find-class symbol nil)))
    (cond ((null class)
           (when (sb-int:info :type :kind symbol)
             :type))
          ((subtypep class (find-class 'condition)) :condition)
          (t :class))))

(defun symbol-kinds (symbol)
  "Return every kind of definition SYMBOL has, or (:SYMBOL) when it has none.

- SYMBOL: the symbol to inspect."
  (or (remove nil (list (function-kind symbol)
                        (variable-kind symbol)
                        (type-kind symbol)))
      (list :symbol)))

(defun render-lambda-element (object)
  "Render one element of a lambda list as lowercase, readable text.

- OBJECT: a symbol, cons or self-evaluating object from a lambda list."
  (typecase object
    (keyword (format nil ":~(~A~)" (symbol-name object)))
    (null "nil")
    (symbol (string-downcase (symbol-name object)))
    (cons (render-lambda-list object))
    ((or string number character)
     (with-standard-io-syntax
       (let ((*print-readably* nil))
         (prin1-to-string object))))
    (t "...")))

(defun render-lambda-list (lambda-list)
  "Render LAMBDA-LIST as lowercase text without package prefixes.

Dotted tails and (quote x) forms are rendered readably.

- LAMBDA-LIST: a list, possibly dotted, as returned by SB-INTROSPECT."
  (if (and (consp lambda-list)
           (eq (first lambda-list) 'quote)
           (consp (rest lambda-list))
           (null (cddr lambda-list)))
      (format nil "'~A" (render-lambda-element (second lambda-list)))
      (with-output-to-string (out)
        (write-char #\( out)
        (loop for tail = lambda-list then (cdr tail)
              for first-p = t then nil
              while (consp tail)
              do (unless first-p (write-char #\Space out))
                 (write-string (render-lambda-element (car tail)) out)
              finally (when tail
                        (format out " . ~A" (render-lambda-element tail))))
        (write-char #\) out))))

(defun kind-lambda-list (symbol kind)
  "Return the rendered lambda list of SYMBOL for KIND, or NIL when it has none.

- SYMBOL: the symbol being documented.
- KIND: the definition kind being rendered."
  (case kind
    (:function
     (render-lambda-list (sb-introspect:function-lambda-list symbol)))
    (:generic-function
     ;; SB-INTROSPECT would add the &key arguments of every loaded method,
     ;; leaking whatever libraries happen to be in the image.
     (render-lambda-list
      (sb-mop:generic-function-lambda-list (fdefinition symbol))))
    (:macro
     (render-lambda-list
      (sb-introspect:function-lambda-list (macro-function symbol))))))

(defun kind-docstring (symbol kind)
  "Return the documentation string SBCL holds for SYMBOL as KIND, or NIL.

- SYMBOL: the symbol being documented.
- KIND: the definition kind being rendered."
  (case kind
    ((:function :generic-function :macro :special-operator)
     (documentation symbol 'function))
    ((:variable :constant)
     (documentation symbol 'variable))
    ((:class :condition :type)
     (documentation symbol 'type))))

(defun symbol-definitions (symbol
                           &key
                             (origin :sbcl)
                             clhs-page
                             package-name)
  "Return the DEFINITION records of SYMBOL, ordered by kind.

- SYMBOL: the symbol to inspect.
- ORIGIN: :SBCL for the image itself, otherwise the ASDF system name.
- CLHS-PAGE: HyperSpec page for SYMBOL, or NIL.
- PACKAGE-NAME: package the page belongs to; defaults to the home package."
  (let ((package-name (or package-name (package-name (symbol-package symbol)))))
    (mapcar (lambda (kind)
              (make-definition :package package-name
                               :name (symbol-name symbol)
                               :kind kind
                               :lambda-list (kind-lambda-list symbol kind)
                               :docstring (kind-docstring symbol kind)
                               :origin origin
                               :clhs-page clhs-page))
            (sort (copy-list (symbol-kinds symbol))
                  #'<
                  :key #'definition-kind-rank))))

(defun external-symbols (package)
  "Return the external symbols of PACKAGE sorted by name.

- PACKAGE: a package object."
  (let ((symbols '()))
    (do-external-symbols (symbol package)
      (push symbol symbols))
    (sort symbols #'string< :key #'symbol-name)))

(defun ingest-package (package-designator
                       &key
                         (origin :sbcl))
  "Return the DEFINITION records of every external symbol of a package.

Signals PACKAGE-NOT-FOUND when the package does not exist.

- PACKAGE-DESIGNATOR: a package, or its name as a string or symbol.
- ORIGIN: :SBCL for the image itself, otherwise the ASDF system name."
  (let ((package (find-package package-designator)))
    (unless package
      (error 'package-not-found :name package-designator))
    (let ((linked-p (string= (package-name package) *clhs-package-name*)))
      (loop for symbol in (external-symbols package)
            append (symbol-definitions symbol
                                       :origin origin
                                       :package-name (package-name package)
                                       :clhs-page (when linked-p
                                                    (clhs-page (symbol-name symbol))))))))
