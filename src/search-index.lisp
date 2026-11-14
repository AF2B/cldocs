;;;; search-index.lisp --- Compact JSON index consumed by the client-side search.

(defpackage #:cldocs/search-index
  (:use #:cl)
  (:import-from #:cldocs/model
                #:kind-label
                #:symbol-entry-kinds
                #:symbol-entry-name
                #:symbol-entry-package
                #:symbol-entry-summary)
  (:import-from #:cldocs/urls
                #:symbol-path)
  (:export #:index-row
           #:build-search-index))

(in-package #:cldocs/search-index)

(defun index-row (entry)
  "Return the index row of ENTRY as a vector of name, package, kinds, path, summary.

Names are lowercase because that is how users type and read them.

- ENTRY: a SYMBOL-ENTRY."
  (vector (string-downcase (symbol-entry-name entry))
          (symbol-entry-package entry)
          (map 'vector #'kind-label (symbol-entry-kinds entry))
          (symbol-path (symbol-entry-package entry)
                       (symbol-entry-name entry))
          (symbol-entry-summary entry)))

(defun build-search-index (entries)
  "Return the JSON text of the search index for ENTRIES.

- ENTRIES: every SYMBOL-ENTRY to make searchable."
  (com.inuoe.jzon:stringify (map 'vector #'index-row entries)))
