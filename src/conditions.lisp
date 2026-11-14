;;;; conditions.lisp --- Condition types signalled by CLDocs.

(defpackage #:cldocs/conditions
  (:use #:cl)
  (:export #:cldocs-error
           #:ingestion-error
           #:ingestion-error-system-name
           #:system-load-failure
           #:system-load-failure-reason
           #:system-without-license
           #:package-not-found
           #:package-not-found-name
           #:malformed-data-file
           #:malformed-data-file-pathname
           #:malformed-data-file-reason
           #:design-system-missing
           #:design-system-missing-pathname
           #:output-directory-not-empty
           #:output-directory-not-empty-pathname))

(in-package #:cldocs/conditions)

(define-condition cldocs-error (error)
  ()
  (:documentation "Base type of every expected failure signalled by CLDocs."))

(define-condition ingestion-error (cldocs-error)
  ((system-name :initarg :system-name
                :initform (error "SYSTEM-NAME is required.")
                :reader ingestion-error-system-name
                :documentation "Name of the ASDF system being ingested."))
  (:report (lambda (condition stream)
             (format stream "Ingestion failed for system ~A."
                     (ingestion-error-system-name condition))))
  (:documentation "Signalled when metadata extraction fails for one system."))

(define-condition system-load-failure (ingestion-error)
  ((reason :initarg :reason
           :initform nil
           :reader system-load-failure-reason
           :documentation "Printed representation of the underlying failure."))
  (:report (lambda (condition stream)
             (format stream "Could not load system ~A: ~A"
                     (ingestion-error-system-name condition)
                     (system-load-failure-reason condition))))
  (:documentation "Signalled when an ASDF system fails to load during ingestion."))

(define-condition system-without-license (ingestion-error)
  ()
  (:report (lambda (condition stream)
             (format stream "System ~A declares no license; refusing to ingest it."
                     (ingestion-error-system-name condition))))
  (:documentation "Signalled when a system has no redistributable license."))

(define-condition package-not-found (cldocs-error)
  ((name :initarg :name
         :initform (error "NAME is required.")
         :reader package-not-found-name
         :documentation "Designator of the package that does not exist."))
  (:report (lambda (condition stream)
             (format stream "Package ~A does not exist."
                     (package-not-found-name condition))))
  (:documentation "Signalled when a package to ingest is not present in the image."))

(define-condition malformed-data-file (cldocs-error)
  ((pathname :initarg :pathname
             :initform (error "PATHNAME is required.")
             :reader malformed-data-file-pathname
             :documentation "Data file that could not be used.")
   (reason :initarg :reason
           :initform "unknown"
           :reader malformed-data-file-reason
           :documentation "Why the file was rejected."))
  (:report (lambda (condition stream)
             (format stream "Data file ~A is unusable: ~A"
                     (malformed-data-file-pathname condition)
                     (malformed-data-file-reason condition))))
  (:documentation "Signalled when a versioned data file is missing or malformed."))

(define-condition design-system-missing (cldocs-error)
  ((pathname :initarg :pathname
             :initform (error "PATHNAME is required.")
             :reader design-system-missing-pathname
             :documentation "Directory where the Borba Design System was expected."))
  (:report (lambda (condition stream)
             (format stream "Borba Design System not found at ~A; refusing to improvise a style."
                     (design-system-missing-pathname condition))))
  (:documentation "Signalled when the design system assets cannot be located."))

(define-condition output-directory-not-empty (cldocs-error)
  ((pathname :initarg :pathname
             :initform (error "PATHNAME is required.")
             :reader output-directory-not-empty-pathname
             :documentation "Directory that was refused as build output."))
  (:report (lambda (condition stream)
             (format stream "Refusing to overwrite ~A: it is not a CLDocs site directory."
                     (output-directory-not-empty-pathname condition))))
  (:documentation "Signalled when the site output directory holds foreign files."))
