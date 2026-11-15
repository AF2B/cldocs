;;;; urls.lisp --- Site-relative paths of every generated page.

(defpackage #:cldocs/urls
  (:use #:cl)
  (:import-from #:cldocs/i18n
                #:*locale*
                #:locale-prefix)
  (:import-from #:cldocs/slug
                #:slugify)
  (:export #:+home-path+
           #:+about-path+
           #:+terms-path+
           #:+trails-path+
           #:+not-found-file+
           #:+search-index-path+
           #:symbol-path
           #:package-path
           #:root-prefix
           #:site-href
           #:localized-path
           #:page-root
           #:page-href
           #:trail-path
           #:search-index-file
           #:url-encode))

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

(alexandria:define-constant +trails-path+ "trails/"
  :test #'string=
  :documentation "Path of the trails index.")

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

(defun url-encode (text)
  "Percent-encode TEXT for use as a URL query value.

Unreserved characters are kept; everything else is written as UTF-8 bytes.

- TEXT: the string to encode."
  (with-output-to-string (out)
    (loop for byte across (sb-ext:string-to-octets text :external-format :utf-8)
          for char = (code-char byte)
          do (if (or (char<= #\a char #\z)
                     (char<= #\A char #\Z)
                     (char<= #\0 char #\9)
                     (find char "-._~"))
                 (write-char char out)
                 (format out "%~2,'0X" byte)))))

(defun trail-path (slug)
  "Return the site path of the trail called SLUG.

- SLUG: the trail slug, a string."
  (format nil "~A~A/" +trails-path+ slug))

(defun localized-path (path)
  "Return PATH below the current locale's directory of the output tree.

- PATH: a page path such as \"sym/common-lisp/car/\"."
  (concatenate 'string (locale-prefix *locale*) path))

(defun page-root (path)
  "Return the relative prefix from the page at PATH, in the current locale, to the site root.

- PATH: the unlocalized page path."
  (root-prefix (localized-path path)))

(defun page-href (root path)
  "Return the link from a page whose prefix is ROOT to the page PATH in the same locale.

- ROOT: the prefix returned by PAGE-ROOT for the linking page.
- PATH: the unlocalized target page path."
  (concatenate 'string root (localized-path path)))

(defun search-index-file ()
  "Return the path of the search index of the current locale."
  (if (string= (locale-prefix *locale*) "")
      +search-index-path+
      (format nil "assets/search-index.~A.json"
              (string-right-trim "/" (locale-prefix *locale*)))))
