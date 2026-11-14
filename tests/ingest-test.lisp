;;;; ingest-test.lisp --- Tests of the checked-in COMMON-LISP data set.

(defpackage #:cldocs/tests/ingest
  (:use #:cl #:fiveam))

(in-package #:cldocs/tests/ingest)

(def-suite* ingest-suite :in cldocs/tests/suite:all-tests)

(defparameter *common-lisp* "COMMON-LISP"
  "Name of the standard package.")

(defun external-symbol-names ()
  "Return the sorted names of every external symbol of COMMON-LISP."
  (let ((names '()))
    (do-external-symbols (symbol :common-lisp)
      (push (symbol-name symbol) names))
    (sort names #'string<)))

(defun stored-names ()
  "Return the sorted distinct symbol names in the stored COMMON-LISP data."
  (sort (remove-duplicates
         (mapcar #'cldocs/definition:definition-name
                 (cldocs/store:read-package-data *common-lisp*))
         :test #'string=)
        #'string<))

(test stored-data-covers-every-external-symbol
  (is (equal (external-symbol-names) (stored-names))))

(test every-stored-definition-links-to-the-hyperspec
  (is (every #'cldocs/definition:definition-clhs-page
             (cldocs/store:read-package-data *common-lisp*))))

(test every-stored-definition-has-a-known-kind
  (is (every (lambda (definition)
               (cldocs/kinds:definition-kind-p
                (cldocs/definition:definition-kind definition)))
             (cldocs/store:read-package-data *common-lisp*))))

(test manifest-matches-the-data-on-disk
  (is (null (cldocs/manifest:manifest-stale-packages))))

(test manifest-records-the-toolchain
  (let ((manifest (cldocs/manifest:read-manifest)))
    (is (stringp (getf manifest :sbcl-version)))
    (is (stringp (getf manifest :quicklisp-dist)))))

(test regenerated-data-is-byte-identical-to-the-checked-in-data
  (let ((recorded (getf (cldocs/manifest:read-manifest) :sbcl-version)))
    (if (string/= recorded (lisp-implementation-version))
        (skip "Data recorded with SBCL ~A, running ~A."
              recorded (lisp-implementation-version))
        (let ((definitions (cldocs/introspect:ingest-package *common-lisp*))
              (checked-in (uiop:read-file-string
                           (cldocs/store:package-data-pathname *common-lisp*))))
          (cldocs/tests/store:call-with-temporary-data-directory
           (lambda ()
             (cldocs/store:write-package-data *common-lisp* definitions)
             (is (string= checked-in
                          (uiop:read-file-string
                           (cldocs/store:package-data-pathname *common-lisp*))))))))))
