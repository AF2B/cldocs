;;;; systems-test.lisp --- Tests for library ingestion and its safeguards.

(defpackage #:cldocs/tests/systems
  (:use #:cl #:fiveam))

(in-package #:cldocs/tests/systems)

(def-suite* systems-suite :in cldocs/tests/suite:all-tests)

(defparameter *unlicensed-system* "cldocs-test-unlicensed"
  "Name of a system defined by the tests that declares no license.")

(defun recorded-with-this-toolchain-p ()
  "Return true when the stored data came from this SBCL and Quicklisp dist."
  (let ((manifest (cldocs/manifest:read-manifest)))
    (and (string= (getf manifest :sbcl-version) (lisp-implementation-version))
         (string= (getf manifest :quicklisp-dist)
                  (cldocs/manifest:quicklisp-dist-version)))))

(test configured-systems-are-listed-with-their-packages
  (let ((systems (cldocs/systems:configured-systems)))
    (is (>= (length systems) 3))
    (dolist (entry systems)
      (is (stringp (getf entry :system)))
      (is (consp (getf entry :packages))))))

(test every-configured-package-has-stored-data-and-a-license
  (dolist (entry (cldocs/systems:configured-systems))
    (dolist (package-name (getf entry :packages))
      (let ((system (cldocs/store:read-package-system package-name)))
        (is (string= (getf entry :system) (getf system :name)))
        (is (plusp (length (getf system :license))) "~A has no license" package-name)
        (is (plusp (length (getf system :version))) "~A has no version" package-name))
      (let ((definitions (cldocs/store:read-package-data package-name)))
        (is (plusp (length definitions)))
        (is (every (lambda (definition)
                     (equal (getf entry :system)
                            (cldocs/definition:definition-origin definition)))
                   definitions))
        (is (notany #'cldocs/definition:definition-clhs-page definitions)
            "library symbols must not link to the HyperSpec")))))

(test sbcl-data-has-no-system-metadata
  (is (null (cldocs/store:read-package-system "COMMON-LISP"))))

(test library-data-is-regenerated-identically
  (if (not (recorded-with-this-toolchain-p))
      (skip "Data was recorded with another SBCL or Quicklisp dist.")
      (dolist (entry (cldocs/systems:configured-systems))
        (cldocs/systems:ensure-system-loaded (getf entry :system))
        (dolist (package-name (getf entry :packages))
          (let ((fresh (mapcar #'cldocs/definition:definition->plist
                               (cldocs/introspect:ingest-package
                                package-name
                                :origin (getf entry :system))))
                (stored (mapcar #'cldocs/definition:definition->plist
                                (cldocs/store:read-package-data package-name))))
            (is (equal fresh stored) "~A drifted from the stored data" package-name))))))

(test system-without-license-is-refused
  (eval `(asdf:defsystem ,*unlicensed-system* :version "1.0"))
  (signals cldocs/conditions:system-without-license
    (cldocs/systems:system-metadata *unlicensed-system*)))

(test system-metadata-reports-version-and-license
  (let ((metadata (cldocs/systems:system-metadata "alexandria")))
    (is (string= "alexandria" (getf metadata :name)))
    (is (plusp (length (getf metadata :license))))))

(test skip-restart-abandons-a-system-that-fails-to-load
  (let ((result (handler-bind ((cldocs/conditions:cldocs-error
                                 (lambda (condition)
                                   (declare (ignore condition))
                                   (invoke-restart 'cldocs/ingest:skip-system))))
                  (cldocs/ingest:ingest-system "cldocs-no-such-system" '("NOPE")))))
    (is (null result))))

(test missing-system-signals-system-load-failure
  (signals cldocs/conditions:system-load-failure
    (cldocs/systems:ensure-system-loaded "cldocs-no-such-system")))

(test library-pages-credit-the-system-and-its-license
  (let ((html (cldocs/tests/site:read-site-file "sym/alexandria/iota/index.html")))
    (is (search "Documentation from alexandria" html))
    (is (search "Public Domain" html))
    (is (not (search "lispworks.com/documentation/HyperSpec" html)))))

(test home-page-lists-every-package-with-its-origin
  (let ((html (cldocs/tests/site:read-site-file "index.html")))
    (dolist (name '("COMMON-LISP" "ALEXANDRIA" "BORDEAUX-THREADS" "CL-PPCRE"))
      (is (search name html) "~A missing from the home page" name))
    (is (search "SBCL" html))))
