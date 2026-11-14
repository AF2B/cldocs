;;;; introspect-test.lisp --- Tests for cldocs/introspect.

(defpackage #:cldocs/tests/introspect
  (:use #:cl #:fiveam))

(in-package #:cldocs/tests/introspect)

(def-suite* introspect-suite :in cldocs/tests/suite:all-tests)

(defun kinds-of (symbol)
  "Return the kinds of SYMBOL as computed by the introspector.

- SYMBOL: the symbol to inspect."
  (cldocs/introspect:symbol-kinds symbol))

(test functions-macros-and-operators-are-told-apart
  (is (equal '(:function) (kinds-of 'car)))
  (is (equal '(:macro) (kinds-of 'defun)))
  (is (equal '(:special-operator) (kinds-of 'if)))
  (is (equal '(:generic-function) (kinds-of 'print-object))))

(test variables-and-constants-are-told-apart
  (is (member :constant (kinds-of 'pi)))
  (is (member :variable (kinds-of '*print-base*))))

(test types-classes-and-conditions-are-told-apart
  (is (member :class (kinds-of 'integer)))
  (is (member :condition (kinds-of 'type-error)))
  (is (member :type (kinds-of 'mod))))

(test one-symbol-can-have-several-kinds
  (let ((kinds (kinds-of 'error)))
    (is (member :function kinds))
    (is (member :condition kinds))))

(test symbols-without-definitions-are-marked-as-plain-symbols
  (is (equal '(:symbol) (kinds-of 'declare)))
  (is (equal '(:symbol) (kinds-of '&optional))))

(test lambda-lists-render-without-package-prefixes
  (is (string= "(list)"
               (cldocs/introspect:render-lambda-list '(list))))
  (is (string= "()"
               (cldocs/introspect:render-lambda-list '())))
  (is (string= "(a &optional (b 1) &key (c nil) . rest)"
               (cldocs/introspect:render-lambda-list
                '(a &optional (b 1) &key (c nil) . rest))))
  (is (string= "(x &key (test 'eql))"
               (cldocs/introspect:render-lambda-list
                '(x &key (test 'eql)))))
  (is (string= "(&key (k :default))"
               (cldocs/introspect:render-lambda-list
                '(&key (k :default))))))

(test definitions-are-ordered-by-kind
  (let ((kinds (mapcar #'cldocs/definition:definition-kind
                       (cldocs/introspect:symbol-definitions 'error))))
    (is (equal kinds
               (sort (copy-list kinds)
                     #'<
                     :key #'cldocs/kinds:definition-kind-rank)))))

(test missing-package-signals-package-not-found
  (signals cldocs/conditions:package-not-found
    (cldocs/introspect:ingest-package "NO-SUCH-PACKAGE-EVER")))

(test ingestion-is-deterministic
  (flet ((snapshot ()
           (mapcar #'cldocs/definition:definition->plist
                   (cldocs/introspect:ingest-package :common-lisp))))
    (is (equal (snapshot) (snapshot)))))
