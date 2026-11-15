;;;; admin.lisp --- The moderators' page: review queue and published items.
;;;;
;;;; Plain HTML forms posting to /admin/moderate, so moderation works without
;;;; JavaScript. Every contribution text is escaped by Spinneret.

(defpackage #:cldocs/admin
  (:use #:cl)
  (:import-from #:cldocs/render
                #:layout-html)
  (:import-from #:cldocs/urls
                #:symbol-path)
  (:import-from #:spinneret
                #:with-html-string)
  (:export #:render-admin
           #:+moderate-path+))

(in-package #:cldocs/admin)

(alexandria:define-constant +moderate-path+ "/admin/moderate"
  :test #'string=
  :documentation "Where the moderation forms post to.")

(defparameter *admin-root* "/"
  "Relative prefix used by the admin page; it is served from one fixed path.")

(defparameter *reason-length* 500
  "Longest reason a moderator may type.")

(defun action-button (action label)
  "Return a submit button that sends ACTION.

- ACTION: the value posted as the action, such as \"approve\".
- LABEL: the text on the button."
  (with-html-string
    (:button :class "btn" :type "submit" :name "action" :value action label)))

(defun moderation-form (csrf id actions)
  "Return the form that moderates contribution ID.

- CSRF: the moderator's CSRF token.
- ID: the contribution id.
- ACTIONS: list of (action . label) conses to offer as buttons."
  (with-html-string
    (:form :class "contribute" :method "post" :action +moderate-path+
      (:input :type "hidden" :name "csrf" :value csrf)
      (:input :type "hidden" :name "id" :value (princ-to-string id))
      (:input :type "text"
              :name "reason"
              :maxlength (princ-to-string *reason-length*)
              :placeholder "Reason (required to reject or hide)"
              :aria-label "Reason")
      (:div :class "admin-actions"
        (loop for (action . label) in actions
              do (:raw (action-button action label)))))))

(defun contribution-card (contribution csrf actions)
  "Return one contribution with its moderation form.

- CONTRIBUTION: a contribution plist.
- CSRF: the moderator's CSRF token.
- ACTIONS: list of (action . label) conses to offer."
  (let ((package (getf contribution :package))
        (symbol (getf contribution :symbol)))
    (with-html-string
      (:article :class "contribution"
        (:p :class "label"
            (format nil "#~D · ~A · by ~A · " (getf contribution :id)
                    (getf contribution :kind) (getf contribution :author))
            (:a :href (concatenate 'string "/" (symbol-path package symbol))
                (format nil "~A:~A" package (string-downcase symbol))))
        (if (string= (getf contribution :kind) "example")
            (:pre (getf contribution :body))
            (:p :class "note" (getf contribution :body)))
        (:raw (moderation-form csrf (getf contribution :id) actions))))))

(defun render-admin (pending published csrf)
  "Return the moderation page.

- PENDING: contribution plists waiting for review.
- PUBLISHED: recently approved contribution plists, which can be hidden.
- CSRF: the moderator's CSRF token, embedded in every form."
  (let ((body (with-html-string
                (:p :class "label" "Moderation")
                (:h1 "Review queue")
                (:section :class "block"
                  (:h2 (format nil "Pending (~D)" (length pending)))
                  (if pending
                      (dolist (item pending)
                        (:raw (contribution-card item csrf
                                                 '(("approve" . "Approve")
                                                   ("reject" . "Reject")))))
                      (:p :class "empty" "Nothing is waiting for review.")))
                (:section :class "block"
                  (:h2 (format nil "Published (~D)" (length published)))
                  (if published
                      (dolist (item published)
                        (:raw (contribution-card item csrf '(("hide" . "Hide")))))
                      (:p :class "empty" "Nothing has been published yet."))))))
    (layout-html :title "Moderation"
                 :description "Review queue for moderators."
                 :root *admin-root*
                 :body body)))
