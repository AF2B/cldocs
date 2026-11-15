;;;; ingest.lisp --- Ingestion entry points producing the versioned data set.
;;;;
;;;; Libraries are ingested one per child SBCL process: loading a system runs
;;;; arbitrary code, so each gets its own image and a time limit.

(defpackage #:cldocs/ingest
  (:use #:cl)
  (:import-from #:cldocs/conditions
                #:system-load-failure)
  (:import-from #:cldocs/introspect
                #:ingest-package)
  (:import-from #:cldocs/manifest
                #:write-manifest)
  (:import-from #:cldocs/store
                #:write-package-data)
  (:import-from #:cldocs/systems
                #:configured-systems
                #:ensure-system-loaded
                #:system-metadata)
  (:export #:ingest-common-lisp
           #:ingest-system
           #:ingest-configured-systems
           #:skip-system
           #:+skipped-exit-code+))

(in-package #:cldocs/ingest)

(defparameter *common-lisp-package* "COMMON-LISP"
  "Name of the standard package, the first data set ingested.")

(defparameter *child-timeout-seconds* 900
  "Longest a child image may take to load and ingest one system.")

(alexandria:define-constant +skipped-exit-code+ 3
  :test #'eql
  :documentation "Exit status of a child that skipped its system on purpose.")

(defparameter *system-variable* "CLDOCS_SYSTEM"
  "Environment variable naming the system a child image must ingest.")

(defun ingest-common-lisp ()
  "Ingest the COMMON-LISP package of this image, refresh the manifest and
return the number of definitions written."
  (let ((definitions (ingest-package *common-lisp-package*)))
    (write-package-data *common-lisp-package* definitions)
    (write-manifest)
    (length definitions)))

(defun ingest-system (system-name packages)
  "Load SYSTEM-NAME, ingest PACKAGES and write their data files.

Establishes the restart SKIP-SYSTEM, which abandons the system and returns
NIL; it is available while the system is loaded and checked for a license.
Returns the number of definitions written.

- SYSTEM-NAME: the ASDF system name, a string.
- PACKAGES: names of the packages the system exports."
  (restart-case
      (progn
        (ensure-system-loaded system-name)
        (let ((metadata (system-metadata system-name))
              (written 0))
          (dolist (package-name packages written)
            (let ((definitions (ingest-package package-name :origin system-name)))
              (write-package-data package-name definitions :system metadata)
              (incf written (length definitions))))))
    (skip-system ()
      :report "Skip this system and keep going."
      nil)))

(defun child-command (project-root)
  "Return the command line that ingests one system in a child SBCL.

- PROJECT-ROOT: pathname of the CLDocs checkout."
  (list "timeout" (princ-to-string *child-timeout-seconds*)
        (namestring sb-ext:*runtime-pathname*)
        "--noinform"
        "--non-interactive"
        "--load" (namestring (merge-pathnames "scripts/ingest-system.lisp"
                                              project-root))))

(defun run-child (system-name project-root)
  "Ingest SYSTEM-NAME in a child image and return its exit status.

- SYSTEM-NAME: the ASDF system name, a string.
- PROJECT-ROOT: pathname of the CLDocs checkout."
  (nth-value 2 (uiop:run-program (child-command project-root)
                                 :environment (list (format nil "~A=~A"
                                                            *system-variable*
                                                            system-name))
                                 :output *standard-output*
                                 :error-output *error-output*
                                 :ignore-error-status t)))

(defun ingest-configured-systems (project-root)
  "Ingest every system of data/systems.sexp, each in its own child image.

Returns an alist of (system-name . status) with status :INGESTED, :SKIPPED
or :FAILED, then refreshes the manifest. A failure never stops the others.

- PROJECT-ROOT: pathname of the CLDocs checkout."
  (let ((results (loop for entry in (configured-systems)
                       for name = (getf entry :system)
                       for code = (run-child name project-root)
                       collect (cons name
                                     (cond ((zerop code) :ingested)
                                           ((= code +skipped-exit-code+) :skipped)
                                           (t :failed))))))
    (write-manifest)
    results))
