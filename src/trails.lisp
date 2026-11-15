;;;; trails.lisp --- Themed reading paths through the documented symbols.
;;;;
;;;; A trail is data in data/trails/<slug>.sexp: a localized title and intro and
;;;; ordered sections of symbols. Symbols are written "NAME" for COMMON-LISP or
;;;; "PACKAGE:NAME" for a library.

(defpackage #:cldocs/trails
  (:use #:cl)
  (:import-from #:cldocs/i18n
                #:*locale*)
  (:import-from #:cldocs/store
                #:data-directory
                #:read-data-file)
  (:export #:trail
           #:make-trail
           #:trail-slug
           #:trail-order
           #:trail-title
           #:trail-intro
           #:localized-sections
           #:trail-symbol-keys
           #:trail-symbol-count
           #:load-trails))

(in-package #:cldocs/trails)

(defparameter *trails-directory* "trails/"
  "Directory below the data root holding one file per trail.")

(defparameter *default-package* "COMMON-LISP"
  "Package assumed for trail symbols written without a package prefix.")

(defparameter *package-separator* #\:
  "Separates the package from the symbol name in a trail entry.")

(defstruct (trail (:copier nil))
  "A themed reading path.

- SLUG: URL-safe name, a string.
- ORDER: position in the trails index.
- TITLES: plist from locale to title.
- INTROS: plist from locale to introduction.
- SECTIONS: list of (HEADINGS . SYMBOL-NAMES) where HEADINGS is a plist from
  locale to heading text."
  (slug "" :type string :read-only t)
  (order 0 :type integer :read-only t)
  (titles '() :type list :read-only t)
  (intros '() :type list :read-only t)
  (sections '() :type list :read-only t))

(defun symbol-key (text)
  "Return the (package . name) key written as TEXT in a trail.

- TEXT: \"NAME\" or \"PACKAGE:NAME\"."
  (let ((colon (position *package-separator* text)))
    (if colon
        (cons (subseq text 0 colon) (subseq text (1+ colon)))
        (cons *default-package* text))))

(defun localized (plist)
  "Return the value PLIST holds for the current locale, falling back to English.

- PLIST: a plist from locale to text."
  (or (getf plist *locale*) (getf plist :en)))

(defun trail-title (trail)
  "Return the title of TRAIL in the current locale.

- TRAIL: a TRAIL."
  (localized (trail-titles trail)))

(defun trail-intro (trail)
  "Return the introduction of TRAIL in the current locale.

- TRAIL: a TRAIL."
  (localized (trail-intros trail)))

(defun localized-sections (trail)
  "Return the sections of TRAIL as (heading . symbol-keys) conses in the current locale.

- TRAIL: a TRAIL."
  (mapcar (lambda (section)
            (cons (localized (car section))
                  (mapcar #'symbol-key (cdr section))))
          (trail-sections trail)))

(defun trail-symbol-keys (trail)
  "Return every (package . name) key of TRAIL, in reading order.

- TRAIL: a TRAIL."
  (loop for section in (trail-sections trail)
        append (mapcar #'symbol-key (cdr section))))

(defun trail-symbol-count (trail)
  "Return how many symbols TRAIL lists.

- TRAIL: a TRAIL."
  (length (trail-symbol-keys trail)))

(defun read-trail (pathname)
  "Read the trail stored in PATHNAME.

- PATHNAME: a data/trails file."
  (let ((plist (read-data-file pathname)))
    (make-trail :slug (getf plist :slug)
                :order (getf plist :order)
                :titles (getf plist :title)
                :intros (getf plist :intro)
                :sections (getf plist :sections))))

(defun load-trails ()
  "Return every trail, ordered for the index."
  (let ((pattern (merge-pathnames (make-pathname :name :wild :type "sexp")
                                  (merge-pathnames *trails-directory* (data-directory)))))
    (sort (mapcar #'read-trail (directory pattern)) #'< :key #'trail-order)))
