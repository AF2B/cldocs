;;;; store-test.lisp --- Tests for cldocs/store and cldocs/definition.

(defpackage #:cldocs/tests/store
  (:use #:cl #:fiveam)
  (:export #:call-with-temporary-data-directory))

(in-package #:cldocs/tests/store)

(def-suite* store-suite :in cldocs/tests/suite:all-tests)

(defun call-with-temporary-data-directory (function)
  "Call FUNCTION with *DATA-DIRECTORY* bound to a fresh directory, then delete it.

- FUNCTION: a function of no arguments."
  (let ((directory (uiop:ensure-directory-pathname
                    (merge-pathnames (format nil "cldocs-test-~36R/" (random (expt 36 8)))
                                     (uiop:temporary-directory)))))
    (ensure-directories-exist directory)
    (unwind-protect (let ((cldocs/store:*data-directory* directory))
                      (funcall function))
      (uiop:delete-directory-tree directory :validate t :if-does-not-exist :ignore))))

(defun sample-definition (name kind)
  "Build a DEFINITION named NAME of KIND for tests.

- NAME: symbol name, a string.
- KIND: a definition kind keyword."
  (cldocs/definition:make-definition :package "DEMO"
                                     :name name
                                     :kind kind
                                     :lambda-list "(a &optional b)"
                                     :docstring (format nil "Line one.~%Line \"two\".")
                                     :origin "demo-system"))

(defun write-raw-data-file (package-name text)
  "Write TEXT verbatim as the data file of PACKAGE-NAME.

- PACKAGE-NAME: the package name as a string.
- TEXT: the exact file contents."
  (let ((pathname (cldocs/store:package-data-pathname package-name)))
    (ensure-directories-exist pathname)
    (with-open-file (out pathname :direction :output :if-exists :supersede)
      (write-string text out))))

(test definitions-roundtrip-through-disk
  (call-with-temporary-data-directory
   (lambda ()
     (let ((definitions (list (sample-definition "FOO" :function)
                              (sample-definition "FOO" :variable))))
       (cldocs/store:write-package-data "DEMO" definitions)
       (let ((loaded (cldocs/store:read-package-data "DEMO")))
         (is (equal (mapcar #'cldocs/definition:definition->plist definitions)
                    (mapcar #'cldocs/definition:definition->plist loaded))))))))

(test stored-package-names-are-sorted
  (call-with-temporary-data-directory
   (lambda ()
     (cldocs/store:write-package-data "ZETA" (list (sample-definition "A" :function)))
     (cldocs/store:write-package-data "ALPHA" (list (sample-definition "B" :function)))
     (is (equal '("ALPHA" "ZETA") (cldocs/store:stored-package-names))))))

(test missing-file-signals-malformed-data-file
  (call-with-temporary-data-directory
   (lambda ()
     (signals cldocs/conditions:malformed-data-file
       (cldocs/store:read-package-data "NOPE")))))

(test unreadable-file-signals-malformed-data-file
  (call-with-temporary-data-directory
   (lambda ()
     (write-raw-data-file "BROKEN" "(:package \"BROKEN\" :definitions (")
     (signals cldocs/conditions:malformed-data-file
       (cldocs/store:read-package-data "BROKEN")))))

(test reader-evaluation-is-disabled
  (call-with-temporary-data-directory
   (lambda ()
     (write-raw-data-file "EVIL" "#.(error \"pwned\")")
     (signals cldocs/conditions:malformed-data-file
       (cldocs/store:read-package-data "EVIL")))))

(test unknown-kind-is-rejected
  (signals type-error
    (cldocs/definition:plist->definition
     '(:name "X" :kind :bogus)
     "DEMO")))
