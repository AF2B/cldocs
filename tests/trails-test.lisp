;;;; trails-test.lisp --- Tests for the thematic trails.

(defpackage #:cldocs/tests/trails
  (:use #:cl #:fiveam))

(in-package #:cldocs/tests/trails)

(def-suite* trails-suite :in cldocs/tests/suite:all-tests)

(defun documented-symbol-p (key)
  "Return true when the (package . name) KEY has stored data.

- KEY: a cons of package name and symbol name."
  (member (cdr key)
          (mapcar #'cldocs/definition:definition-name
                  (cldocs/store:read-package-data (car key)))
          :test #'string=))

(test every-trail-is-complete-in-every-language
  (let ((trails (cldocs/trails:load-trails)))
    (is (>= (length trails) 10))
    (dolist (trail trails)
      (dolist (locale cldocs/i18n:+locales+)
        (let ((cldocs/i18n:*locale* locale))
          (is (plusp (length (cldocs/trails:trail-title trail))))
          (is (plusp (length (cldocs/trails:trail-intro trail))))
          (dolist (section (cldocs/trails:localized-sections trail))
            (is (plusp (length (car section))))
            (is (consp (cdr section)))))))))

(test every-trail-symbol-is-documented
  (dolist (trail (cldocs/trails:load-trails))
    (dolist (key (cldocs/trails:trail-symbol-keys trail))
      (is (documented-symbol-p key)
          "~A lists ~S, which is not documented" (cldocs/trails:trail-slug trail) key))))

(test trails-are-ordered-and-have-unique-slugs
  (let* ((trails (cldocs/trails:load-trails))
         (slugs (mapcar #'cldocs/trails:trail-slug trails))
         (orders (mapcar #'cldocs/trails:trail-order trails)))
    (is (= (length slugs) (length (remove-duplicates slugs :test #'string=))))
    (is (equal orders (sort (copy-list orders) #'<)))))

(test trails-do-not-repeat-a-symbol-within-one-trail
  (dolist (trail (cldocs/trails:load-trails))
    (let ((keys (cldocs/trails:trail-symbol-keys trail)))
      (is (= (length keys) (length (remove-duplicates keys :test #'equal)))
          "~A repeats a symbol" (cldocs/trails:trail-slug trail)))))

(test trail-pages-exist-in-both-languages-and-link-to-symbols
  (dolist (prefix '("" "pt-br/"))
    (let ((index (cldocs/tests/site:read-site-file
                  (format nil "~Atrails/index.html" prefix))))
      (dolist (trail (cldocs/trails:load-trails))
        (is (search (format nil "trails/~A/" (cldocs/trails:trail-slug trail)) index))
        (let ((page (cldocs/tests/site:read-site-file
                     (format nil "~Atrails/~A/index.html" prefix (cldocs/trails:trail-slug trail)))))
          (is (search "sym/" page)))))))

(test the-libraries-trail-reaches-library-pages
  (let ((page (cldocs/tests/site:read-site-file "trails/libraries/index.html")))
    (is (search "sym/alexandria/curry/" page))
    (is (search "sym/str/join/" page))))
