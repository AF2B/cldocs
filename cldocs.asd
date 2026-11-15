;;;; cldocs.asd --- ASDF definitions for CLDocs.

(defsystem "cldocs"
  :description "Community reference for Common Lisp symbols."
  :version "0.1.0"
  :author "André Borba"
  :license "MIT"
  :depends-on ("alexandria"
               "com.inuoe.jzon"
               "ironclad"
               "sb-cltl2"
               "sb-introspect"
               "spinneret")
  :pathname "src"
  :serial t
  :components ((:file "conditions")
               (:file "kinds")
               (:file "slug")
               (:file "definition")
               (:file "store")
               (:file "systems")
               (:file "clhs")
               (:file "introspect")
               (:file "manifest")
               (:file "ingest")
               (:file "examples")
               (:file "urls")
               (:file "model")
               (:file "related")
               (:file "render")
               (:file "search-index")
               (:file "site")
               (:file "cldocs"))
  :in-order-to ((test-op (test-op "cldocs/tests"))))

(defsystem "cldocs/server"
  :description "Community API, sign-in and web server for CLDocs."
  :depends-on ("alexandria"
               "bordeaux-threads"
               "cldocs"
               "com.inuoe.jzon"
               "dexador"
               "hunchentoot"
               "ironclad"
               "sqlite")
  :pathname "src/server"
  :serial t
  :components ((:file "config")
               (:file "db")
               (:file "contributions")
               (:file "auth")
               (:file "web")))

(defsystem "cldocs/tests"
  :description "Test suite for CLDocs."
  :depends-on ("cldocs" "cldocs/server" "dexador" "fiveam")
  :pathname "tests"
  :serial t
  :components ((:file "suite")
               (:file "conditions-test")
               (:file "kinds-test")
               (:file "slug-test")
               (:file "store-test")
               (:file "introspect-test")
               (:file "ingest-test")
               (:file "site-test")
               (:file "examples-test")
               (:file "systems-test")
               (:file "contributions-test")
               (:file "auth-test")
               (:file "server-test")
               (:file "cldocs-test"))
  :perform (test-op (operation component)
             (declare (ignore operation component))
             (unless (uiop:symbol-call :fiveam '#:run!
                                       (uiop:find-symbol* '#:all-tests
                                                          '#:cldocs/tests/suite))
               (error "CLDocs test suite failed."))))
