;;;; site-test.lisp --- Tests of the generated static site and its styling.

(defpackage #:cldocs/tests/site
  (:use #:cl #:fiveam)
  (:export #:built-site
           #:read-site-file
           #:call-with-temporary-directory))

(in-package #:cldocs/tests/site)

(def-suite* site-suite :in cldocs/tests/suite:all-tests)

(defparameter *common-lisp-symbol-count* 978
  "Number of external symbols of COMMON-LISP; each gets one page.")

(defparameter *allowed-colors* '("#000510" "#00081a" "#fff" "#ffffff" "#333" "#333333"
                                 "#000" "#000000" "#8899a6" "#0074d9" "#ef4444" "#22c55e")
  "Every hex color the Borba Design System permits.")

(defun call-with-temporary-directory (function)
  "Call FUNCTION with a fresh empty directory pathname, deleting it afterwards.

- FUNCTION: a function of one argument, the directory pathname."
  (let ((directory (uiop:ensure-directory-pathname
                    (merge-pathnames (format nil "cldocs-site-~36R/" (random (expt 36 8)))
                                     (uiop:temporary-directory)))))
    (ensure-directories-exist directory)
    (unwind-protect (funcall function directory)
      (uiop:delete-directory-tree directory :validate t :if-does-not-exist :ignore))))

(defvar *built-site* nil
  "Directory of a site built once and shared by the read-only tests.")

(defun built-site ()
  "Return the directory of a freshly built site, building it on first use."
  (or *built-site*
      (let ((directory (uiop:ensure-directory-pathname
                        (merge-pathnames (format nil "cldocs-shared-~36R/" (random (expt 36 8)))
                                         (uiop:temporary-directory)))))
        (cldocs/site:build-site directory)
        (push (lambda ()
                (uiop:delete-directory-tree directory :validate t :if-does-not-exist :ignore))
              sb-ext:*exit-hooks*)
        (setf *built-site* directory))))

(defun read-site-file (relative-path)
  "Return the contents of RELATIVE-PATH inside the shared built site.

- RELATIVE-PATH: path below the site root, such as \"index.html\"."
  (uiop:read-file-string (merge-pathnames relative-path (built-site))))

(defun attribute-values (html attribute)
  "Return every value of ATTRIBUTE written as ATTRIBUTE=\"value\" in HTML.

- HTML: the page source, a string.
- ATTRIBUTE: attribute name such as \"href\"."
  (let ((needle (format nil " ~A=\"" attribute))
        (values '()))
    (loop for start = (search needle html) then (search needle html :start2 end)
          while start
          for value-start = (+ start (length needle))
          for end = (position #\" html :start value-start)
          do (push (subseq html value-start end) values))
    (nreverse values)))

(defun internal-link-p (link)
  "Return true when LINK points inside the site.

- LINK: a href or src value."
  (not (or (zerop (length link))
           (char= (char link 0) #\#)
           (search "://" link))))

(defun link-target (page-directory link)
  "Return the file LINK resolves to when found on a page in PAGE-DIRECTORY.

- PAGE-DIRECTORY: directory of the page holding the link.
- LINK: an internal href or src value."
  (let* ((path (subseq link 0 (position #\# link)))
         (file (if (or (zerop (length path))
                       (char= (char path (1- (length path))) #\/))
                   (concatenate 'string path "index.html")
                   path)))
    (if (and (plusp (length file)) (char= (char file 0) #\/))
        (probe-file (merge-pathnames (string-left-trim "/" file) (built-site)))
        (probe-file (merge-pathnames file page-directory)))))

(defun broken-links ()
  "Return a list of (page . link) conses whose target file does not exist."
  (let ((site (built-site))
        (broken '()))
    (dolist (page (directory (merge-pathnames "**/*.html" site)))
      (let ((html (uiop:read-file-string page)))
        (dolist (link (append (attribute-values html "href")
                              (attribute-values html "src")
                              (attribute-values html "data-index")))
          (when (and (internal-link-p link)
                     (null (link-target (uiop:pathname-directory-pathname page) link)))
            (push (cons (enough-namestring page site) link) broken)))))
    broken))

(test site-has-one-page-per-symbol
  (let ((pages (length (directory (merge-pathnames "sym/common-lisp/*/index.html" (built-site))))))
    (is (= *common-lisp-symbol-count* pages))))

(test site-has-the-fixed-pages
  (dolist (path '("index.html" "about/index.html" "404.html" "pkg/common-lisp/index.html"
                  "pkg/alexandria/index.html" "pkg/cl-ppcre/index.html"
                  "pkg/bordeaux-threads/index.html"
                  "assets/site.css" "assets/tokens.css" "assets/search-index.json"
                  "assets/fonts/Inter.ttf" "assets/fonts/JetBrainsMono.ttf"))
    (is (probe-file (merge-pathnames path (built-site))) "missing ~A" path)))

(test site-has-no-broken-internal-links
  (is (null (broken-links))))

(test symbol-page-links-to-the-hyperspec-safely
  (let ((html (read-site-file "sym/common-lisp/car/index.html")))
    (is (search "https://www.lispworks.com/documentation/HyperSpec/Body/f_car_c.htm" html))
    (is (search "noopener noreferrer" html))))

(test symbols-with-special-characters-get-safe-paths
  (is (probe-file (merge-pathnames "sym/common-lisp/_2a_print-base_2a_/index.html"
                                   (built-site))))
  (is (probe-file (merge-pathnames "sym/common-lisp/1_2b_/index.html" (built-site)))))

(test pages-never-copy-hyperspec-text
  (let ((html (read-site-file "sym/common-lisp/car/index.html")))
    (is (search "never copies its text" html))))

(defun without-attribute-values (html)
  "Return HTML with every double-quoted attribute value removed.

Quoted values may hold a raw < or > safely, so only text and tags are checked.

- HTML: the page source, a string."
  (with-output-to-string (out)
    (let ((inside-quotes nil))
      (loop for char across html
            do (cond ((char= char #\") (setf inside-quotes (not inside-quotes)))
                     ((not inside-quotes) (write-char char out)))))))

(defun compact-html (html)
  "Return HTML on one line with attribute quotes removed, for substring checks.

The pretty printer may wrap a tag across lines; this makes tags contiguous.

- HTML: the page source, a string."
  (with-output-to-string (out)
    (let ((previous-space nil))
      (loop for char across html
            do (cond ((char= char #\") nil)
                     ((member char '(#\Space #\Newline #\Tab))
                      (unless previous-space (write-char #\Space out))
                      (setf previous-space t))
                     (t (write-char char out)
                        (setf previous-space nil)))))))

(test docstrings-and-names-are-escaped
  (let* ((definition (cldocs/definition:make-definition
                      :package "DEMO"
                      :name "<B>"
                      :kind :function
                      :lambda-list "(x)"
                      :docstring "x\"><script>alert(1)</script>"))
         (entry (cldocs/model:make-symbol-entry :package "DEMO"
                                                :name "<B>"
                                                :definitions (list definition)))
         (html (cldocs/render:render-symbol entry)))
    (is (not (search "\"><script>" html)))
    (is (not (search "<b>" (without-attribute-values html))))
    (is (search "&lt;script&gt;alert(1)" html))))

(test generated-css-obeys-the-design-system
  (let ((css (string-downcase
              (uiop:read-file-string
               (asdf:system-relative-pathname "cldocs" "assets/site.css")))))
    (is (not (search "box-shadow" css)))
    (is (not (search "gradient" css)))
    (is (not (search "text-shadow" css)))
    (is (null (loop for start = (search "border-radius:" css)
                      then (search "border-radius:" css :start2 (1+ start))
                    while start
                    unless (eql start (search "border-radius: 0;" css :start2 start))
                      collect start)))
    (let ((colors '()))
      (loop for start = (position #\# css) then (position #\# css :start (1+ start))
            while start
            do (let ((end (position-if-not #'alphanumericp css :start (1+ start))))
                 (push (subseq css start end) colors)))
      (is (null (set-difference (remove-duplicates colors :test #'string=)
                                *allowed-colors*
                                :test #'string=))))))

(test built-site-ships-the-design-system-tokens-unmodified
  (is (string= (uiop:read-file-string
                (merge-pathnames "tokens.css" (cldocs/site:design-system-directory)))
               (read-site-file "assets/tokens.css"))))

(test missing-design-system-is-reported-not-improvised
  (call-with-temporary-directory
   (lambda (directory)
     (let ((output (merge-pathnames "out/" directory)))
       (signals cldocs/conditions:design-system-missing
         (cldocs/site:build-site output :design-system (merge-pathnames "nope/" directory)))
       (is (not (probe-file output)))))))

(test foreign-output-directory-is-never-wiped
  (call-with-temporary-directory
   (lambda (directory)
     (let ((stray (merge-pathnames "precious.txt" directory)))
       (with-open-file (out stray :direction :output)
         (write-string "keep me" out))
       (signals cldocs/conditions:output-directory-not-empty
         (cldocs/site:build-site directory))
       (is (probe-file stray))))))

(test rebuilding-over-a-previous-site-is-allowed
  (call-with-temporary-directory
   (lambda (directory)
     (let ((output (merge-pathnames "site/" directory)))
       (let ((first (cldocs/site:build-site output))
             (second (cldocs/site:build-site output)))
         (is (= first second)))))))

(defun node-available-p ()
  "Return true when a node executable is on the PATH."
  (zerop (nth-value 2 (uiop:run-program '("sh" "-c" "command -v node")
                                        :output nil
                                        :ignore-error-status t))))

(test client-side-scripts-pass-their-node-tests
  (if (not (node-available-p))
      (skip "node is not installed; client-side scripts were NOT verified.")
      (multiple-value-bind (output error-output code)
          (uiop:run-program
           (list "env"
                 (format nil "CLDOCS_INDEX=~A"
                         (namestring (merge-pathnames "assets/search-index.json"
                                                      (built-site))))
                 "node" "--test")
           :directory (asdf:system-relative-pathname "cldocs" "")
           :output :string
           :error-output :string
           :ignore-error-status t)
        (is (zerop code) "node tests failed:~%~A~%~A" output error-output))))

(test every-header-shows-the-borba-wordmark-with-the-blue-period
  (dolist (path '("index.html" "sym/common-lisp/car/index.html" "404.html"))
    (let ((html (read-site-file path)))
      (is (search "BORBA" html) "wordmark missing on ~A" path)
      (is (search "<span class=dot>.</span>" html) "blue period missing on ~A" path)
      (is (search "logo-product" html)))))

(test vendored-design-system-matches-its-source-when-the-source-is-present
  (let ((source (merge-pathnames "Documents/borba-design-system/" (user-homedir-pathname)))
        (vendored (asdf:system-relative-pathname "cldocs" "vendor/borba-design-system/")))
    (if (not (probe-file (merge-pathnames "tokens.css" source)))
        (skip "The design system source is not on this machine.")
        (dolist (file '("tokens.css" "tipografia.md"))
          (is (string= (uiop:read-file-string (merge-pathnames file source))
                       (uiop:read-file-string (merge-pathnames file vendored)))
              "~A drifted from the source of truth; run scripts/sync-design-system.sh" file)))))

(test contribution-buttons-need-a-repository-and-prefill-the-file
  (let* ((definition (cldocs/definition:make-definition :package "COMMON-LISP"
                                                        :name "CAR"
                                                        :kind :function))
         (entry (cldocs/model:make-symbol-entry :package "COMMON-LISP"
                                                :name "CAR"
                                                :definitions (list definition))))
    (is (not (search "id=contribute" (cldocs/render:render-symbol entry))))
    (let ((html (let ((cldocs/render:*repository-url* "https://github.com/example/cldocs"))
                  (cldocs/render:render-symbol entry))))
      (is (search "id=contribute" html))
      (is (search "https://github.com/example/cldocs/new/main?filename=community%2Fexamples%2Fcommon-lisp%2Fcar.txt" html))
      (is (search "author%3A%20YOUR-GITHUB-LOGIN" html))
      (is (search "CONTRIBUTING.md" html)))))

(defparameter *test-site-url* "https://example.org/docs"
  "Public address used to build a site that has sitemap and canonical links.")

(defun call-with-site-built-for-search-engines (function)
  "Call FUNCTION with the directory of a site built with *TEST-SITE-URL*.

- FUNCTION: a function of one argument, the site directory."
  (call-with-temporary-directory
   (lambda (directory)
     (cldocs/site:build-site directory :site-url (concatenate 'string *test-site-url* "/"))
     (funcall function directory))))

(test every-page-has-an-icon-and-preview-tags-without-needing-an-address
  (let ((html (compact-html (read-site-file "sym/common-lisp/car/index.html"))))
    (is (search "rel=icon" html))
    (is (search "property=og:title" html))
    (is (search "property=og:description" html))
    (is (search "name=twitter:card" html))
    (is (not (search "rel=canonical" html)))
    (is (not (search "og:image" html))))
  (dolist (path '("assets/favicon.svg" "assets/share.png"))
    (is (probe-file (merge-pathnames path (built-site))) "missing ~A" path))
  (is (not (probe-file (merge-pathnames "sitemap.xml" (built-site)))))
  (is (not (probe-file (merge-pathnames "robots.txt" (built-site))))))

(test a-site-address-adds-canonical-links-alternates-and-the-share-image
  (call-with-site-built-for-search-engines
   (lambda (directory)
     (let ((english (compact-html
                     (uiop:read-file-string
                      (merge-pathnames "sym/common-lisp/car/index.html" directory))))
           (portuguese (compact-html
                        (uiop:read-file-string
                         (merge-pathnames "pt-br/sym/common-lisp/car/index.html" directory)))))
       (is (search "rel=canonical href=https://example.org/docs/sym/common-lisp/car/" english))
       (is (search "rel=canonical href=https://example.org/docs/pt-br/sym/common-lisp/car/"
                   portuguese))
       (dolist (html (list english portuguese))
         (is (search "hreflang=en href=https://example.org/docs/sym/common-lisp/car/" html))
         (is (search "hreflang=pt-BR href=https://example.org/docs/pt-br/sym/common-lisp/car/"
                     html))
         (is (search "hreflang=x-default href=https://example.org/docs/sym/common-lisp/car/"
                     html))
         (is (search "og:image content=https://example.org/docs/assets/share.png" html)))
       (is (search "og:locale content=pt_BR" portuguese))))))

(test the-sitemap-lists-every-page-in-both-languages-and-robots-points-to-it
  (call-with-site-built-for-search-engines
   (lambda (directory)
     (let* ((sitemap (uiop:read-file-string (merge-pathnames "sitemap.xml" directory)))
            (robots (uiop:read-file-string (merge-pathnames "robots.txt" directory)))
            (locations (loop for start = (search "<loc>" sitemap)
                               then (search "<loc>" sitemap :start2 end)
                             while start
                             for end = (search "</loc>" sitemap :start2 start)
                             collect (subseq sitemap (+ start (length "<loc>")) end))))
       (is (search "<urlset " sitemap))
       (is (member "https://example.org/docs/" locations :test #'string=))
       (is (member "https://example.org/docs/pt-br/" locations :test #'string=))
       (is (member "https://example.org/docs/sym/common-lisp/car/" locations :test #'string=))
       (is (member "https://example.org/docs/pt-br/pkg/alexandria/" locations :test #'string=))
       (is (not (member "https://example.org/docs/404.html" locations :test #'string=)))
       (is (= (length locations) (length (remove-duplicates locations :test #'string=))))
       (is (= (length locations)
              (length (directory (merge-pathnames "**/index.html" directory)))))
       (is (search "Sitemap: https://example.org/docs/sitemap.xml" robots))
       (is (search "Allow: /" robots))))))
