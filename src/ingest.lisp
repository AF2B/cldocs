;;;; ingest.lisp --- Ingestion entry points producing the versioned data set.

(defpackage #:cldocs/ingest
  (:use #:cl)
  (:import-from #:cldocs/introspect
                #:ingest-package)
  (:import-from #:cldocs/manifest
                #:write-manifest)
  (:import-from #:cldocs/store
                #:write-package-data)
  (:export #:ingest-common-lisp))

(in-package #:cldocs/ingest)

(defparameter *common-lisp-package* "COMMON-LISP"
  "Name of the standard package, the first data set ingested.")

(defun ingest-common-lisp ()
  "Ingest the COMMON-LISP package of this image, refresh the manifest and
return the number of definitions written."
  (let ((definitions (ingest-package *common-lisp-package*)))
    (write-package-data *common-lisp-package* definitions)
    (write-manifest)
    (length definitions)))
