;;;; related.lisp --- "See also" links between symbols.
;;;;
;;;; Two sources, curated first: hand-written groups in data/see-also/ and
;;;; symbols that share a HyperSpec page (such as CAR and CDR).

(defpackage #:cldocs/related
  (:use #:cl)
  (:import-from #:cldocs/definition
                #:definition-clhs-page)
  (:import-from #:cldocs/model
                #:symbol-entry-definitions
                #:symbol-entry-name)
  (:import-from #:cldocs/slug
                #:slugify)
  (:import-from #:cldocs/store
                #:data-directory
                #:read-data-file)
  (:export #:see-also-pathname
           #:read-see-also-groups
           #:build-related-index
           #:+max-related+))

(in-package #:cldocs/related)

(alexandria:define-constant +max-related+ 12
  :test #'eql
  :documentation "Most related symbols shown on one page.")

(defparameter *see-also-type* "sexp"
  "File type of curated see-also files.")

(defun see-also-pathname (package-name)
  "Return the curated see-also file of PACKAGE-NAME.

- PACKAGE-NAME: the documented package, a string."
  (merge-pathnames (make-pathname :directory '(:relative "see-also")
                                  :name (slugify package-name)
                                  :type *see-also-type*)
                   (data-directory)))

(defun read-see-also-groups (package-name)
  "Return the curated groups of related symbol names, or NIL without a file.

Each group is a list of symbol-name strings that relate to one another.

- PACKAGE-NAME: the documented package, a string."
  (let ((pathname (see-also-pathname package-name)))
    (when (probe-file pathname)
      (getf (read-data-file pathname) :groups))))

(defun curated-neighbours (name groups)
  "Return the names that share a curated group with NAME, in group order.

- NAME: a symbol name, a string.
- GROUPS: curated groups as returned by READ-SEE-ALSO-GROUPS."
  (loop for group in groups
        when (member name group :test #'string=)
          append (remove name group :test #'string=)))

(defun page-index (entries)
  "Return a table from HyperSpec page to the names of the symbols it documents.

- ENTRIES: SYMBOL-ENTRY records of one package."
  (let ((table (make-hash-table :test #'equal)))
    (dolist (entry entries table)
      (let ((page (some #'definition-clhs-page (symbol-entry-definitions entry))))
        (when page
          (push (symbol-entry-name entry) (gethash page table)))))))

(defun shared-page-neighbours (entry page-table)
  "Return the names of other symbols documented on the same HyperSpec page as ENTRY.

- ENTRY: a SYMBOL-ENTRY.
- PAGE-TABLE: the table returned by PAGE-INDEX."
  (let ((page (some #'definition-clhs-page (symbol-entry-definitions entry))))
    (when page
      (sort (remove (symbol-entry-name entry)
                    (gethash page page-table)
                    :test #'string=)
            (lambda (left right)
              (or (< (length left) (length right))
                  (and (= (length left) (length right))
                       (string< left right))))))))

(defun build-related-index (package-name entries)
  "Return a table from symbol name to the names of its related symbols.

Curated neighbours come first, then symbols sharing a HyperSpec page. Only
names present in ENTRIES are kept and at most +MAX-RELATED+ are returned.

- PACKAGE-NAME: the documented package, a string.
- ENTRIES: SYMBOL-ENTRY records of that package."
  (let ((groups (read-see-also-groups package-name))
        (page-table (page-index entries))
        (known (make-hash-table :test #'equal))
        (index (make-hash-table :test #'equal)))
    (dolist (entry entries)
      (setf (gethash (symbol-entry-name entry) known) t))
    (dolist (entry entries index)
      (let* ((name (symbol-entry-name entry))
             (candidates (append (curated-neighbours name groups)
                                 (shared-page-neighbours entry page-table)))
             (kept (remove-if-not (lambda (candidate) (gethash candidate known))
                                  (remove-duplicates candidates
                                                     :test #'string=
                                                     :from-end t))))
        (when kept
          (setf (gethash name index)
                (subseq kept 0 (min (length kept) +max-related+))))))))
