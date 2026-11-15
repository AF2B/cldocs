;;;; urls.lisp --- Site-relative paths of every generated page.

(defpackage #:cldocs/urls
  (:use #:cl)
  (:import-from #:cldocs/slug
                #:slugify)
  (:export #:+home-path+
           #:+about-path+
           #:+terms-path+
           #:+not-found-file+
           #:+search-index-path+
           #:symbol-path
           #:package-path
           #:root-prefix
           #:site-href))

(in-package #:cldocs/urls)

(alexandria:define-constant +home-path+ ""
  :test #'string=
  :documentation "Path of the home page below the site root.")

(alexandria:define-constant +about-path+ "about/"
  :test #'string=
  :documentation "Path of the about and legal page.")

(alexandria:define-constant +terms-path+ "terms/"
  :test #'string=
  :documentation "Path of the contribution terms page.")

(alexandria:define-constant +not-found-file+ "404.html"
  :test #'string=
  :documentation "File served for unknown paths.")

(alexandria:define-constant +search-index-path+ "assets/search-index.json"
  :test #'string=
  :documentation "Path of the client-side search index.")

(defun symbol-path (package-name symbol-name)
  "Return the site path of the page documenting a symbol.

- PACKAGE-NAME: home package name, a string.
- SYMBOL-NAME: symbol name, a string."
  (format nil "sym/~A/~A/" (slugify package-name) (slugify symbol-name)))

(defun package-path (package-name)
  "Return the site path of a package page.

- PACKAGE-NAME: package name, a string."
  (format nil "pkg/~A/" (slugify package-name)))

(defun root-prefix (path)
  "Return the relative prefix that leads from PATH back to the site root.

- PATH: the page path below the site root, such as \"sym/common-lisp/car/\"."
  (with-output-to-string (out)
    (loop for char across path
          when (char= char #\/)
            do (write-string "../" out))))

(defun site-href (root path)
  "Return the relative link from a page at depth ROOT to PATH.

- ROOT: the prefix returned by ROOT-PREFIX for the linking page.
- PATH: the target path below the site root."
  (concatenate 'string root path))
