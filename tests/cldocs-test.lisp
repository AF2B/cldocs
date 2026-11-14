;;;; cldocs-test.lisp --- Tests for the top-level cldocs package.

(defpackage #:cldocs/tests/cldocs
  (:use #:cl #:fiveam))

(in-package #:cldocs/tests/cldocs)

(def-suite* cldocs-suite :in cldocs/tests/suite:all-tests)

(test version-matches-asdf-definition
  (is (string= (cldocs:version)
               (asdf:component-version (asdf:find-system "cldocs")))))
