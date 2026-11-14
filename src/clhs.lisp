;;;; clhs.lisp --- Links into the Common Lisp HyperSpec (never its text).
;;;;
;;;; The HyperSpec is copyrighted by LispWorks Ltd. We store only the factual
;;;; mapping from symbol name to page name and link to the official copy.

(defpackage #:cldocs/clhs
  (:use #:cl)
  (:import-from #:cldocs/store
                #:data-directory
                #:read-data-file)
  (:export #:+clhs-base-url+
           #:clhs-page
           #:clhs-url
           #:reset-clhs-map))

(in-package #:cldocs/clhs)

(alexandria:define-constant +clhs-base-url+
    "https://www.lispworks.com/documentation/HyperSpec/"
  :test #'string=
  :documentation "Root of the official HyperSpec; page names resolve below it.")

(defparameter *map-file-name* "clhs-map.sexp"
  "File below the data root holding the symbol-name to page-name pairs.")

(defvar *clhs-map* nil
  "Lazily loaded hash table from symbol name to HyperSpec page, or NIL.")

(defun reset-clhs-map ()
  "Forget the cached map so the next lookup reloads it from disk."
  (setf *clhs-map* nil))

(defun clhs-map ()
  "Return the symbol-name to page-name table, loading it on first use."
  (or *clhs-map*
      (setf *clhs-map*
            (let ((table (make-hash-table :test #'equal))
                  (pathname (merge-pathnames *map-file-name* (data-directory))))
              (loop for (name . page) in (read-data-file pathname)
                    do (setf (gethash name table) page))
              table))))

(defun clhs-page (symbol-name)
  "Return the HyperSpec page (relative to the root) documenting SYMBOL-NAME, or NIL.

- SYMBOL-NAME: the name of a COMMON-LISP symbol as a string."
  (values (gethash symbol-name (clhs-map))))

(defun clhs-url (page)
  "Return the absolute URL of the HyperSpec PAGE.

- PAGE: a page path such as \"Body/f_car_c.htm\"."
  (concatenate 'string +clhs-base-url+ page))
