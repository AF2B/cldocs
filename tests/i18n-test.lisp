;;;; i18n-test.lisp --- Tests for locales, translations and the Portuguese pages.

(defpackage #:cldocs/tests/i18n
  (:use #:cl #:fiveam))

(in-package #:cldocs/tests/i18n)

(def-suite* i18n-suite :in cldocs/tests/suite:all-tests)

(test every-message-has-text-in-every-locale
  (dolist (key (cldocs/i18n:message-keys))
    (dolist (locale cldocs/i18n:+locales+)
      (is (plusp (length (cldocs/i18n:message key locale)))
          "~S has no ~S text" key locale))))

(test format-directives-agree-between-locales
  (flet ((directives (text)
           (loop for index from 0 below (1- (length text))
                 when (char= (char text index) #\~)
                   collect (char-upcase (char text (1+ index))))))
    (dolist (key (cldocs/i18n:message-keys))
      (is (equal (directives (cldocs/i18n:message key :en))
                 (directives (cldocs/i18n:message key :pt-br)))
          "~S uses different format directives per locale" key))))

(test unknown-message-keys-are-an-error
  (signals error (cldocs/i18n:tr :there-is-no-such-message)))

(test every-symbol-kind-has-a-label-in-every-locale
  (dolist (locale cldocs/i18n:+locales+)
    (let ((cldocs/i18n:*locale* locale))
      (dolist (kind cldocs/kinds:+definition-kinds+)
        (is (plusp (length (cldocs/model:kind-label kind))))))))

(test portuguese-summaries-name-existing-symbols
  (let ((stored (mapcar #'cldocs/definition:definition-name
                        (cldocs/store:read-package-data "COMMON-LISP")))
        (pathname (asdf:system-relative-pathname "cldocs" "data/i18n/pt-br/common-lisp.sexp")))
    (dolist (pair (cldocs/store:read-data-file pathname))
      (is (member (car pair) stored :test #'string=) "~A is not a symbol" (car pair))
      (is (plusp (length (cdr pair)))))))

(test summaries-are-only-translated-for-portuguese
  (let ((cldocs/i18n:*locale* :en))
    (is (null (cldocs/i18n:translated-summary "COMMON-LISP" "CAR"))))
  (let ((cldocs/i18n:*locale* :pt-br))
    (is (search "primeiro" (cldocs/i18n:translated-summary "COMMON-LISP" "CAR")))
    (is (null (cldocs/i18n:translated-summary "COMMON-LISP" "NO-SUCH-SYMBOL")))))

(test portuguese-pages-live-under-pt-br-and-speak-portuguese
  (let ((home (cldocs/tests/site:read-site-file "pt-br/index.html"))
        (symbol-page (cldocs/tests/site:read-site-file "pt-br/sym/common-lisp/car/index.html")))
    (is (search "<html lang=\"pt-BR\">" home))
    (is (search "Pacotes" home))
    (is (search "Exemplo 1" symbol-page))
    (is (search "Resumo:" symbol-page))
    (is (search "Veja também" symbol-page))
    (is (search "<html lang=\"en\">" (cldocs/tests/site:read-site-file "index.html")))
    (is (not (search "Resumo:" (cldocs/tests/site:read-site-file
                                "sym/common-lisp/car/index.html"))))))

(test portuguese-pages-keep-the-reader-inside-the-portuguese-tree
  (let ((html (cldocs/tests/site:read-site-file "pt-br/sym/common-lisp/car/index.html")))
    (is (search "href=\"../../../../pt-br/pkg/common-lisp/\"" html))
    (is (search "href=\"../../../../assets/site.css\"" html))
    (is (search "data-index=\"../../../../assets/search-index.pt-br.json\"" html))))

(test the-language-switch-points-at-the-same-page-in-the-other-language
  (let ((english (cldocs/tests/site:read-site-file "sym/common-lisp/car/index.html"))
        (portuguese (cldocs/tests/site:read-site-file "pt-br/sym/common-lisp/car/index.html")))
    (is (search "href=\"../../../pt-br/sym/common-lisp/car/\"" english))
    (is (search "href=\"../../../../sym/common-lisp/car/\"" portuguese))))

(test each-language-has-its-own-search-index
  (let ((english (com.inuoe.jzon:parse (cldocs/tests/site:read-site-file "assets/search-index.json")))
        (portuguese (com.inuoe.jzon:parse
                     (cldocs/tests/site:read-site-file "assets/search-index.pt-br.json"))))
    (is (= (length english) (length portuguese)))
    (flet ((summary-of (index name)
             (aref (find name index :key (lambda (row) (aref row 0)) :test #'string=) 4)))
      (is (search "primeiro" (summary-of portuguese "car")))
      (is (not (search "primeiro" (summary-of english "car")))))))

(test the-404-page-uses-absolute-links-from-the-base-path
  (let ((html (cldocs/tests/site:read-site-file "404.html")))
    (is (search "href=\"/assets/site.css\"" html))))
