;;;; cldocs.asd --- ASDF definitions for CLDocs.

(defsystem "cldocs"
  :description "Community reference for Common Lisp symbols."
  :version "0.1.0"
  :author "André Borba"
  :license "MIT"
  :depends-on ("alexandria"
               "ironclad"
               "sb-cltl2"
               "sb-introspect")
  :pathname "src"
  :serial t
  :components ((:file "conditions")
               (:file "kinds")
               (:file "slug")
               (:file "definition")
               (:file "store")
               (:file "clhs")
               (:file "introspect")
               (:file "manifest")
               (:file "ingest")
               (:file "cldocs"))
  :in-order-to ((test-op (test-op "cldocs/tests"))))

(defsystem "cldocs/tests"
  :description "Test suite for CLDocs."
  :depends-on ("cldocs" "fiveam")
  :pathname "tests"
  :serial t
  :components ((:file "suite")
               (:file "conditions-test")
               (:file "kinds-test")
               (:file "slug-test")
               (:file "store-test")
               (:file "introspect-test")
               (:file "ingest-test")
               (:file "cldocs-test"))
  :perform (test-op (operation component)
             (declare (ignore operation component))
             (unless (uiop:symbol-call :fiveam '#:run!
                                       (uiop:find-symbol* '#:all-tests
                                                          '#:cldocs/tests/suite))
               (error "CLDocs test suite failed."))))
