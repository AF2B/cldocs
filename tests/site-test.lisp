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
    (probe-file (merge-pathnames file page-directory))))

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
    (is (not (search "<b>" html)))
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
           (list "node" "--test" "tests/")
           :directory (asdf:system-relative-pathname "cldocs" "")
           :environment (list (format nil "CLDOCS_INDEX=~A"
                                      (namestring
                                       (merge-pathnames "assets/search-index.json"
                                                        (built-site)))))
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
