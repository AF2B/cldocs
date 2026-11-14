;;;; conditions.lisp --- Condition types signalled by CLDocs.

(defpackage #:cldocs/conditions
  (:use #:cl)
  (:export #:cldocs-error
           #:ingestion-error
           #:ingestion-error-system-name
           #:system-load-failure
           #:system-load-failure-reason))

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
