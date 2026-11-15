;;;; systems.lisp --- ASDF systems documented besides the SBCL image.
;;;;
;;;; References: ASDF manual, "The defsystem grammar" (:version, :license);
;;;; Quicklisp, https://www.quicklisp.org/beta/ (dists and system loading).

(defpackage #:cldocs/systems
  (:use #:cl)
  (:import-from #:cldocs/conditions
                #:system-load-failure
                #:system-without-license)
  (:import-from #:cldocs/store
                #:data-directory
                #:read-data-file)
  (:export #:configured-systems
           #:ensure-system-loaded
           #:system-metadata))

(in-package #:cldocs/systems)

(defparameter *systems-file-name* "systems.sexp"
  "File below the data root listing the systems to ingest.")

(defparameter *unversioned* "unversioned"
  "Version recorded for a system whose .asd declares none.")

(defun configured-systems ()
  "Return the list of (:system NAME :packages (PACKAGE ...)) plists to ingest."
  (read-data-file (merge-pathnames *systems-file-name* (data-directory))))

(defun ensure-system-loaded (system-name)
  "Load the ASDF system SYSTEM-NAME, through Quicklisp when it is present.

Signals SYSTEM-LOAD-FAILURE when loading fails.

- SYSTEM-NAME: the system name as a string, or NIL for nothing to load."
  (when system-name
    (handler-case
        (if (find-package '#:ql)
            (uiop:symbol-call '#:ql '#:quickload system-name :silent t)
            (asdf:load-system system-name))
      (error (condition)
        (error 'system-load-failure
               :system-name system-name
               :reason (princ-to-string condition))))))

(defun system-metadata (system-name)
  "Return the plist (:name :version :license) describing a loaded system.

Signals SYSTEM-WITHOUT-LICENSE when the system declares no license, because
its docstrings cannot be redistributed without one.

- SYSTEM-NAME: the system name as a string."
  (let* ((system (asdf:find-system system-name))
         (license (asdf:system-license system)))
    (when (or (null license) (string= (string-trim " " license) ""))
      (error 'system-without-license :system-name system-name))
    (list :name system-name
          :version (or (asdf:component-version system) *unversioned*)
          :license license)))
