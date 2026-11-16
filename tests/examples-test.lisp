;;;; examples-test.lisp --- Tests for examples, see-also and their rendering.

(defpackage #:cldocs/tests/examples
  (:use #:cl #:fiveam))

(in-package #:cldocs/tests/examples)

(def-suite* examples-suite :in cldocs/tests/suite:all-tests)

(defparameter *common-lisp* "COMMON-LISP"
  "Name of the standard package.")

(defparameter *minimum-documented-symbols* 100
  "Milestone M4: symbols that must have at least one verified example.")

(defparameter *sample-source*
  "ignored text before any header
== CAR
; a comment between forms
(car '(a b c))
-- silent
(defun f (x)
  \"has (parens) and ;semicolon\"
  x)
(f #\\()
== FLATTEN @ alexandria
(alexandria:flatten '(1 (2)))
== ALEXANDRIA:FLATTEN @ alexandria
"
  "Authoring text that exercises every feature of the format.")

(defun step-forms (example)
  "Return the source text of every step of EXAMPLE.

- EXAMPLE: an EXAMPLE record."
  (mapcar (lambda (step) (getf step :form))
          (cldocs/examples:example-steps example)))

(defun make-test-example (&rest steps)
  "Build a COMMON-LISP example holding STEPS.

- STEPS: step plists."
  (cldocs/examples:make-example :package *common-lisp* :name "DEMO" :steps steps))

(defun documented-steps (example)
  "Return the steps of EXAMPLE whose result is shown.

- EXAMPLE: an EXAMPLE record."
  (remove-if (lambda (step) (getf step :silent))
             (cldocs/examples:example-steps example)))

;;; Parsing

(test source-blocks-become-examples
  (let ((examples (cldocs/examples:parse-examples-source *sample-source*)))
    (is (= 3 (length examples)))
    (destructuring-bind (car-example flatten-example namespaced) examples
      (is (string= "CAR" (cldocs/examples:example-name car-example)))
      (is (string= "COMMON-LISP" (cldocs/examples:example-package car-example)))
      (is (equal '("FLATTEN" "alexandria")
                 (list (cldocs/examples:example-name flatten-example)
                       (cldocs/examples:example-system flatten-example))))
      (is (equal '("ALEXANDRIA" ("ALEXANDRIA"))
                 (list (cldocs/examples:example-package namespaced)
                       (cldocs/examples:example-uses namespaced)))))))

(test steps-keep-their-source-text-and-silent-marker
  (let* ((example (first (cldocs/examples:parse-examples-source *sample-source*)))
         (steps (cldocs/examples:example-steps example)))
    (is (= 3 (length steps)))
    (is (string= "(car '(a b c))" (getf (first steps) :form)))
    (is (getf (second steps) :silent))
    (is (search "has (parens) and ;semicolon" (getf (second steps) :form)))
    (is (not (getf (third steps) :silent)))
    (is (string= "(f #\\()" (getf (third steps) :form)))))

(test unbalanced-source-is-rejected
  (signals cldocs/conditions:malformed-example-source
    (cldocs/examples:parse-examples-source (format nil "== CAR~%(car '(a b~%"))))

(test empty-header-is-rejected
  (signals cldocs/conditions:malformed-example-source
    (cldocs/examples:parse-examples-source (format nil "== ~%(car nil)~%"))))

;;; Running

(test steps-record-values-output-and-errors
  (let ((steps (cldocs/examples:run-example
                (make-test-example (list :form "(+ 1 2)")
                                   (list :form "(values)")
                                   (list :form "(floor 7 2)")
                                   (list :form "(format t \"hi~%\")")
                                   (list :form "(car 5)")
                                   (list :form "(defparameter *x* 1)" :silent t)))))
    (is (equal '("3") (getf (nth 0 steps) :values)))
    (is (equal '() (getf (nth 1 steps) :values)))
    (is (equal '("3" "1") (getf (nth 2 steps) :values)))
    (is (string= (format nil "hi~%") (getf (nth 3 steps) :output)))
    (is (string= "TYPE-ERROR" (getf (nth 4 steps) :error)))
    (is (getf (nth 5 steps) :silent))
    (is (null (getf (nth 5 steps) :values)))))

(test steps-share-state-within-one-example
  (let ((steps (cldocs/examples:run-example
                (make-test-example (list :form "(defvar *shared* 41)" :silent t)
                                   (list :form "(1+ *shared*)")))))
    (is (equal '("42") (getf (second steps) :values)))))

(test examples-do-not-leak-into-each-other
  (cldocs/examples:run-example
   (make-test-example (list :form "(defun leaky-function () :leaked)" :silent t)))
  (let ((steps (cldocs/examples:run-example
                (make-test-example (list :form "(leaky-function)")))))
    (is (string= "UNDEFINED-FUNCTION" (getf (first steps) :error)))))

(test symbols-print-unqualified-inside-the-example-package
  (let ((steps (cldocs/examples:run-example
                (make-test-example (list :form "'(a b)")))))
    (is (equal '("(A B)") (getf (first steps) :values)))))

(test verification-reports-changed-results
  (let* ((example (make-test-example (list :form "(+ 1 2)" :values '("4"))))
         (problems (cldocs/examples:verify-example example)))
    (is (= 1 (length problems)))
    (is (string= "(+ 1 2)" (first (first problems))))))

(test result-lines-follow-the-display-conventions
  (flet ((lines (&rest step)
           (cldocs/examples:step-result-lines step)))
    (is (equal '(";; => 3") (lines :form "x" :values '("3"))))
    (is (equal '(";; => 1" ";; => 2") (lines :form "x" :values '("1" "2"))))
    (is (equal '(";; => (no values)") (lines :form "x" :values '())))
    (is (equal '(";; signals TYPE-ERROR") (lines :form "x" :error "TYPE-ERROR")))
    (is (equal '(";; prints: hi" ";; => NIL")
               (lines :form "x" :values '("NIL") :output (format nil "~%hi~%"))))
    (is (equal '() (lines :form "x" :silent t)))))

;;; Recording

(test recording-refuses-a-failing-setup-step
  (cldocs/tests/store:call-with-temporary-data-directory
   (lambda ()
     (let ((source (cldocs/examples:examples-source-pathname *common-lisp*)))
       (ensure-directories-exist source)
       (with-open-file (out source :direction :output :if-exists :supersede)
         (format out "== CAR~%-- silent~%(undefined-setup-function)~%(car nil)~%"))
       (signals cldocs/conditions:example-step-failed
         (cldocs/examples:record-examples *common-lisp*))))))

(defun regenerate-examples (package-name)
  "Re-record PACKAGE-NAME from its source inside a temporary data directory.

Returns the regenerated file text.

- PACKAGE-NAME: a documented package, a string."
  (let ((source (uiop:read-file-string
                 (cldocs/examples:examples-source-pathname package-name))))
    (cldocs/tests/store:call-with-temporary-data-directory
     (lambda ()
       (let ((source-copy (cldocs/examples:examples-source-pathname package-name)))
         (ensure-directories-exist source-copy)
         (with-open-file (out source-copy :direction :output :if-exists :supersede)
           (write-string source out))
         (cldocs/examples:record-examples package-name)
         (uiop:read-file-string (cldocs/examples:examples-pathname package-name)))))))

(defun differing-lines (left right)
  "Return up to three (index left right) lists where the line lists differ.

- LEFT: the checked-in text.
- RIGHT: the regenerated text."
  (let ((left-lines (uiop:split-string left :separator '(#\Newline)))
        (right-lines (uiop:split-string right :separator '(#\Newline))))
    (loop for index from 1
          for a in left-lines
          for b in right-lines
          unless (string= a b)
            collect (list index a b) into found
          until (>= (length found) 3)
          finally (return found))))

(test checked-in-examples-are-regenerated-byte-for-byte-from-the-source
  (dolist (package-name (cons *common-lisp*
                              (loop for entry in (cldocs/systems:configured-systems)
                                    append (getf entry :packages))))
    (let ((checked-in (uiop:read-file-string
                       (cldocs/examples:examples-pathname package-name)))
          (regenerated (regenerate-examples package-name)))
      (is (string= checked-in regenerated)
          "~A examples differ from their source, first differences: ~S"
          package-name (differing-lines checked-in regenerated)))))

;;; Checked-in data

(defun all-recorded-examples ()
  "Return every recorded EXAMPLE of every stored package."
  (loop for package-name in (cldocs/store:stored-package-names)
        append (cldocs/examples:read-examples package-name)))

(test every-recorded-example-still-produces-its-recorded-results
  (let ((failures (loop for example in (all-recorded-examples)
                        for problems = (cldocs/examples:verify-example example)
                        when problems
                          collect (cons (cldocs/examples:example-name example) problems))))
    (is (null failures) "examples out of date: ~S" failures)))

(test enough-symbols-have-examples
  (let ((names (remove-duplicates
                (mapcar #'cldocs/examples:example-name
                        (cldocs/examples:read-examples *common-lisp*))
                :test #'string=)))
    (is (>= (length names) *minimum-documented-symbols*))))

(test every-documented-symbol-has-between-one-and-four-examples
  (dolist (package-name (cldocs/store:stored-package-names))
    (let ((counts (make-hash-table :test #'equal)))
      (dolist (example (cldocs/examples:read-examples package-name))
        (incf (gethash (cldocs/examples:example-name example) counts 0)))
      (dolist (definition (cldocs/store:read-package-data package-name))
        (let ((count (gethash (cldocs/definition:definition-name definition) counts 0)))
          (is (<= 1 count 4)
              "~A:~A has ~D examples"
              package-name
              (cldocs/definition:definition-name definition)
              count))))))

(test every-example-documents-a-real-symbol-and-shows-a-result
  (dolist (package-name (cldocs/store:stored-package-names))
    (let ((stored (mapcar #'cldocs/definition:definition-name
                          (cldocs/store:read-package-data package-name))))
      (dolist (example (cldocs/examples:read-examples package-name))
        (is (member (cldocs/examples:example-name example) stored :test #'string=)
            "~A is not a stored symbol of ~A" (cldocs/examples:example-name example) package-name)
        (is (documented-steps example)
            "~A has no visible step" (cldocs/examples:example-name example))))))

(test no-recorded-step-signals-an-unexpected-error
  (let ((expected-error-symbols '("ERROR")))
    (dolist (example (all-recorded-examples))
      (unless (member (cldocs/examples:example-name example) expected-error-symbols
                      :test #'string=)
        (dolist (step (cldocs/examples:example-steps example))
          (is (null (getf step :error))
              "~A: ~A signals ~A" (cldocs/examples:example-name example)
              (getf step :form) (getf step :error)))))))

;;; See also

(defun related-names (name)
  "Return the names related to NAME in COMMON-LISP.

- NAME: a symbol name, a string."
  (let* ((entries (cldocs/model:group-definitions
                   (cldocs/store:read-package-data *common-lisp*)))
         (index (cldocs/related:build-related-index *common-lisp* entries)))
    (gethash name index)))

(test curated-groups-name-only-existing-symbols
  (let ((stored (mapcar #'cldocs/definition:definition-name
                        (cldocs/store:read-package-data *common-lisp*))))
    (dolist (group (cldocs/related:read-see-also-groups *common-lisp*))
      (dolist (name group)
        (is (member name stored :test #'string=) "~A is not a symbol" name)))))

(test related-symbols-exclude-self-and-respect-the-limit
  (let ((related (related-names "CAR")))
    (is (member "CDR" related :test #'string=))
    (is (not (member "CAR" related :test #'string=)))
    (is (<= (length related) cldocs/related:+max-related+))
    (is (= (length related) (length (remove-duplicates related :test #'string=))))))

(test shared-hyperspec-pages-relate-symbols-automatically
  (let ((related (related-names "CAAR")))
    (is (member "CAR" related :test #'string=))
    (is (member "CDR" related :test #'string=))))

;;; Pages

(test symbol-pages-show-examples-and-see-also
  (let ((html (cldocs/tests/site:read-site-file "sym/common-lisp/car/index.html")))
    (is (search "Example 1" html))
    (is (search "(car " html) "form missing")
    (is (search ";; =&gt; A" html) "result missing")
    (is (search "See also" html))
    (is (search "sym/common-lisp/cdr/" html))
    (is (not (search "No examples yet" html)))))

(test symbols-without-examples-say-so
  (let* ((definition (cldocs/definition:make-definition :package "DEMO"
                                                        :name "LONELY"
                                                        :kind :function))
         (entry (cldocs/model:make-symbol-entry :package "DEMO"
                                                :name "LONELY"
                                                :definitions (list definition))))
    (is (search "No examples yet" (cldocs/render:render-symbol entry)))))

(test every-published-symbol-page-shows-examples
  (let ((html (cldocs/tests/site:read-site-file "sym/common-lisp/abort/index.html")))
    (is (not (search "No examples yet" html)))
    (is (search "Example 1" html))))
