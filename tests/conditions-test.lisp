;;;; conditions-test.lisp --- Tests for cldocs/conditions.

(defpackage #:cldocs/tests/conditions
  (:use #:cl #:fiveam))

(in-package #:cldocs/tests/conditions)

(def-suite* conditions-suite :in cldocs/tests/suite:all-tests)

(test load-failure-is-caught-as-base-type
  (let ((caught (handler-case
                    (error 'cldocs/conditions:system-load-failure
                           :system-name "broken-lib"
                           :reason "missing dependency")
                  (cldocs/conditions:cldocs-error (condition) condition))))
    (is (typep caught 'cldocs/conditions:ingestion-error))
    (is (string= "broken-lib"
                 (cldocs/conditions:ingestion-error-system-name caught)))))

(test load-failure-report-names-system-and-reason
  (let ((report (princ-to-string
                 (make-condition 'cldocs/conditions:system-load-failure
                                 :system-name "broken-lib"
                                 :reason "missing dependency"))))
    (is (search "broken-lib" report))
    (is (search "missing dependency" report))))

(test ingestion-error-requires-system-name
  (signals error
    (make-condition 'cldocs/conditions:ingestion-error)))
