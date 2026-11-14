;;;; suite.lisp --- Root FiveAM suite for CLDocs.

(defpackage #:cldocs/tests/suite
  (:use #:cl)
  (:export #:all-tests))

(in-package #:cldocs/tests/suite)

(fiveam:def-suite all-tests
  :description "Every CLDocs test.")
