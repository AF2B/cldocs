;;;; render.lisp --- HTML for every page of the static site.
;;;;
;;;; Every function returns a string. Text is escaped by Spinneret, so
;;;; docstrings and symbol names can never inject markup. All visible words
;;;; come from CLDOCS/I18N, so pages render in the current *LOCALE*.

(defpackage #:cldocs/render
  (:use #:cl)
  (:import-from #:cldocs/clhs
                #:clhs-url)
  (:import-from #:cldocs/definition
                #:definition-clhs-page
                #:definition-docstring
                #:definition-kind
                #:definition-lambda-list
                #:definition-name)
  (:import-from #:cldocs/examples
                #:example-author
                #:example-steps
                #:step-result-lines)
  (:import-from #:cldocs/i18n
                #:*locale*
                #:locale-code
                #:locale-prefix
                #:other-locale
                #:tr
                #:translated-summary)
  (:import-from #:cldocs/model
                #:kind-label
                #:signature
                #:symbol-entry-definitions
                #:symbol-entry-kinds
                #:symbol-entry-name
                #:symbol-entry-package
                #:symbol-entry-summary)
  (:import-from #:cldocs/trails
                #:trail-intro
                #:localized-sections
                #:trail-slug
                #:trail-symbol-count
                #:trail-title)
  (:import-from #:cldocs/urls
                #:+about-path+
                #:+home-path+
                #:+terms-path+
                #:+trails-path+
                #:package-path
                #:page-href
                #:page-root
                #:search-index-file
                #:site-href
                #:symbol-path
                #:trail-path
                #:url-encode)
  (:import-from #:spinneret
                #:with-html-string)
  (:export #:render-home
           #:render-package
           #:render-symbol
           #:render-examples
           #:render-about
           #:render-not-found
           #:render-message
           #:render-terms
           #:render-trails-index
           #:render-trail
           #:layout-html
           #:+terms-version+
           #:*toolchain-note*
           #:*repository-url*
           #:*live-api-p*
           #:*base-path*))

(in-package #:cldocs/render)

(alexandria:define-constant +terms-version+ "2026-11-15"
  :test #'string=
  :documentation "Version of the contribution terms; bump it when the terms change.")

(defparameter *toolchain-note* nil
  "Text describing the SBCL and Quicklisp versions the data came from, or NIL.")

(defparameter *repository-url* nil
  "Public GitHub URL of the repository, or NIL; enables the contribution buttons.")

(defparameter *live-api-p* nil
  "True when the optional community server is deployed next to the site.")

(defparameter *base-path* "/"
  "Absolute path the site is served under, used by the 404 page; \"/cldocs/\" on GitHub Pages.")

(defparameter *api-path* "/api"
  "Where the optional community API lives, on the same origin as the site.")

(defparameter *community-script* "assets/community.js"
  "Script that loads and submits live community contributions.")

(defparameter *contribution-branch* "main"
  "Branch pull requests target.")

(defparameter *contribution-directory* "community/examples/"
  "Directory below the repository root that holds contributed examples.")

(defparameter *contributing-file* "CONTRIBUTING.md"
  "File that explains how to contribute.")

(setf spinneret:*always-quote* t)

(defun page-title (title)
  "Return the document title for a page called TITLE.

- TITLE: the page name, or NIL for the home page."
  (if title
      (format nil "~A | ~A" title (tr :site-name))
      (format nil "~A | ~A" (tr :site-name) (tr :tagline))))

(defun language-switch-html (root path)
  "Return the link to the same page in the other language, or NIL without a PATH.

- ROOT: relative prefix leading to the site root.
- PATH: the unlocalized path of the current page, or NIL."
  (when path
    (let ((target (other-locale)))
      (with-html-string
        (:a :href (let ((*locale* target)) (page-href root path))
            :hreflang (let ((*locale* target)) (locale-code))
            :lang (let ((*locale* target)) (locale-code))
            (tr :other-language-short))))))

(defun header-html (root path)
  "Return the site header with the search form.

- ROOT: relative prefix leading to the site root.
- PATH: the unlocalized path of the current page, or NIL."
  (with-html-string
    (:header :class "site-header"
      (:div :class "container"
        (:a :class "logo" :href (page-href root +home-path+)
            :aria-label (tr :logo-aria)
            (:span :class "logo-mark" "BORBA" (:span :class "dot" "."))
            (:span :class "logo-product" (tr :site-name)))
        (:form :class "search" :role "search" :action "#"
          (:input :id "search-input"
                  :type "search"
                  :name "q"
                  :placeholder (tr :search-placeholder)
                  :autocomplete "off"
                  :aria-label (tr :search-label)
                  :data-index (site-href root (search-index-file))
                  :data-root (page-href root ""))
          (:ul :id "search-results" :class "search-results" :hidden t))
        (:nav :class "site-nav" :aria-label (tr :nav-main)
          (:a :href (concatenate 'string (page-href root +home-path+) "#packages")
              (tr :nav-packages))
          (:a :href (page-href root +trails-path+) (tr :nav-trails))
          (:a :href (page-href root +about-path+) (tr :nav-about))
          (:raw (or (language-switch-html root path) "")))))))

(defun footer-html (root)
  "Return the site footer with the legal notices.

- ROOT: relative prefix leading to the site root."
  (with-html-string
    (:footer :class "site-footer"
      (:div :class "container"
        (:p (tr :footer-hyperspec))
        (:p (tr :footer-docstrings)
            (:a :href (page-href root +about-path+) (tr :licensing-details))
            " · "
            (:a :href (page-href root +terms-path+) (tr :contribution-terms)))
        (when *toolchain-note*
          (:p *toolchain-note*))))))

(defun layout-html (&key
                      title
                      description
                      path
                      root
                      body
                      scripts)
  "Wrap BODY, an HTML string, in the shared page layout.

- TITLE: page name, or NIL for the home page.
- DESCRIPTION: text for the description meta tag.
- PATH: unlocalized page path; enables the language switch and sets the root.
- ROOT: relative prefix to the site root; overrides the one derived from PATH.
- BODY: the already rendered main content.
- SCRIPTS: extra script paths below the site root, loaded after search.js."
  (let ((root (or root (page-root path))))
    (with-html-string
      (:doctype)
      (:html :lang (locale-code)
        (:head
          (:meta :charset "utf-8")
          (:meta :name "viewport" :content "width=device-width, initial-scale=1")
          (:title (page-title title))
          (:meta :name "description" :content description)
          (:link :rel "stylesheet" :href (site-href root "assets/tokens.css"))
          (:link :rel "stylesheet" :href (site-href root "assets/site.css"))
          (:script :src (site-href root "assets/search.js") :defer t)
          (dolist (script scripts)
            (:script :src (site-href root script) :defer t)))
        (:body
          (:raw (header-html root path))
          (:main :class "container" (:raw body))
          (:raw (footer-html root)))))))

(defun definition-html (definition)
  "Return the section describing one DEFINITION of a symbol.

- DEFINITION: a DEFINITION record."
  (let ((docstring (definition-docstring definition))
        (clhs-page (definition-clhs-page definition)))
    (with-html-string
      (:section :class "definition"
                :id (string-downcase (symbol-name (definition-kind definition)))
        (:div :class "definition-head"
          (:h2 :class "label" (kind-label (definition-kind definition)))
          (when clhs-page
            (:a :class "btn"
                :href (clhs-url clhs-page)
                :rel "noopener noreferrer"
                (tr :hyperspec))))
        (:pre :class "code"
              (signature (definition-name definition)
                         (definition-lambda-list definition)))
        (if docstring
            (:p :class "docstring" :lang "en" docstring)
            (:p :class "docstring-missing" (tr :no-docstring)))))))

(defun system-note (system)
  "Return the attribution sentence for SYSTEM, or NIL for the SBCL image.

- SYSTEM: metadata plist (:name :version :license) or NIL."
  (when system
    (tr :system-note
        (getf system :name)
        (getf system :version)
        (getf system :license))))

(defun span-html (class text)
  "Return a span of CLASS holding the escaped TEXT, with no extra whitespace.

- CLASS: the CSS class name.
- TEXT: the text shown inside the span."
  (with-html-string
    (:span :class class text)))

(defun author-html (author)
  "Return the credit line for a community AUTHOR as a link to their GitHub profile.

- AUTHOR: a GitHub login."
  (with-html-string
    (tr :example-by)
    (:a :href (format nil "https://github.com/~A" author)
        :rel "noopener noreferrer"
        (format nil "@~A" author))))

(defun example-html (example position)
  "Return one example as a terminal-style code block with its recorded results.

The block is assembled as one string so the browser sees no layout whitespace
inside the preformatted element.

- EXAMPLE: a recorded EXAMPLE.
- POSITION: its 1-based number among the examples of the symbol."
  (let* ((lines (loop for step in (example-steps example)
                      append (cons (span-html "form" (getf step :form))
                                   (mapcar (lambda (line)
                                             (span-html "result" line))
                                           (step-result-lines step)))))
         (text (format nil "~{~A~^~%~}" lines))
         (author (example-author example)))
    (with-html-string
      (:div :class "example"
        (:p :class "label"
            (tr :example-n position)
            (when author
              (:raw (author-html author))))
        (:pre (:raw text))))))

(defun render-examples (examples)
  "Return the Examples section body for EXAMPLES, or NIL when there are none.

- EXAMPLES: recorded EXAMPLE records of one symbol."
  (when examples
    (with-html-string
      (loop for example in examples
            for position from 1
            do (:raw (example-html example position)))
      (:p :class "attribution" (tr :examples-note)))))

(defun symbol-link-html (root package-name symbol-name)
  "Return a link chip pointing to another symbol page.

- ROOT: relative prefix leading to the site root.
- PACKAGE-NAME: package of the target symbol.
- SYMBOL-NAME: name of the target symbol."
  (with-html-string
    (:li (:a :href (page-href root (symbol-path package-name symbol-name))
             (string-downcase symbol-name)))))

(defun contribution-template (package-name symbol-name system)
  "Return the starter text of a contributed example file.

- PACKAGE-NAME: package of the documented symbol.
- SYMBOL-NAME: name of the documented symbol.
- SYSTEM: metadata plist of the providing system, or NIL for SBCL."
  (format nil ";;; author: YOUR-GITHUB-LOGIN~%;;; license: CC0-1.0~%~A~%(your-example-here)~%"
          (if system
              (format nil "== ~A:~A @ ~A" package-name symbol-name (getf system :name))
              (format nil "== ~A" symbol-name))))

(defun contribute-url (package-name symbol-name system)
  "Return the GitHub link that opens a new contribution file for a symbol.

- PACKAGE-NAME: package of the documented symbol.
- SYMBOL-NAME: name of the documented symbol.
- SYSTEM: metadata plist of the providing system, or NIL for SBCL."
  (let ((file (format nil "~A~A/~A.txt"
                      *contribution-directory*
                      (cldocs/slug:slugify package-name)
                      (cldocs/slug:slugify symbol-name))))
    (format nil "~A/new/~A?filename=~A&value=~A"
            *repository-url*
            *contribution-branch*
            (url-encode file)
            (url-encode (contribution-template package-name symbol-name system)))))

(defun contribute-html (package-name symbol-name system)
  "Return the Contribute section, or NIL when no repository URL is configured.

- PACKAGE-NAME: package of the documented symbol.
- SYMBOL-NAME: name of the documented symbol.
- SYSTEM: metadata plist of the providing system, or NIL for SBCL."
  (when *repository-url*
    (with-html-string
      (:section :class "block" :id "contribute"
        (:h2 (tr :contribute))
        (:p (tr :contribute-text))
        (:p
          (:a :class "btn"
              :href (contribute-url package-name symbol-name system)
              :rel "noopener noreferrer"
              (tr :contribute-button))
          " "
          (:a :class "btn"
              :href (format nil "~A/blob/~A/~A"
                            *repository-url* *contribution-branch* *contributing-file*)
              :rel "noopener noreferrer"
              (tr :contribute-guide)))))))

(defun render-symbol (entry
                      &key
                        examples-html
                        related
                        system)
  "Return the page of one symbol.

- ENTRY: a SYMBOL-ENTRY.
- EXAMPLES-HTML: pre-rendered examples section, or NIL.
- RELATED: list of (package-name . symbol-name) conses to show as See also.
- SYSTEM: metadata plist of the providing ASDF system, or NIL for SBCL."
  (let* ((package-name (symbol-entry-package entry))
         (name (symbol-entry-name entry))
         (path (symbol-path package-name name))
         (root (page-root path))
         (translated (translated-summary package-name name))
         (body (with-html-string
                 (:article :class "symbol"
                   (:p :class "label"
                     (:a :href (page-href root (package-path package-name))
                         package-name))
                   (:h1 :class "symbol-name" (string-downcase name))
                   (:ul :class "badges"
                     (dolist (kind (symbol-entry-kinds entry))
                       (:li :class "badge" (kind-label kind))))
                   (when translated
                     (:p :class "lede" (:strong (format nil "~A: " (tr :summary))) translated))
                   (dolist (definition (symbol-entry-definitions entry))
                     (:raw (definition-html definition)))
                   (when (system-note system)
                     (:p :class "attribution" (system-note system)))
                   (:section :class "block" :id "examples"
                     (:h2 (tr :examples))
                     (if examples-html
                         (:raw examples-html)
                         (:p :class "empty" (tr :no-examples))))
                   (:raw (or (contribute-html package-name name system) ""))
                   (when *live-api-p*
                     (:section :class "block community" :id "community" :hidden t
                               :data-api *api-path*
                               :data-package package-name
                               :data-symbol name
                       (:h2 (tr :community))
                       (:div :id "community-list")
                       (:div :id "community-form")))
                   (when related
                     (:section :class "block" :id "see-also"
                       (:h2 (tr :see-also))
                       (:ul :class "see-also"
                         (loop for (related-package . related-name) in related
                               do (:raw (symbol-link-html root
                                                          related-package
                                                          related-name))))))))))
    (layout-html :title (string-downcase name)
                 :description (let ((summary (symbol-entry-summary entry)))
                                (if (string= summary "")
                                    (format nil "~A (~A)" (string-downcase name) package-name)
                                    summary))
                 :path path
                 :body body
                 :scripts (when *live-api-p* (list *community-script*)))))

(defun package-section-html (root heading entries)
  "Return a heading followed by a grid of links to ENTRIES.

- ROOT: relative prefix leading to the site root.
- HEADING: the section title, a string.
- ENTRIES: the SYMBOL-ENTRY records listed in the section."
  (with-html-string
    (:section :class "block"
      (:h2 heading)
      (:ul :class "symbol-list"
        (dolist (entry entries)
          (:li (:a :href (page-href root (symbol-path (symbol-entry-package entry)
                                                      (symbol-entry-name entry)))
                   (:span :class "name" (string-downcase (symbol-entry-name entry)))
                   (:span :class "summary" (symbol-entry-summary entry)))))))))

(defun render-package (package-name
                       entries
                       kinds
                       &key
                         system)
  "Return the page listing every symbol of a package, grouped by kind.

- PACKAGE-NAME: package name, a string.
- ENTRIES: every SYMBOL-ENTRY of the package, sorted by name.
- KINDS: the kinds to show as sections, in display order.
- SYSTEM: metadata plist of the providing ASDF system, or NIL for SBCL."
  (let* ((path (package-path package-name))
         (root (page-root path))
         (body (with-html-string
                 (:p :class "label" (tr :package))
                 (:h1 :class "symbol-name" package-name)
                 (:p :class "lede" (tr :symbol-count (length entries)))
                 (when (system-note system)
                   (:p :class "attribution" (system-note system)))
                 (dolist (kind kinds)
                   (let ((members (remove-if-not
                                   (lambda (entry)
                                     (find kind (symbol-entry-kinds entry)))
                                   entries)))
                     (when members
                       (:raw (package-section-html root
                                                   (format nil "~A (~D)"
                                                           (kind-label kind)
                                                           (length members))
                                                   members))))))))
    (layout-html :title package-name
                 :description (tr :symbol-count (length entries))
                 :path path
                 :body body)))

(defun render-home (packages)
  "Return the home page.

- PACKAGES: list of (package-name symbol-count system) lists to advertise;
  SYSTEM is the metadata plist of the providing system, or NIL for SBCL."
  (let* ((root (page-root +home-path+))
         (body (with-html-string
                 (:h1 (tr :site-name) (:span :class "dot" "."))
                 (:p :class "lede" (tr :home-lede))
                 (:section :class "block" :id "packages"
                   (:h2 (tr :packages))
                   (:ul :class "package-list"
                     (loop for (package-name count system) in packages
                           do (:li (:a :href (page-href root (package-path package-name))
                                       (:span :class "name" package-name)
                                       (:span :class "summary"
                                              (if system
                                                  (tr :package-count-system
                                                      count
                                                      (getf system :name)
                                                      (getf system :version))
                                                  (tr :package-count-sbcl count)))))))))))
    (layout-html :title nil
                 :description (tr :tagline)
                 :path +home-path+
                 :body body)))

(defun trail-card-html (root entry)
  "Return a list item linking to the symbol described by ENTRY.

- ROOT: relative prefix leading to the site root.
- ENTRY: a SYMBOL-ENTRY."
  (with-html-string
    (:li (:a :href (page-href root (symbol-path (symbol-entry-package entry)
                                                (symbol-entry-name entry)))
             (:span :class "name" (string-downcase (symbol-entry-name entry)))
             (:span :class "summary" (symbol-entry-summary entry))))))

(defun render-trail (trail entries-by-symbol)
  "Return the page of one trail, with its sections of linked symbols.

- TRAIL: a TRAIL record.
- ENTRIES-BY-SYMBOL: table from (package . name) to SYMBOL-ENTRY."
  (let* ((path (trail-path (trail-slug trail)))
         (root (page-root path))
         (body (with-html-string
                 (:p :class "label"
                     (:a :href (page-href root +trails-path+) (tr :trail)))
                 (:h1 :class "symbol-name" (trail-title trail))
                 (:p :class "lede" (trail-intro trail))
                 (loop for (heading . symbols) in (localized-sections trail)
                       do (:section :class "block"
                            (:h2 heading)
                            (:ol :class "symbol-list"
                              (dolist (symbol symbols)
                                (let ((entry (gethash symbol entries-by-symbol)))
                                  (when entry
                                    (:raw (trail-card-html root entry)))))))))))
    (layout-html :title (trail-title trail)
                 :description (trail-intro trail)
                 :path path
                 :body body)))

(defun render-trails-index (trails)
  "Return the page that lists every trail.

- TRAILS: the TRAIL records, in display order."
  (let* ((root (page-root +trails-path+))
         (body (with-html-string
                 (:p :class "label" (tr :trails))
                 (:h1 (tr :trails))
                 (:p :class "lede" (tr :trails-lede))
                 (:ul :class "package-list"
                   (dolist (trail trails)
                     (:li (:a :href (page-href root (trail-path (trail-slug trail)))
                              (:span :class "name" (trail-title trail))
                              (:span :class "summary"
                                     (tr :trail-count (trail-symbol-count trail))))))))))
    (layout-html :title (tr :trails)
                 :description (tr :trails-lede)
                 :path +trails-path+
                 :body body)))

(defun render-about ()
  "Return the about and licensing page."
  (let* ((body (with-html-string
                 (:p :class "label" (tr :about))
                 (:h1 (tr :licensing))
                 (:section :class "block"
                   (:h2 (tr :about-hyperspec-heading))
                   (:p (tr :footer-hyperspec) (tr :about-hyperspec)))
                 (:section :class "block"
                   (:h2 (tr :about-docstrings-heading))
                   (:p (tr :about-docstrings)))
                 (:section :class "block"
                   (:h2 (tr :about-examples-heading))
                   (:p (tr :about-examples)))
                 (:section :class "block"
                   (:h2 (tr :about-translations-heading))
                   (:p (tr :about-translations))))))
    (layout-html :title (tr :licensing)
                 :description (tr :licensing)
                 :path +about-path+
                 :body body)))

(defun render-not-found ()
  "Return the page served for unknown paths, with links that work from any URL."
  (let ((body (with-html-string
                (:p :class "label" "404")
                (:h1 (tr :not-found))
                (:p :class "lede" (tr :not-found-text)))))
    (layout-html :title (tr :not-found)
                 :description (tr :not-found)
                 :root *base-path*
                 :body body)))

(defun render-message (title message)
  "Return a small page with a heading and one sentence, for server responses.

Links use absolute paths because the page may be served from any URL.

- TITLE: the heading.
- MESSAGE: the sentence shown below it."
  (let ((body (with-html-string
                (:h1 title)
                (:p :class "lede" message))))
    (let ((*locale* :en))
      (layout-html :title title
                   :description message
                   :root "/"
                   :body body))))

(defun render-terms ()
  "Return the contribution terms page."
  (let ((body (with-html-string
                (:p :class "label" (tr :terms-version +terms-version+))
                (:h1 (tr :terms))
                (:section :class "block"
                  (:h2 (tr :terms-give-heading))
                  (:p (tr :terms-give)))
                (:section :class "block"
                  (:h2 (tr :terms-review-heading))
                  (:p (tr :terms-review)))
                (:section :class "block"
                  (:h2 (tr :terms-limits-heading))
                  (:p (tr :terms-limits)))
                (:section :class "block"
                  (:h2 (tr :terms-data-heading))
                  (:p (tr :terms-data)))
                (:section :class "block"
                  (:h2 (tr :terms-back-heading))
                  (:p (tr :terms-back))))))
    (layout-html :title (tr :terms)
                 :description (tr :terms)
                 :path +terms-path+
                 :body body)))
