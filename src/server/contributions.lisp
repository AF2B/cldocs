;;;; contributions.lisp --- Users, community contributions and their moderation.
;;;;
;;;; Contributions (examples and notes) are never executed and never shown
;;;; before a moderator approves them. Expected failures are signalled as
;;;; CLDOCS-ERROR conditions so the web layer can map them to HTTP statuses.

(defpackage #:cldocs/contributions
  (:use #:cl)
  (:import-from #:cldocs/conditions
                #:contribution-not-found
                #:invalid-contribution
                #:not-allowed
                #:rate-limited)
  (:import-from #:cldocs/render
                #:+terms-version+)
  (:import-from #:cldocs/db
                #:call-with-transaction
                #:db-execute
                #:db-insert
                #:db-query
                #:db-row)
  (:export #:+terms-version+
           #:+max-body-length+
           #:+max-submissions-per-window+
           #:+rate-window-seconds+
           #:+flags-to-requeue+
           #:upsert-user
           #:find-user
           #:user-id
           #:user-login
           #:user-role
           #:user-moderator-p
           #:submit-contribution
           #:approved-contributions
           #:pending-contributions
           #:recent-approved-contributions
           #:contribution-status
           #:moderate-contribution
           #:flag-contribution
           #:withdraw-contribution
           #:moderation-log))

(in-package #:cldocs/contributions)

(alexandria:define-constant +max-body-length+ 4000
  :test #'eql
  :documentation "Longest accepted contribution body, in characters.")

(alexandria:define-constant +max-reason-length+ 500
  :test #'eql
  :documentation "Longest accepted flag or moderation reason, in characters.")

(alexandria:define-constant +max-urls-per-body+ 2
  :test #'eql
  :documentation "Bodies with more links than this are rejected as spam.")

(alexandria:define-constant +max-submissions-per-window+ 10
  :test #'eql
  :documentation "Submissions one user may make within the rate window.")

(alexandria:define-constant +rate-window-seconds+ 3600
  :test #'eql
  :documentation "Length of the sliding submission window, one hour.")

(alexandria:define-constant +flags-to-requeue+ 3
  :test #'eql
  :documentation "Distinct flags that send an approved contribution back to review.")

(alexandria:define-constant +url-marker+ "://"
  :test #'string=
  :documentation "Substring counted as one link when screening for spam.")

(defparameter *kinds* '(:example :note)
  "Kinds of contribution that may be submitted.")

(defparameter *moderation-actions* '(:approve :reject :hide)
  "Actions a moderator may take.")

(defparameter *action-statuses*
  '((:approve . :approved) (:reject . :rejected) (:hide . :hidden))
  "Status each moderation action leads to.")

(defparameter *role-moderator* "moderator"
  "Role value that grants moderation rights.")

(defparameter *role-member* "member"
  "Role value of an ordinary signed-in user.")

(defparameter *list-limit* 200
  "Most contributions returned by one listing query.")

;;; Helpers

(defun status-text (status)
  "Return the stored text of the status keyword STATUS.

- STATUS: a keyword such as :PENDING."
  (string-downcase (symbol-name status)))

(defun invalid (reason &optional detail)
  "Signal INVALID-CONTRIBUTION for REASON.

- REASON: a keyword naming the broken rule.
- DETAIL: a human readable explanation, or NIL."
  (error 'invalid-contribution :reason reason :detail detail))

(defun count-occurrences (needle haystack)
  "Return how many times NEEDLE occurs in HAYSTACK without overlapping.

- NEEDLE: the non-empty substring to count.
- HAYSTACK: the string to search."
  (loop for start = (search needle haystack) then (search needle haystack :start2 (+ start (length needle)))
        while start
        count t))

(defun forbidden-control-char-p (char)
  "Return true for control characters other than newline and tab.

- CHAR: a character."
  (and (< (char-code char) 32)
       (not (member char '(#\Newline #\Tab)))))

(defun check-body (body)
  "Signal INVALID-CONTRIBUTION unless BODY is acceptable user text.

- BODY: the submitted text."
  (cond ((not (stringp body)) (invalid :body-not-text))
        ((string= (string-trim '(#\Space #\Tab #\Newline #\Return) body) "")
         (invalid :body-empty))
        ((> (length body) +max-body-length+)
         (invalid :body-too-long (format nil "at most ~D characters" +max-body-length+)))
        ((find-if #'forbidden-control-char-p (remove #\Return body))
         (invalid :body-control-characters))
        ((> (count-occurrences +url-marker+ body) +max-urls-per-body+)
         (invalid :too-many-links))))

(defun check-reason (reason)
  "Signal INVALID-CONTRIBUTION unless REASON is a short non-empty string.

- REASON: text explaining a flag or moderation decision."
  (cond ((not (stringp reason)) (invalid :reason-not-text))
        ((string= (string-trim " " reason) "") (invalid :reason-empty))
        ((> (length reason) +max-reason-length+) (invalid :reason-too-long))))

;;; Users

(defun user-id (user)
  "Return the id of USER.

- USER: a user plist."
  (getf user :id))

(defun user-login (user)
  "Return the GitHub login of USER.

- USER: a user plist."
  (getf user :login))

(defun user-role (user)
  "Return the role of USER, \"member\" or \"moderator\".

- USER: a user plist."
  (getf user :role))

(defun user-moderator-p (user)
  "Return true when USER may moderate.

- USER: a user plist, or NIL."
  (and user (string= (user-role user) *role-moderator*)))

(defun row->user (row)
  "Convert a users table ROW into a user plist.

- ROW: a list (id github-id login role), or NIL."
  (when row
    (destructuring-bind (id github-id login role) row
      (list :id id :github-id github-id :login login :role role))))

(defun find-user (database id)
  "Return the user plist with ID, or NIL.

- DATABASE: a DATABASE.
- ID: a user id."
  (row->user (db-row database
                     "SELECT id, github_id, login, role FROM users WHERE id = ?"
                     id)))

(defun upsert-user (database
                    github-id
                    login
                    moderator-p
                    now)
  "Create or refresh the user for GITHUB-ID and return the user plist.

The role is recomputed on every sign-in, so removing someone from the
moderator list takes effect at their next login.

- DATABASE: a DATABASE.
- GITHUB-ID: the numeric GitHub account id.
- LOGIN: the GitHub login, a string.
- MODERATOR-P: true when the login is on the moderator list.
- NOW: the current universal time."
  (let ((role (if moderator-p *role-moderator* *role-member*)))
    (call-with-transaction
     database
     (lambda ()
       (if (db-row database "SELECT id FROM users WHERE github_id = ?" github-id)
           (db-execute database
                       "UPDATE users SET login = ?, role = ? WHERE github_id = ?"
                       login role github-id)
           (db-execute database
                       "INSERT INTO users (github_id, login, role, created_at) VALUES (?, ?, ?, ?)"
                       github-id login role now))
       (row->user (db-row database
                          "SELECT id, github_id, login, role FROM users WHERE github_id = ?"
                          github-id))))))

;;; Submitting

(defun recent-submissions (database user-id now)
  "Return the creation times of USER-ID's submissions inside the rate window.

- DATABASE: a DATABASE.
- USER-ID: the submitting user.
- NOW: the current universal time."
  (mapcar #'first
          (db-query database
                    "SELECT created_at FROM contributions
                      WHERE author_id = ? AND created_at > ?
                      ORDER BY created_at"
                    user-id
                    (- now +rate-window-seconds+))))

(defun check-rate-limit (database user-id now)
  "Signal RATE-LIMITED when USER-ID has used up the submission quota.

- DATABASE: a DATABASE.
- USER-ID: the submitting user.
- NOW: the current universal time."
  (let ((recent (recent-submissions database user-id now)))
    (when (>= (length recent) +max-submissions-per-window+)
      (error 'rate-limited
             :retry-after (max 1 (- (+ (first recent) +rate-window-seconds+) now))))))

(defun submit-contribution (database
                            &key
                              user-id
                              kind
                              package
                              symbol
                              body
                              terms-accepted
                              known-symbol-p
                              now)
  "Store a new pending contribution and return its id.

Signals INVALID-CONTRIBUTION for content problems and RATE-LIMITED when the
user submitted too much recently.

- DATABASE: a DATABASE.
- USER-ID: the submitting user.
- KIND: :EXAMPLE or :NOTE.
- PACKAGE: package name of the documented symbol.
- SYMBOL: name of the documented symbol.
- BODY: the contribution text.
- TERMS-ACCEPTED: true when the submitter accepted the current terms.
- KNOWN-SYMBOL-P: function of package and symbol names that says whether the symbol is documented.
- NOW: the current universal time."
  (unless (member kind *kinds*)
    (invalid :unknown-kind))
  (unless terms-accepted
    (invalid :terms-not-accepted))
  (unless (and (stringp package) (stringp symbol)
               (funcall known-symbol-p package symbol))
    (invalid :unknown-symbol))
  (check-body body)
  (call-with-transaction
   database
   (lambda ()
     (check-rate-limit database user-id now)
     (db-insert database
                "INSERT INTO contributions
                   (kind, package, symbol, author_id, body, status,
                    terms_version, created_at, updated_at)
                 VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)"
                (status-text kind) package symbol user-id body
                +terms-version+ now now))))

;;; Reading

(defun row->contribution (row)
  "Convert a contributions row into a plist.

- ROW: a list (id kind package symbol body status login created-at)."
  (destructuring-bind (id kind package symbol body status login created-at) row
    (list :id id
          :kind kind
          :package package
          :symbol symbol
          :body body
          :status status
          :author login
          :created-at created-at)))

(defparameter *contribution-columns*
  "c.id, c.kind, c.package, c.symbol, c.body, c.status, u.login, c.created_at"
  "Columns selected for every contribution listing, in ROW->CONTRIBUTION order.")

(defun approved-contributions (database package symbol)
  "Return the approved contributions of one symbol, oldest first.

- DATABASE: a DATABASE.
- PACKAGE: package name of the documented symbol.
- SYMBOL: name of the documented symbol."
  (mapcar #'row->contribution
          (db-query database
                    (format nil "SELECT ~A FROM contributions c
                                   JOIN users u ON u.id = c.author_id
                                  WHERE c.package = ? AND c.symbol = ? AND c.status = 'approved'
                                  ORDER BY c.created_at, c.id
                                  LIMIT ~D"
                            *contribution-columns* *list-limit*)
                    package symbol)))

(defun pending-contributions (database)
  "Return the contributions waiting for review, oldest first.

- DATABASE: a DATABASE."
  (mapcar #'row->contribution
          (db-query database
                    (format nil "SELECT ~A FROM contributions c
                                   JOIN users u ON u.id = c.author_id
                                  WHERE c.status = 'pending'
                                  ORDER BY c.created_at, c.id
                                  LIMIT ~D"
                            *contribution-columns* *list-limit*))))

(defun recent-approved-contributions (database)
  "Return the most recently approved contributions, newest first, for moderators.

- DATABASE: a DATABASE."
  (mapcar #'row->contribution
          (db-query database
                    (format nil "SELECT ~A FROM contributions c
                                   JOIN users u ON u.id = c.author_id
                                  WHERE c.status = 'approved'
                                  ORDER BY c.updated_at DESC, c.id DESC
                                  LIMIT ~D"
                            *contribution-columns* *list-limit*))))

(defun contribution-status (database id)
  "Return the status keyword of contribution ID, or signal CONTRIBUTION-NOT-FOUND.

- DATABASE: a DATABASE.
- ID: a contribution id."
  (let ((row (db-row database "SELECT status FROM contributions WHERE id = ?" id)))
    (unless row
      (error 'contribution-not-found :id id))
    (intern (string-upcase (first row)) :keyword)))

;;; Moderating

(defun log-action (database
                   actor-id
                   id
                   action
                   reason
                   now)
  "Append an entry to the moderation log.

- DATABASE: a DATABASE.
- ACTOR-ID: the moderating user's id, or NIL for an automatic action.
- ID: the contribution concerned.
- ACTION: text naming what happened.
- REASON: the explanation, or NIL.
- NOW: the current universal time."
  (db-execute database
              "INSERT INTO moderation_log (actor_id, contribution_id, action, reason, created_at)
               VALUES (?, ?, ?, ?, ?)"
              actor-id id action reason now))

(defun set-status (database id status now)
  "Update the status of contribution ID.

- DATABASE: a DATABASE.
- ID: a contribution id.
- STATUS: the new status keyword.
- NOW: the current universal time."
  (db-execute database
              "UPDATE contributions SET status = ?, updated_at = ? WHERE id = ?"
              (status-text status) now id))

(defun moderate-contribution (database
                              moderator
                              id
                              action
                              reason
                              now)
  "Apply a moderation ACTION to contribution ID and log it.

Signals NOT-ALLOWED for non-moderators, CONTRIBUTION-NOT-FOUND for a bad id and
INVALID-CONTRIBUTION for an unknown action, a missing reason on rejection or a
contribution already in the target status. Returns the new status keyword.

- DATABASE: a DATABASE.
- MODERATOR: the acting user plist.
- ID: a contribution id.
- ACTION: :APPROVE, :REJECT or :HIDE.
- REASON: required for :REJECT and :HIDE, optional for :APPROVE.
- NOW: the current universal time."
  (unless (user-moderator-p moderator)
    (error 'not-allowed :action "moderate"))
  (unless (member action *moderation-actions*)
    (invalid :unknown-action))
  (unless (eq action :approve)
    (check-reason reason))
  (call-with-transaction
   database
   (lambda ()
     (let ((target (cdr (assoc action *action-statuses*))))
       (when (eq (contribution-status database id) target)
         (invalid :already-in-status))
       (set-status database id target now)
       (log-action database (user-id moderator) id (status-text action) reason now)
       target))))

(defun flag-contribution (database
                          user
                          id
                          reason
                          now)
  "Record that USER flagged the approved contribution ID.

Once +FLAGS-TO-REQUEUE+ distinct users flagged it, it returns to the review
queue. Flagging twice by the same user counts once. Returns the status
keyword after flagging.

- DATABASE: a DATABASE.
- USER: the flagging user plist.
- ID: a contribution id.
- REASON: why the user flagged it.
- NOW: the current universal time."
  (check-reason reason)
  (call-with-transaction
   database
   (lambda ()
     (unless (eq (contribution-status database id) :approved)
       (invalid :not-flaggable))
     (db-execute database
                 "INSERT OR IGNORE INTO flags (contribution_id, user_id, reason, created_at)
                  VALUES (?, ?, ?, ?)"
                 id (user-id user) reason now)
     (let ((flags (first (db-row database
                                 "SELECT COUNT(*) FROM flags WHERE contribution_id = ?"
                                 id))))
       (when (>= flags +flags-to-requeue+)
         (set-status database id :pending now)
         (log-action database nil id "requeue" "flag threshold reached" now))
       (contribution-status database id)))))

(defun withdraw-contribution (database user id now)
  "Let the author of contribution ID withdraw it from public view.

Signals NOT-ALLOWED for anyone else.

- DATABASE: a DATABASE.
- USER: the acting user plist.
- ID: a contribution id.
- NOW: the current universal time."
  (call-with-transaction
   database
   (lambda ()
     (contribution-status database id)
     (unless (eql (first (db-row database
                                 "SELECT author_id FROM contributions WHERE id = ?"
                                 id))
                  (user-id user))
       (error 'not-allowed :action "withdraw"))
     (set-status database id :withdrawn now)
     (log-action database (user-id user) id "withdraw" nil now)
     :withdrawn)))

(defun moderation-log (database id)
  "Return the log entries of contribution ID as (action reason actor created-at) lists.

- DATABASE: a DATABASE.
- ID: a contribution id."
  (db-query database
            "SELECT l.action, l.reason, u.login, l.created_at
               FROM moderation_log l LEFT JOIN users u ON u.id = l.actor_id
              WHERE l.contribution_id = ?
              ORDER BY l.id"
            id))
