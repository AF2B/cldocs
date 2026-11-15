;;;; render.lisp --- HTML for every page of the static site.
;;;;
;;;; Every function returns a string. Text is escaped by Spinneret, so
;;;; docstrings and symbol names can never inject markup.

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
                #:example-steps
                #:step-result-lines)
  (:import-from #:cldocs/model
                #:docstring-summary
                #:kind-label
                #:signature
                #:symbol-entry-definitions
                #:symbol-entry-kinds
                #:symbol-entry-name
                #:symbol-entry-package
                #:symbol-entry-summary)
  (:import-from #:cldocs/urls
                #:+about-path+
                #:+home-path+
                #:+search-index-path+
                #:+terms-path+
                #:package-path
                #:root-prefix
                #:site-href
                #:symbol-path)
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
           #:layout-html
           #:+terms-version+
           #:*toolchain-note*))

(in-package #:cldocs/render)

(alexandria:define-constant +terms-version+ "2026-11"
  :test #'string=
  :documentation "Version of the contribution terms; bump it when the terms change.")

(defparameter *site-name* "CLDocs"
  "Name shown in the header and in page titles.")

(defparameter *tagline* "Community reference for Common Lisp."
  "One-line description of the site.")

(defparameter *toolchain-note* nil
  "Text describing the SBCL and Quicklisp versions the data came from, or NIL.")

(defparameter *search-placeholder* "Search symbols: car, mapcar, *print-base*"
  "Hint shown inside the empty search box.")

(defparameter *hyperspec-notice*
  "The Common Lisp HyperSpec is copyright LispWorks Ltd. CLDocs links to it and never copies its text or images."
  "Legal notice shown in the footer of every page.")

(defparameter *api-path* "/api"
  "Where the community API lives, on the same origin as the site.")

(defparameter *community-script* "assets/community.js"
  "Script that loads and submits community contributions.")

(defparameter *no-docstring-notice*
  "No documentation string is available in the implementation."
  "Shown when a definition carries no docstring.")

(setf spinneret:*always-quote* t)

(defun page-title (title)
  "Return the document title for a page called TITLE.

- TITLE: the page name, or NIL for the home page."
  (if title
      (format nil "~A | ~A" title *site-name*)
      (format nil "~A | ~A" *site-name* *tagline*)))

(defun header-html (root)
  "Return the site header with the search form.

- ROOT: relative prefix leading to the site root."
  (with-html-string
    (:header :class "site-header"
      (:div :class "container"
        (:a :class "logo" :href (site-href root +home-path+)
            :aria-label "CLDocs home"
            (:span :class "logo-mark" "BORBA" (:span :class "dot" "."))
            (:span :class "logo-product" "CLDocs"))
        (:form :class "search" :role "search" :action "#"
          (:input :id "search-input"
                  :type "search"
                  :name "q"
                  :placeholder *search-placeholder*
                  :autocomplete "off"
                  :aria-label "Search symbols"
                  :data-index (site-href root +search-index-path+)
                  :data-root root)
          (:ul :id "search-results" :class "search-results" :hidden t))
        (:nav :class "site-nav" :aria-label "Main"
          (:a :href (concatenate 'string (site-href root +home-path+) "#packages")
              "Packages")
          (:a :href (site-href root +about-path+) "About"))))))

(defun footer-html (root)
  "Return the site footer with the legal notices.

- ROOT: relative prefix leading to the site root."
  (with-html-string
    (:footer :class "site-footer"
      (:div :class "container"
        (:p *hyperspec-notice*)
        (:p "Docstrings come from the documented implementation under its own license. "
            (:a :href (site-href root +about-path+) "Licensing details")
            " · "
            (:a :href (site-href root +terms-path+) "Contribution terms"))
        (when *toolchain-note*
          (:p *toolchain-note*))))))

(defun layout-html (&key
                      title
                      description
                      root
                      body
                      scripts)
  "Wrap BODY, an HTML string, in the shared page layout.

- TITLE: page name, or NIL for the home page.
- DESCRIPTION: text for the description meta tag.
- ROOT: relative prefix leading to the site root.
- BODY: the already rendered main content.
- SCRIPTS: extra script paths below the site root, loaded after search.js."
  (with-html-string
    (:doctype)
    (:html :lang "en"
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
        (:raw (header-html root))
        (:main :class "container" (:raw body))
        (:raw (footer-html root))))))

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
                "HyperSpec")))
        (:pre :class "code"
              (signature (definition-name definition)
                         (definition-lambda-list definition)))
        (if docstring
            (:p :class "docstring" docstring)
            (:p :class "docstring-missing" *no-docstring-notice*))))))

(defun system-note (system)
  "Return the attribution sentence for SYSTEM, or NIL for the SBCL image.

- SYSTEM: metadata plist (:name :version :license) or NIL."
  (when system
    (format nil "Documentation from ~A ~A, licensed ~A."
            (getf system :name)
            (getf system :version)
            (getf system :license))))

(defun span-html (class text)
  "Return a span of CLASS holding the escaped TEXT, with no extra whitespace.

- CLASS: the CSS class name.
- TEXT: the text shown inside the span."
  (with-html-string
    (:span :class class text)))

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
         (text (format nil "~{~A~^~%~}" lines)))
    (with-html-string
      (:div :class "example"
        (:p :class "label" (format nil "Example ~D" position))
        (:pre (:raw text))))))

(defun render-examples (examples)
  "Return the Examples section body for EXAMPLES, or NIL when there are none.

- EXAMPLES: recorded EXAMPLE records of one symbol."
  (when examples
    (with-html-string
      (loop for example in examples
            for position from 1
            do (:raw (example-html example position)))
      (:p :class "attribution"
          "Examples are dedicated to the public domain (CC0 1.0) and checked by running them in SBCL."))))

(defun symbol-link-html (root package-name symbol-name)
  "Return a link chip pointing to another symbol page.

- ROOT: relative prefix leading to the site root.
- PACKAGE-NAME: package of the target symbol.
- SYMBOL-NAME: name of the target symbol."
  (with-html-string
    (:li (:a :href (site-href root (symbol-path package-name symbol-name))
             (string-downcase symbol-name)))))

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
         (root (root-prefix (symbol-path package-name name)))
         (body (with-html-string
                 (:article :class "symbol"
                   (:p :class "label"
                     (:a :href (site-href root (package-path package-name))
                         package-name))
                   (:h1 :class "symbol-name" (string-downcase name))
                   (:ul :class "badges"
                     (dolist (kind (symbol-entry-kinds entry))
                       (:li :class "badge" (kind-label kind))))
                   (dolist (definition (symbol-entry-definitions entry))
                     (:raw (definition-html definition)))
                   (when (system-note system)
                     (:p :class "attribution" (system-note system)))
                   (:section :class "block" :id "examples"
                     (:h2 "Examples")
                     (if examples-html
                         (:raw examples-html)
                         (:p :class "empty" "No examples yet.")))
                   (:section :class "block community" :id "community" :hidden t
                             :data-api *api-path*
                             :data-package package-name
                             :data-symbol name
                     (:h2 "Community")
                     (:div :id "community-list")
                     (:div :id "community-form"))
                   (when related
                     (:section :class "block" :id "see-also"
                       (:h2 "See also")
                       (:ul :class "see-also"
                         (loop for (related-package . related-name) in related
                               do (:raw (symbol-link-html root
                                                          related-package
                                                          related-name))))))))))
    (layout-html :title (string-downcase name)
                 :description (let ((summary (symbol-entry-summary entry)))
                                (if (string= summary "")
                                    (format nil "~A in package ~A." (string-downcase name) package-name)
                                    summary))
                 :root root
                 :body body
                 :scripts (list *community-script*))))

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
          (:li (:a :href (site-href root (symbol-path (symbol-entry-package entry)
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
  (let* ((root (root-prefix (package-path package-name)))
         (body (with-html-string
                 (:p :class "label" "Package")
                 (:h1 :class "symbol-name" package-name)
                 (:p :class "lede"
                     (format nil "~D symbols." (length entries)))
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
                 :description (format nil "Every exported symbol of package ~A." package-name)
                 :root root
                 :body body)))

(defun render-home (packages)
  "Return the home page.

- PACKAGES: list of (package-name symbol-count system) lists to advertise;
  SYSTEM is the metadata plist of the providing system, or NIL for SBCL."
  (let* ((root (root-prefix +home-path+))
         (body (with-html-string
                 (:h1 "CLDocs" (:span :class "dot" "."))
                 (:p :class "lede"
                     "Every symbol of Common Lisp on its own page: signature, documentation, examples and cross references.")
                 (:section :class "block" :id "packages"
                   (:h2 "Packages")
                   (:ul :class "package-list"
                     (loop for (package-name count system) in packages
                           do (:li (:a :href (site-href root (package-path package-name))
                                       (:span :class "name" package-name)
                                       (:span :class "summary"
                                              (if system
                                                  (format nil "~D symbols · ~A ~A"
                                                          count
                                                          (getf system :name)
                                                          (getf system :version))
                                                  (format nil "~D symbols · SBCL" count)))))))))))
    (layout-html :title nil
                 :description *tagline*
                 :root root
                 :body body)))

(defun render-about ()
  "Return the about and licensing page."
  (let* ((root (root-prefix +about-path+))
         (body (with-html-string
                 (:p :class "label" "About")
                 (:h1 "Licensing")
                 (:section :class "block"
                   (:h2 "Common Lisp HyperSpec")
                   (:p *hyperspec-notice*
                       " Each HyperSpec button on a symbol page leads to the official copy hosted by LispWorks."))
                 (:section :class "block"
                   (:h2 "Signatures and documentation strings")
                   (:p "Extracted by introspection from SBCL, which is in the public domain apart from some files under BSD-style licenses. Library docstrings keep the license of their system, shown on each page."))
                 (:section :class "block"
                   (:h2 "Examples")
                   (:p "Examples written for CLDocs are dedicated to the public domain under CC0 1.0. Each one is executed in SBCL by the test suite and its printed results are checked.")))))
    (layout-html :title "Licensing"
                 :description "Licenses and attribution for CLDocs content."
                 :root root
                 :body body)))

(defun render-not-found ()
  "Return the page served for unknown paths."
  (let* ((root "")
         (body (with-html-string
                 (:p :class "label" "404")
                 (:h1 "Not found")
                 (:p :class "lede" "No such page. Try the search box above."))))
    (layout-html :title "Not found"
                 :description "Page not found."
                 :root root
                 :body body)))

(defun render-message (title message)
  "Return a small page with a heading and one sentence, for server responses.

Links use absolute paths because the page may be served from any URL.

- TITLE: the heading.
- MESSAGE: the sentence shown below it."
  (let* ((root "/")
         (body (with-html-string
                 (:h1 title)
                 (:p :class "lede" message))))
    (layout-html :title title
                 :description message
                 :root root
                 :body body)))

(defun render-terms ()
  "Return the contribution terms page."
  (let* ((root (root-prefix +terms-path+))
         (body (with-html-string
                 (:p :class "label" (format nil "Version ~A" +terms-version+))
                 (:h1 "Contribution terms")
                 (:section :class "block"
                   (:h2 "What you give")
                   (:p "Anything you submit, an example or a note, is dedicated to the public domain under CC0 1.0. You must be the author, or have the right to dedicate it. Do not submit code or text copied from the HyperSpec, from books or from projects whose license forbids it."))
                 (:section :class "block"
                   (:h2 "Review")
                   (:p "Every contribution waits for a moderator before it appears. Moderators may reject or hide anything that is spam, advertising, abusive, misleading, unsafe or off topic. Readers can flag published items; enough flags send an item back to review. Contributions are never executed by CLDocs."))
                 (:section :class "block"
                   (:h2 "Limits")
                   (:p "Contributions are limited to 4000 characters and a few links, and each account can submit ten per hour."))
                 (:section :class "block"
                   (:h2 "Your data")
                   (:p "Signing in with GitHub gives CLDocs your public GitHub account number and login. No other profile data, and no GitHub permissions, are requested. A session cookie keeps you signed in for seven days; there are no analytics or advertising cookies. Your login is shown next to what you publish."))
                 (:section :class "block"
                   (:h2 "Taking things back")
                   (:p "You can withdraw anything you published, which removes it from public view. Because contributions are public domain, copies others made stay theirs.")))))
    (layout-html :title "Contribution terms"
                 :description "Terms for contributing examples and notes to CLDocs."
                 :root root
                 :body body)))
