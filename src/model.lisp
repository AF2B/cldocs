;;;; model.lisp --- View model shared by the page renderers.

(defpackage #:cldocs/model
  (:use #:cl)
  (:import-from #:cldocs/i18n
                #:tr
                #:translated-summary)
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

(defparameter *kind-message-keys*
  '((:function . :kind-function)
    (:generic-function . :kind-generic-function)
    (:macro . :kind-macro)
    (:special-operator . :kind-special-operator)
    (:variable . :kind-variable)
    (:constant . :kind-constant)
    (:class . :kind-class)
    (:condition . :kind-condition)
    (:type . :kind-type)
    (:symbol . :kind-symbol))
  "Message key of the display label of every definition kind.")

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
  (let ((key (cdr (assoc kind *kind-message-keys*))))
    (unless key
      (error "No label for definition kind ~S." kind))
    (tr key)))

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
  "Return the one-line summary of ENTRY in the current locale.

A translated summary wins; otherwise the first documented definition's
docstring is used.

- ENTRY: a SYMBOL-ENTRY."
  (or (translated-summary (symbol-entry-package entry) (symbol-entry-name entry))
      (let ((documented (find-if #'definition-docstring
                                 (symbol-entry-definitions entry))))
        (if documented
            (docstring-summary (definition-docstring documented))
            ""))))

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
