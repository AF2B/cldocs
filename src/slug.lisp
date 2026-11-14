;;;; slug.lisp --- Reversible, filesystem-safe names for symbols and packages.

(defpackage #:cldocs/slug
  (:use #:cl)
  (:export #:slugify))

(in-package #:cldocs/slug)

(defun slugify (name)
  "Return a lowercase, URL- and filesystem-safe slug for NAME.

Uppercase ASCII letters, digits and hyphens are kept (letters lowercased).
Every other character becomes `_<hex code>_`, so distinct names never collide.

- NAME: the symbol or package name as a string."
  (check-type name string)
  (with-output-to-string (out)
    (loop for char across name
          do (cond ((char<= #\A char #\Z) (write-char (char-downcase char) out))
                   ((or (digit-char-p char) (char= char #\-)) (write-char char out))
                   (t (format out "_~(~x~)_" (char-code char)))))))
