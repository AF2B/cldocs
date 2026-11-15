;;;; i18n.lisp --- Locales, interface strings and translated symbol summaries.
;;;;
;;;; Strings live in data/i18n/messages.sexp and per-symbol Portuguese summaries
;;;; in data/i18n/pt-br/<package>.sexp, so translations are plain data that
;;;; contributors can send as pull requests.

(defpackage #:cldocs/i18n
  (:use #:cl)
  (:import-from #:cldocs/slug
                #:slugify)
  (:import-from #:cldocs/store
                #:data-directory
                #:read-data-file)
  (:export #:*locale*
           #:+locales+
           #:locale-prefix
           #:locale-code
           #:other-locale
           #:message
           #:tr
           #:message-keys
           #:translated-summary
           #:reset-i18n-cache))

(in-package #:cldocs/i18n)

(alexandria:define-constant +locales+ '(:en :pt-br)
  :test #'equal
  :documentation "Every locale the site is generated in; :EN is the default.")

(defvar *locale* :en
  "Locale used by every renderer; rebound by the site builder for each language.")

(defparameter *locale-prefixes* '((:en . "") (:pt-br . "pt-br/"))
  "Path prefix below the site root where each locale's pages live.")

(defparameter *locale-codes* '((:en . "en") (:pt-br . "pt-BR"))
  "Value of the HTML lang attribute for each locale.")

(defparameter *messages-file* "i18n/messages.sexp"
  "File below the data root holding the interface strings.")

(defparameter *summaries-directory* "i18n/pt-br/"
  "Directory below the data root holding translated symbol summaries.")

(defvar *messages* nil
  "Lazily loaded hash table from message key to its plist of translations.")

(defvar *summaries* (make-hash-table :test #'equal)
  "Cache of translated summaries, keyed by package name.")

(defun locale-prefix (&optional (locale *locale*))
  "Return the path prefix of LOCALE's pages, \"\" for the default locale.

- LOCALE: a keyword from +LOCALES+."
  (cdr (assoc locale *locale-prefixes*)))

(defun locale-code (&optional (locale *locale*))
  "Return the HTML language code of LOCALE.

- LOCALE: a keyword from +LOCALES+."
  (cdr (assoc locale *locale-codes*)))

(defun other-locale (&optional (locale *locale*))
  "Return the locale offered by the language switch while LOCALE is shown.

- LOCALE: a keyword from +LOCALES+."
  (if (eq locale :en) :pt-br :en))

(defun messages ()
  "Return the table of interface strings, loading it on first use."
  (or *messages*
      (setf *messages*
            (let ((table (make-hash-table :test #'eq)))
              (dolist (entry (read-data-file (merge-pathnames *messages-file*
                                                              (data-directory)))
                             table)
                (setf (gethash (first entry) table) (rest entry)))))))

(defun message (key &optional (locale *locale*))
  "Return the unformatted string KEY has in LOCALE.

Signals an error when the key or its translation is missing.

- KEY: a message keyword.
- LOCALE: a keyword from +LOCALES+."
  (let ((plist (gethash key (messages))))
    (or (getf plist locale)
        (error "No ~S translation for message ~S." locale key))))

(defun tr (key &rest arguments)
  "Return the message KEY in the current locale, formatted with ARGUMENTS.

- KEY: a message keyword.
- ARGUMENTS: values for the ~A and ~D directives of the message."
  (apply #'format nil (message key) arguments))

(defun message-keys ()
  "Return every message key, for tests that check translations are complete."
  (let ((keys '()))
    (maphash (lambda (key plist) (declare (ignore plist)) (push key keys)) (messages))
    keys))

(defun summaries-for (package-name)
  "Return the table of translated summaries of PACKAGE-NAME, empty when none exist.

- PACKAGE-NAME: a package name, a string."
  (or (gethash package-name *summaries*)
      (setf (gethash package-name *summaries*)
            (let ((table (make-hash-table :test #'equal))
                  (pathname (merge-pathnames
                             (make-pathname :name (slugify package-name) :type "sexp")
                             (merge-pathnames *summaries-directory* (data-directory)))))
              (when (probe-file pathname)
                (loop for (name . text) in (read-data-file pathname)
                      do (setf (gethash name table) text)))
              table))))

(defun translated-summary (package-name symbol-name)
  "Return the Portuguese summary of a symbol, or NIL when the locale is English
or no translation exists.

- PACKAGE-NAME: the symbol's package, a string.
- SYMBOL-NAME: the symbol's name, a string."
  (unless (eq *locale* :en)
    (values (gethash symbol-name (summaries-for package-name)))))

(defun reset-i18n-cache ()
  "Forget cached messages and summaries so the next lookup reloads them."
  (setf *messages* nil)
  (clrhash *summaries*))
