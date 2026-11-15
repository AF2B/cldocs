;;;; contributions-test.lisp --- Tests for users, submissions, moderation and flags.

(defpackage #:cldocs/tests/contributions
  (:use #:cl #:fiveam)
  (:export #:call-with-memory-database
           #:make-test-user
           #:submit-valid
           #:+start-time+))

(in-package #:cldocs/tests/contributions)

(def-suite* contributions-suite :in cldocs/tests/suite:all-tests)

(defparameter +start-time+ 3900000000
  "A fixed universal time all tests count from.")

(defun call-with-memory-database (function)
  "Call FUNCTION with a private in-memory database, closing it afterwards.

- FUNCTION: a function of one argument, the DATABASE."
  (let ((database (cldocs/db:open-database ":memory:")))
    (unwind-protect (funcall function database)
      (cldocs/db:close-database database))))

(defun make-test-user (database login &key moderator)
  "Create a user with a github id derived from LOGIN and return its plist.

- DATABASE: a DATABASE.
- LOGIN: the GitHub login.
- MODERATOR: true to make the user a moderator."
  (cldocs/contributions:upsert-user database
                                    (+ 1000 (sxhash login))
                                    login
                                    moderator
                                    +start-time+))

(defun always-known (package symbol)
  "Accept every package and symbol, for tests that are not about symbols.

- PACKAGE: ignored.
- SYMBOL: ignored."
  (declare (ignore package symbol))
  t)

(defun submit-valid (database
                     user
                     &key
                       (body "(car '(a b))")
                       (kind :example)
                       (now +start-time+))
  "Submit a valid contribution as USER and return its id.

- DATABASE: a DATABASE.
- USER: the submitting user plist.
- BODY: the contribution text.
- KIND: :EXAMPLE or :NOTE.
- NOW: the submission time."
  (cldocs/contributions:submit-contribution
   database
   :user-id (cldocs/contributions:user-id user)
   :kind kind
   :package "COMMON-LISP"
   :symbol "CAR"
   :body body
   :terms-accepted t
   :known-symbol-p #'always-known
   :now now))

(defun rejection-reason (thunk)
  "Return the reason keyword of the INVALID-CONTRIBUTION THUNK signals, or NIL.

- THUNK: a function of no arguments."
  (handler-case (progn (funcall thunk) nil)
    (cldocs/conditions:invalid-contribution (condition)
      (cldocs/conditions:invalid-contribution-reason condition))))

(defun approved-ids (database)
  "Return the ids of the approved contributions of COMMON-LISP:CAR.

- DATABASE: a DATABASE."
  (mapcar (lambda (item) (getf item :id))
          (cldocs/contributions:approved-contributions database "COMMON-LISP" "CAR")))

;;; Users

(test users-are-created-once-and-roles-follow-the-moderator-list
  (call-with-memory-database
   (lambda (database)
     (let ((first (cldocs/contributions:upsert-user database 42 "ada" nil +start-time+))
           (second (cldocs/contributions:upsert-user database 42 "ada-renamed" t +start-time+)))
       (is (= (cldocs/contributions:user-id first) (cldocs/contributions:user-id second)))
       (is (string= "member" (cldocs/contributions:user-role first)))
       (is (cldocs/contributions:user-moderator-p second))
       (is (string= "ada-renamed" (cldocs/contributions:user-login second)))
       (let ((demoted (cldocs/contributions:upsert-user database 42 "ada" nil +start-time+)))
         (is (not (cldocs/contributions:user-moderator-p demoted))))))))

;;; Submitting

(test submissions-start-pending-and-stay-hidden
  (call-with-memory-database
   (lambda (database)
     (let* ((user (make-test-user database "ada"))
            (id (submit-valid database user)))
       (is (integerp id))
       (is (eq :pending (cldocs/contributions:contribution-status database id)))
       (is (null (approved-ids database)))
       (is (= 1 (length (cldocs/contributions:pending-contributions database))))))))

(test content-rules-reject-bad-submissions
  (call-with-memory-database
   (lambda (database)
     (let ((user (make-test-user database "ada")))
       (flet ((reason (&rest arguments)
                (rejection-reason (lambda () (apply #'submit-valid database user arguments)))))
         (is (eq :body-empty (reason :body "")))
         (is (eq :body-empty (reason :body (format nil "  ~%  "))))
         (is (eq :body-too-long
                 (reason :body (make-string (1+ cldocs/contributions:+max-body-length+)
                                            :initial-element #\a))))
         (is (null (reason :body (make-string cldocs/contributions:+max-body-length+
                                              :initial-element #\a))))
         (is (eq :body-control-characters (reason :body (format nil "a~Cb" (code-char 7)))))
         (is (eq :too-many-links
                 (reason :body "http://a.example http://b.example http://c.example")))
         (is (eq :body-not-text (reason :body 42)))
         (is (eq :unknown-kind (reason :kind :video))))))))

(test unknown-symbols-and-missing-terms-are-rejected
  (call-with-memory-database
   (lambda (database)
     (let ((user (make-test-user database "ada")))
       (flet ((attempt (&key (terms t) (known t))
                (rejection-reason
                 (lambda ()
                   (cldocs/contributions:submit-contribution
                    database
                    :user-id (cldocs/contributions:user-id user)
                    :kind :example
                    :package "COMMON-LISP"
                    :symbol "CAR"
                    :body "x"
                    :terms-accepted terms
                    :known-symbol-p (lambda (package symbol)
                                      (declare (ignore package symbol))
                                      known)
                    :now +start-time+)))))
         (is (eq :terms-not-accepted (attempt :terms nil)))
         (is (eq :unknown-symbol (attempt :known nil))))))))

(test sql-metacharacters-are-stored-verbatim
  (call-with-memory-database
   (lambda (database)
     (let* ((user (make-test-user database "ada"))
            (payload "'); DROP TABLE users; --")
            (id (submit-valid database user :body payload))
            (moderator (make-test-user database "mod" :moderator t)))
       (cldocs/contributions:moderate-contribution database moderator id :approve nil +start-time+)
       (is (string= payload
                    (getf (first (cldocs/contributions:approved-contributions
                                  database "COMMON-LISP" "CAR"))
                          :body)))
       (is (find-user-p database "ada"))))))

(defun find-user-p (database login)
  "Return true when a user with LOGIN still exists.

- DATABASE: a DATABASE.
- LOGIN: a GitHub login."
  (and (cldocs/db:db-row database "SELECT id FROM users WHERE login = ?" login) t))

(test submission-quota-is-enforced-per-user-and-expires
  (call-with-memory-database
   (lambda (database)
     (let ((user (make-test-user database "ada"))
           (other (make-test-user database "grace")))
       (dotimes (count cldocs/contributions:+max-submissions-per-window+)
         (submit-valid database user :now (+ +start-time+ count)))
       (let ((retry-after (handler-case (progn (submit-valid database user
                                                             :now (+ +start-time+ 20))
                                               nil)
                            (cldocs/conditions:rate-limited (condition)
                              (cldocs/conditions:rate-limited-retry-after condition)))))
         (is (integerp retry-after))
         (is (<= 1 retry-after cldocs/contributions:+rate-window-seconds+)))
       (is (integerp (submit-valid database other :now (+ +start-time+ 20))))
       (is (integerp (submit-valid database
                                   user
                                   :now (+ +start-time+
                                           cldocs/contributions:+rate-window-seconds+
                                           100))))))))

(test failed-submissions-do-not-leave-rows-behind
  (call-with-memory-database
   (lambda (database)
     (let ((user (make-test-user database "ada")))
       (rejection-reason (lambda () (submit-valid database user :body "")))
       (is (zerop (first (cldocs/db:db-row database "SELECT COUNT(*) FROM contributions"))))))))

(test transactions-roll-back-on-non-local-exit
  (call-with-memory-database
   (lambda (database)
     (let ((user (make-test-user database "ada")))
       (ignore-errors
        (cldocs/db:call-with-transaction
         database
         (lambda ()
           (submit-valid database user)
           (error "boom"))))
       (is (zerop (first (cldocs/db:db-row database "SELECT COUNT(*) FROM contributions"))))))))

;;; Moderation

(test moderators-approve-reject-and-hide-with-an-audit-trail
  (call-with-memory-database
   (lambda (database)
     (let* ((author (make-test-user database "ada"))
            (moderator (make-test-user database "mod" :moderator t))
            (id (submit-valid database author)))
       (is (eq :approved (cldocs/contributions:moderate-contribution
                          database moderator id :approve nil +start-time+)))
       (is (equal (list id) (approved-ids database)))
       (is (eq :hidden (cldocs/contributions:moderate-contribution
                        database moderator id :hide "spam" +start-time+)))
       (is (null (approved-ids database)))
       (is (eq :rejected (cldocs/contributions:moderate-contribution
                          database moderator id :reject "wrong" +start-time+)))
       (is (equal '("approve" "hide" "reject")
                  (mapcar #'first (cldocs/contributions:moderation-log database id))))
       (is (equal '("mod" "mod" "mod")
                  (mapcar #'third (cldocs/contributions:moderation-log database id))))))))

(test only-moderators-may-moderate
  (call-with-memory-database
   (lambda (database)
     (let* ((author (make-test-user database "ada"))
            (id (submit-valid database author)))
       (signals cldocs/conditions:not-allowed
         (cldocs/contributions:moderate-contribution
          database author id :approve nil +start-time+))
       (is (eq :pending (cldocs/contributions:contribution-status database id)))))))

(test moderation-rejects-bad-requests
  (call-with-memory-database
   (lambda (database)
     (let* ((author (make-test-user database "ada"))
            (moderator (make-test-user database "mod" :moderator t))
            (id (submit-valid database author)))
       (is (eq :unknown-action
               (rejection-reason
                (lambda ()
                  (cldocs/contributions:moderate-contribution
                   database moderator id :delete "x" +start-time+)))))
       (is (eq :reason-empty
               (rejection-reason
                (lambda ()
                  (cldocs/contributions:moderate-contribution
                   database moderator id :reject "" +start-time+)))))
       (cldocs/contributions:moderate-contribution database moderator id :approve nil +start-time+)
       (is (eq :already-in-status
               (rejection-reason
                (lambda ()
                  (cldocs/contributions:moderate-contribution
                   database moderator id :approve nil +start-time+)))))
       (signals cldocs/conditions:contribution-not-found
         (cldocs/contributions:moderate-contribution
          database moderator 99999 :approve nil +start-time+))))))

;;; Flags and withdrawal

(defun approved-contribution (database)
  "Create an approved contribution and return its id.

- DATABASE: a DATABASE."
  (let* ((author (make-test-user database "ada"))
         (moderator (make-test-user database "mod" :moderator t))
         (id (submit-valid database author)))
    (cldocs/contributions:moderate-contribution database moderator id :approve nil +start-time+)
    id))

(test enough-distinct-flags-send-a-contribution-back-to-review
  (call-with-memory-database
   (lambda (database)
     (let ((id (approved-contribution database))
           (flaggers (loop for login in '("f1" "f2" "f3")
                           collect (make-test-user database login))))
       (flet ((flag (user)
                (cldocs/contributions:flag-contribution database user id "bad" +start-time+)))
         (is (eq :approved (flag (first flaggers))))
         (is (eq :approved (flag (first flaggers))))
         (is (eq :approved (flag (second flaggers))))
         (is (eq :pending (flag (third flaggers))))
         (is (null (approved-ids database)))
         (is (equal '("approve" "requeue")
                    (mapcar #'first (cldocs/contributions:moderation-log database id)))))))))

(test only-approved-contributions-can-be-flagged
  (call-with-memory-database
   (lambda (database)
     (let* ((author (make-test-user database "ada"))
            (id (submit-valid database author)))
       (is (eq :not-flaggable
               (rejection-reason
                (lambda ()
                  (cldocs/contributions:flag-contribution
                   database author id "why" +start-time+)))))
       (is (eq :reason-empty
               (rejection-reason
                (lambda ()
                  (cldocs/contributions:flag-contribution
                   database author id " " +start-time+)))))))))

(test only-the-author-can-withdraw
  (call-with-memory-database
   (lambda (database)
     (let* ((author (make-test-user database "ada"))
            (stranger (make-test-user database "eve"))
            (id (approved-contribution database)))
       (declare (ignorable author))
       (signals cldocs/conditions:not-allowed
         (cldocs/contributions:withdraw-contribution database stranger id +start-time+))
       (let ((owner (cldocs/contributions:find-user
                     database
                     (first (cldocs/db:db-row
                             database
                             "SELECT author_id FROM contributions WHERE id = ?" id)))))
         (is (eq :withdrawn (cldocs/contributions:withdraw-contribution
                             database owner id +start-time+)))
         (is (null (approved-ids database))))))))
