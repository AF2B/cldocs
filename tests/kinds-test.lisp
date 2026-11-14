;;;; kinds-test.lisp --- Tests for cldocs/kinds.

(defpackage #:cldocs/tests/kinds
  (:use #:cl #:fiveam))

(in-package #:cldocs/tests/kinds)

(def-suite* kinds-suite :in cldocs/tests/suite:all-tests)

(test every-declared-kind-is-recognised
  (dolist (kind cldocs/kinds:+definition-kinds+)
    (is (cldocs/kinds:definition-kind-p kind))))

(test unknown-objects-are-rejected
  (is (not (cldocs/kinds:definition-kind-p :nonsense)))
  (is (not (cldocs/kinds:definition-kind-p "function")))
  (is (not (cldocs/kinds:definition-kind-p nil))))

(test kinds-are-unique
  (is (= (length cldocs/kinds:+definition-kinds+)
         (length (remove-duplicates cldocs/kinds:+definition-kinds+)))))
