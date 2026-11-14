;;;; slug-test.lisp --- Tests for cldocs/slug.

(defpackage #:cldocs/tests/slug
  (:use #:cl #:fiveam))

(in-package #:cldocs/tests/slug)

(def-suite* slug-suite :in cldocs/tests/suite:all-tests)

(test plain-names-are-lowercased
  (is (string= "mapcar" (cldocs/slug:slugify "MAPCAR")))
  (is (string= "print-object" (cldocs/slug:slugify "PRINT-OBJECT"))))

(test special-characters-are-hex-escaped
  (is (string= "_2a_print-base_2a_" (cldocs/slug:slugify "*PRINT-BASE*")))
  (is (string= "1_2b_" (cldocs/slug:slugify "1+")))
  (is (string= "_3c__3d_" (cldocs/slug:slugify "<="))))

(test distinct-names-never-collide
  (let ((names '("1+" "1-" "+" "-" "*" "/" "/=" "=" "<" "<=" ">" ">=" "FOO_BAR" "FOO-BAR" "foo")))
    (is (= (length names)
           (length (remove-duplicates (mapcar #'cldocs/slug:slugify names)
                                      :test #'string=))))))

(test slugs-are-filesystem-safe
  (dolist (name '("*PRINT-BASE*" "1+" "/" "<=" "&OPTIONAL" "A/B"))
    (is (every (lambda (char)
                 (or (alphanumericp char) (char= char #\-) (char= char #\_)))
               (cldocs/slug:slugify name)))))
