;;;; model.lisp --- View model shared by the page renderers.

(defpackage #:cldocs/model
  (:use #:cl)
  (:import-from #:cldocs/definition
                #:definition-docstring
                #:definition-kind
                #:definition-name
                #:definition-package)
  (:export #:symbol-entry
           #:make-symbol-entry
           #:symbol-entry-package
           #:symbol-entry-name
           #:symbol-entry-definitions
           #:symbol-entry-kinds
           #:symbol-entry-summary
           #:group-definitions
           #:docstring-summary
           #:kind-label
           #:signature))

(in-package #:cldocs/model)

(defparameter *summary-length* 120
  "Maximum number of characters of a docstring shown as a one-line summary.")

(defparameter *ellipsis* "…"
  "Marks a truncated summary.")

(defparameter *kind-labels*
  '((:function . "Function")
    (:generic-function . "Generic function")
    (:macro . "Macro")
    (:special-operator . "Special operator")
    (:variable . "Variable")
    (:constant . "Constant")
    (:class . "Class")
    (:condition . "Condition")
    (:type . "Type")
    (:symbol . "Symbol"))
  "Display label of every definition kind.")

(defstruct (symbol-entry (:copier nil))
  "Everything documented about one symbol of one package.

- PACKAGE: home package name, a string.
- NAME: symbol name, a string.
- DEFINITIONS: its DEFINITION records, ordered by kind."
  (package "" :type string :read-only t)
  (name "" :type string :read-only t)
  (definitions '() :type list :read-only t))

(defun kind-label (kind)
  "Return the display label of the definition KIND.

- KIND: a keyword from CLDOCS/KINDS:+DEFINITION-KINDS+."
  (or (cdr (assoc kind *kind-labels*))
      (error "No label for definition kind ~S." kind)))

(defun symbol-entry-kinds (entry)
  "Return the kinds of every definition of ENTRY, in display order.

- ENTRY: a SYMBOL-ENTRY."
  (mapcar #'definition-kind (symbol-entry-definitions entry)))

(defun docstring-summary (docstring)
  "Return the first line of DOCSTRING, truncated for use in lists.

- DOCSTRING: a documentation string, or NIL."
  (if (null docstring)
      ""
      (let* ((newline (position #\Newline docstring))
             (line (string-trim " " (subseq docstring 0 newline))))
        (if (> (length line) *summary-length*)
            (concatenate 'string
                         (string-right-trim " " (subseq line 0 (1- *summary-length*)))
                         *ellipsis*)
            line))))

(defun symbol-entry-summary (entry)
  "Return the one-line summary of ENTRY taken from its first documented definition.

- ENTRY: a SYMBOL-ENTRY."
  (let ((documented (find-if #'definition-docstring
                             (symbol-entry-definitions entry))))
    (if documented
        (docstring-summary (definition-docstring documented))
        "")))

(defun group-definitions (definitions)
  "Group DEFINITIONS by symbol and return SYMBOL-ENTRY records sorted by name.

- DEFINITIONS: DEFINITION records of one package, in any order."
  (let ((groups (make-hash-table :test #'equal))
        (entries '()))
    (dolist (definition definitions)
      (push definition (gethash (definition-name definition) groups)))
    (maphash (lambda (name members)
               (let ((ordered (reverse members)))
                 (push (make-symbol-entry
                        :package (definition-package (first ordered))
                        :name name
                        :definitions ordered)
                       entries)))
             groups)
    (sort entries #'string< :key #'symbol-entry-name)))

(defun signature (name lambda-list)
  "Return the call form of NAME as shown in a code block.

- NAME: symbol name, a string, rendered in lowercase.
- LAMBDA-LIST: rendered lambda list such as \"(a &optional b)\", or NIL."
  (let ((lowercase (string-downcase name)))
    (cond ((null lambda-list) lowercase)
          ((string= lambda-list "()") (format nil "(~A)" lowercase))
          (t (format nil "(~A ~A" lowercase (subseq lambda-list 1))))))
