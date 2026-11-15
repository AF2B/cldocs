;;;; examples.lisp --- Seeded examples: parse, run, record and verify.
;;;;
;;;; Authoring format (data/examples-src/<package>.txt), one block per example:
;;;;
;;;;   == CAR                      header: NAME, or PACKAGE:NAME @ SYSTEM
;;;;   (car '(a b c))              every top-level form is one step
;;;;   -- silent                   next step runs but shows no result
;;;;   (defclass point () ())
;;;;
;;;; Recording runs each step and stores printed values, output or the type
;;;; of the condition signalled in data/examples/<package>.sexp. Only trusted,
;;;; repository-owned examples are ever executed.

(defpackage #:cldocs/examples
  (:use #:cl)
  (:import-from #:cldocs/conditions
                #:example-step-failed
                #:malformed-data-file
                #:malformed-example-source)
  (:import-from #:cldocs/slug
                #:slugify)
  (:import-from #:cldocs/store
                #:data-directory
                #:read-data-file)
  (:export #:example
           #:make-example
           #:example-package
           #:example-name
           #:example-uses
           #:example-system
           #:example-steps
           #:parse-examples-source
           #:run-example
           #:verify-example
           #:record-examples
           #:read-examples
           #:write-examples
           #:examples-source-pathname
           #:examples-pathname
           #:step-result-lines))

(in-package #:cldocs/examples)

(defparameter *header-prefix* "== "
  "Marks the first line of an example block in the source file.")

(defparameter *silent-marker* "-- silent"
  "Marks the next step as setup whose result is neither shown nor checked.")

(defparameter *package-separator* #\:
  "Separates the package from the symbol name in a block header.")

(defparameter *system-separator* " @ "
  "Separates the symbol from the ASDF system in a block header.")

(defparameter *example-package-prefix* "CLDOCS-EXAMPLE-"
  "Name prefix of the throwaway packages examples run in.")

(defparameter *source-type* "txt"
  "File type of authoring files.")

(defparameter *recorded-type* "sexp"
  "File type of recorded files.")

(defparameter *no-values-line* ";; => (no values)"
  "Result line shown for a step that returns no values.")

(defvar *example-counter* 0
  "Counter that keeps throwaway package names unique.")

(defstruct (example (:copier nil))
  "A runnable example for one symbol.

- PACKAGE: package of the documented symbol, a string.
- NAME: name of the documented symbol, a string.
- USES: names of extra packages the example package uses.
- SYSTEM: ASDF system to load before running, or NIL.
- STEPS: list of step plists (:form TEXT [:silent T] [:values ..] [:output ..] [:error ..])."
  (package "COMMON-LISP" :type string :read-only t)
  (name "" :type string :read-only t)
  (uses '() :type list :read-only t)
  (system nil :type (or null string) :read-only t)
  (steps '() :type list :read-only t))

;;; Parsing the authoring format

(defun blank-end (text position)
  "Return the first index at or after POSITION that is not blank or a comment.

- TEXT: the block text.
- POSITION: where to start looking."
  (loop
    (cond ((>= position (length text)) (return position))
          ((member (char text position) '(#\Space #\Tab #\Newline #\Return))
           (incf position))
          ((char= (char text position) #\;)
           (setf position (or (position #\Newline text :start position)
                              (length text))))
          (t (return position)))))

(defun form-end (text start)
  "Return the index just after the form that begins at START.

Reads with *READ-SUPPRESS* so forms from libraries that are not loaded
still parse. Signals MALFORMED-EXAMPLE-SOURCE on unbalanced input.

- TEXT: the block text.
- START: index of the first character of the form."
  (handler-case
      (let ((*read-suppress* t)
            (*read-eval* nil))
        (nth-value 1 (read-from-string text t nil
                                       :start start
                                       :preserve-whitespace t)))
    (error (condition)
      (error 'malformed-example-source
             :reason (format nil "cannot read form at ~S: ~A"
                             (subseq text start (min (length text) (+ start 40)))
                             condition)))))

(defun parse-steps (text)
  "Split the block TEXT into step plists, one per top-level form.

- TEXT: the lines of one example block."
  (let ((steps '())
        (silent nil)
        (position 0))
    (loop
      (setf position (blank-end text position))
      (when (>= position (length text))
        (return))
      (cond ((uiop:string-prefix-p *silent-marker* (subseq text position))
             (setf silent t
                   position (or (position #\Newline text :start position)
                                (length text))))
            (t
             (let ((end (form-end text position)))
               (push (append (list :form (subseq text position end))
                             (when silent (list :silent t)))
                     steps)
               (setf silent nil
                     position end)))))
    (nreverse steps)))

(defun parse-header (line)
  "Return the example skeleton described by the header LINE.

- LINE: a line starting with the header prefix."
  (let* ((spec (string-trim " " (subseq line (length *header-prefix*))))
         (system-position (search *system-separator* spec))
         (symbol-spec (subseq spec 0 system-position))
         (system (when system-position
                   (string-trim " " (subseq spec (+ system-position
                                                    (length *system-separator*))))))
         (colon (position *package-separator* symbol-spec)))
    (when (string= symbol-spec "")
      (error 'malformed-example-source :reason (format nil "empty header ~S" line)))
    (if colon
        (let ((package (subseq symbol-spec 0 colon)))
          (list :package package
                :name (subseq symbol-spec (1+ colon))
                :uses (list package)
                :system system))
        (list :package "COMMON-LISP" :name symbol-spec :uses '() :system system))))

(defun parse-examples-source (text)
  "Parse the authoring TEXT into a list of EXAMPLE records without results.

- TEXT: the contents of a data/examples-src file."
  (let ((examples '())
        (header nil)
        (block-lines '()))
    (flet ((finish ()
             (when header
               (push (make-example
                      :package (getf header :package)
                      :name (getf header :name)
                      :uses (getf header :uses)
                      :system (getf header :system)
                      :steps (parse-steps (format nil "~{~A~%~}" (reverse block-lines))))
                     examples))
             (setf block-lines '())))
      (dolist (line (uiop:split-string text :separator '(#\Newline)))
        (cond ((uiop:string-prefix-p *header-prefix* line)
               (finish)
               (setf header (parse-header line)))
              (header (push line block-lines))))
      (finish))
    (nreverse examples)))

;;; Running

(defun condition-type-name (condition)
  "Return the printed type name of CONDITION without a package prefix.

- CONDITION: a condition object."
  (with-standard-io-syntax
    (let ((*package* (find-package "COMMON-LISP"))
          (*print-readably* nil))
      (prin1-to-string (type-of condition)))))

(defun print-values (values package)
  "Return the printed representation of each of VALUES as read inside PACKAGE.

- VALUES: a list of Lisp objects.
- PACKAGE: the package that decides how symbols print."
  (with-standard-io-syntax
    (let ((*package* package)
          (*print-readably* nil))
      (mapcar #'prin1-to-string values))))

(defun evaluate-step (text package)
  "Evaluate the form in TEXT inside PACKAGE and describe what happened.

Returns a plist with :VALUES (printed strings), :OUTPUT (when anything was
printed) and :ERROR (type name) when the form signalled an error.

- TEXT: source of one form.
- PACKAGE: the throwaway package to evaluate in."
  (let ((captured (make-string-output-stream))
        (values '())
        (failure nil))
    (let ((*package* package)
          (*standard-output* captured)
          (*error-output* captured)
          (*read-eval* nil))
      (handler-case
          (setf values
                (handler-bind ((warning #'muffle-warning))
                  (multiple-value-list (eval (read-from-string text)))))
        (serious-condition (condition)
          (setf failure (condition-type-name condition)))))
    (let ((output (get-output-stream-string captured)))
      (append (if failure
                  (list :error failure)
                  (list :values (print-values values package)))
              (when (string/= output "")
                (list :output output))))))

(defun ensure-system-loaded (system)
  "Load the ASDF SYSTEM through Quicklisp when present, otherwise ASDF.

- SYSTEM: the system name, or NIL for nothing to load."
  (when system
    (if (find-package '#:ql)
        (uiop:symbol-call '#:ql '#:quickload system :silent t)
        (asdf:load-system system))))

(defun call-with-example-package (example function)
  "Call FUNCTION with a fresh package for EXAMPLE, deleting it afterwards.

- EXAMPLE: the EXAMPLE about to run.
- FUNCTION: a function of one argument, the package."
  (ensure-system-loaded (example-system example))
  (let ((package (make-package (format nil "~A~D" *example-package-prefix*
                                       (incf *example-counter*))
                               :use (list* "COMMON-LISP" (example-uses example)))))
    (unwind-protect (funcall function package)
      (delete-package package))))

(defun run-example (example)
  "Run EXAMPLE in a fresh package and return its steps with fresh results.

Silent steps are executed but only record a failure.

- EXAMPLE: an EXAMPLE whose steps carry at least a :FORM."
  (call-with-example-package
   example
   (lambda (package)
     (loop for step in (example-steps example)
           for text = (getf step :form)
           for result = (evaluate-step text package)
           collect (if (getf step :silent)
                       (append (list :form text :silent t)
                               (when (getf result :error)
                                 (list :error (getf result :error))))
                       (append (list :form text) result))))))

(defun verify-example (example)
  "Re-run a recorded EXAMPLE and return the steps whose results differ.

The result is a list of (form expected actual) lists; NIL means it verified.

- EXAMPLE: an EXAMPLE read from recorded data."
  (loop for expected in (example-steps example)
        for actual in (run-example example)
        unless (equal expected actual)
          collect (list (getf expected :form) expected actual)))

;;; Files

(defun examples-source-pathname (package-name)
  "Return the authoring file of PACKAGE-NAME.

- PACKAGE-NAME: the documented package, a string."
  (merge-pathnames (make-pathname :directory '(:relative "examples-src")
                                  :name (slugify package-name)
                                  :type *source-type*)
                   (data-directory)))

(defun examples-pathname (package-name)
  "Return the recorded examples file of PACKAGE-NAME.

- PACKAGE-NAME: the documented package, a string."
  (merge-pathnames (make-pathname :directory '(:relative "examples")
                                  :name (slugify package-name)
                                  :type *recorded-type*)
                   (data-directory)))

(defun write-examples (package-name examples)
  "Write recorded EXAMPLES of PACKAGE-NAME and return the pathname.

- PACKAGE-NAME: the documented package, a string.
- EXAMPLES: recorded EXAMPLE records."
  (let ((pathname (examples-pathname package-name)))
    (ensure-directories-exist pathname)
    (with-standard-io-syntax
      (let ((*print-readably* nil))
        (with-open-file (out pathname
                             :direction :output
                             :if-exists :supersede
                             :external-format :utf-8)
          (format out ";;;; Generated by scripts/record-examples.lisp from examples-src; do not edit.~%")
          (format out ";;;; Examples are dedicated to the public domain under CC0 1.0.~%")
          (format out "(:package ~S~% :examples~% (" package-name)
          (dolist (example examples)
            (format out "~%  (:symbol ~S :uses ~S :system ~S~%   :steps~%   ("
                    (example-name example)
                    (example-uses example)
                    (example-system example))
            (dolist (step (example-steps example))
              (format out "~%    ~S" step))
            (format out "))"))
          (format out ")~% )~%"))))
    pathname))

(defun read-examples (package-name)
  "Return the recorded EXAMPLE records of PACKAGE-NAME, or NIL without a file.

- PACKAGE-NAME: the documented package, a string."
  (let ((pathname (examples-pathname package-name)))
    (when (probe-file pathname)
      (let ((form (read-data-file pathname)))
        (unless (and (consp form) (string= (getf form :package) package-name))
          (error 'malformed-data-file
                 :pathname pathname
                 :reason "package name does not match file"))
        (mapcar (lambda (plist)
                  (make-example :package package-name
                                :name (getf plist :symbol)
                                :uses (getf plist :uses)
                                :system (getf plist :system)
                                :steps (getf plist :steps)))
                (getf form :examples))))))

(defun record-examples (package-name)
  "Parse, run and store the examples of PACKAGE-NAME; return how many were recorded.

Signals EXAMPLE-STEP-FAILED when a silent setup step errors.

- PACKAGE-NAME: the documented package, a string."
  (let* ((source (uiop:read-file-string (examples-source-pathname package-name)))
         (recorded (mapcar (lambda (example)
                             (let ((steps (run-example example)))
                               (dolist (step steps)
                                 (when (and (getf step :silent) (getf step :error))
                                   (error 'example-step-failed
                                          :form (getf step :form)
                                          :reason (getf step :error))))
                               (make-example :package (example-package example)
                                             :name (example-name example)
                                             :uses (example-uses example)
                                             :system (example-system example)
                                             :steps steps)))
                           (parse-examples-source source))))
    (write-examples package-name recorded)
    (length recorded)))

;;; Display

(defun output-lines (output)
  "Return the lines of OUTPUT prefixed for display, or NIL when empty.

- OUTPUT: text printed by a step, or NIL."
  (when output
    (mapcar (lambda (line) (format nil ";; prints: ~A" line))
            (uiop:split-string (string-trim '(#\Newline #\Space) output)
                               :separator '(#\Newline)))))

(defun step-result-lines (step)
  "Return the comment lines that display the recorded result of STEP.

- STEP: a recorded step plist."
  (cond ((getf step :silent) '())
        ((getf step :error)
         (list (format nil ";; signals ~A" (getf step :error))))
        (t (append (output-lines (getf step :output))
                   (if (getf step :values)
                       (mapcar (lambda (value) (format nil ";; => ~A" value))
                               (getf step :values))
                       (list *no-values-line*))))))
