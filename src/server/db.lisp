;;;; db.lisp --- SQLite storage with one serialised connection.
;;;;
;;;; cl-sqlite connections are not thread safe, so every access goes through
;;;; a recursive lock. Statements always use bound parameters, never string
;;;; concatenation of user input.

(defpackage #:cldocs/db
  (:use #:cl)
  (:export #:database
           #:open-database
           #:close-database
           #:db-query
           #:db-row
           #:db-execute
           #:db-insert
           #:call-with-transaction
           #:+schema-version+))

(in-package #:cldocs/db)

(alexandria:define-constant +schema-version+ 1
  :test #'eql
  :documentation "Value of PRAGMA user_version once the schema is installed.")

(defparameter *busy-timeout-milliseconds* 5000
  "How long SQLite waits for a lock held by another process.")

(defparameter *schema-statements*
  '("CREATE TABLE IF NOT EXISTS users (
       id INTEGER PRIMARY KEY,
       github_id INTEGER NOT NULL UNIQUE,
       login TEXT NOT NULL,
       role TEXT NOT NULL DEFAULT 'member',
       created_at INTEGER NOT NULL)"
    "CREATE TABLE IF NOT EXISTS sessions (
       token_hash TEXT PRIMARY KEY,
       user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
       expires_at INTEGER NOT NULL)"
    "CREATE TABLE IF NOT EXISTS contributions (
       id INTEGER PRIMARY KEY,
       kind TEXT NOT NULL CHECK (kind IN ('example', 'note')),
       package TEXT NOT NULL,
       symbol TEXT NOT NULL,
       author_id INTEGER NOT NULL REFERENCES users(id),
       body TEXT NOT NULL,
       status TEXT NOT NULL
         CHECK (status IN ('pending', 'approved', 'rejected', 'hidden', 'withdrawn')),
       terms_version TEXT NOT NULL,
       created_at INTEGER NOT NULL,
       updated_at INTEGER NOT NULL)"
    "CREATE INDEX IF NOT EXISTS contributions_by_symbol
       ON contributions (package, symbol, status)"
    "CREATE INDEX IF NOT EXISTS contributions_by_author
       ON contributions (author_id, created_at)"
    "CREATE TABLE IF NOT EXISTS flags (
       contribution_id INTEGER NOT NULL REFERENCES contributions(id) ON DELETE CASCADE,
       user_id INTEGER NOT NULL REFERENCES users(id),
       reason TEXT NOT NULL,
       created_at INTEGER NOT NULL,
       PRIMARY KEY (contribution_id, user_id))"
    "CREATE TABLE IF NOT EXISTS moderation_log (
       id INTEGER PRIMARY KEY,
       actor_id INTEGER REFERENCES users(id),
       contribution_id INTEGER NOT NULL REFERENCES contributions(id),
       action TEXT NOT NULL,
       reason TEXT,
       created_at INTEGER NOT NULL)")
  "Statements that create the whole schema; each is idempotent.")

(defstruct (database (:constructor make-database (connection lock)) (:copier nil))
  "A SQLite connection together with the lock that serialises its use.

- CONNECTION: the cl-sqlite connection.
- LOCK: a recursive lock held for the duration of every operation."
  connection
  lock)

(defun install-schema (database)
  "Create every table and index and record the schema version.

- DATABASE: a DATABASE."
  (dolist (statement *schema-statements*)
    (db-execute database statement))
  (db-execute database (format nil "PRAGMA user_version = ~D" +schema-version+)))

(defun open-database (path)
  "Open the SQLite file PATH, install the schema and return a DATABASE.

- PATH: a file name, or \":memory:\" for a private in-memory database."
  (let ((database (make-database (sqlite:connect path)
                                 (bt:make-recursive-lock "cldocs-database"))))
    (db-execute database "PRAGMA foreign_keys = ON")
    (db-execute database (format nil "PRAGMA busy_timeout = ~D" *busy-timeout-milliseconds*))
    (install-schema database)
    database))

(defun close-database (database)
  "Close the connection of DATABASE.

- DATABASE: a DATABASE."
  (bt:with-recursive-lock-held ((database-lock database))
    (sqlite:disconnect (database-connection database))))

(defun db-query (database sql &rest parameters)
  "Run the SELECT statement SQL and return its rows as a list of lists.

- DATABASE: a DATABASE.
- SQL: a statement using ? placeholders.
- PARAMETERS: values bound to the placeholders, in order."
  (bt:with-recursive-lock-held ((database-lock database))
    (apply #'sqlite:execute-to-list (database-connection database) sql parameters)))

(defun db-row (database sql &rest parameters)
  "Run SQL and return only its first row, or NIL when there is none.

- DATABASE: a DATABASE.
- SQL: a statement using ? placeholders.
- PARAMETERS: values bound to the placeholders, in order."
  (first (apply #'db-query database sql parameters)))

(defun db-execute (database sql &rest parameters)
  "Run the statement SQL for its effect and return NIL.

- DATABASE: a DATABASE.
- SQL: a statement using ? placeholders.
- PARAMETERS: values bound to the placeholders, in order."
  (bt:with-recursive-lock-held ((database-lock database))
    (apply #'sqlite:execute-non-query (database-connection database) sql parameters))
  nil)

(defun db-insert (database sql &rest parameters)
  "Run the INSERT statement SQL and return the new row id.

- DATABASE: a DATABASE.
- SQL: an INSERT statement using ? placeholders.
- PARAMETERS: values bound to the placeholders, in order."
  (bt:with-recursive-lock-held ((database-lock database))
    (apply #'sqlite:execute-non-query (database-connection database) sql parameters)
    (sqlite:last-insert-rowid (database-connection database))))

(defun call-with-transaction (database function)
  "Call FUNCTION inside an immediate transaction; roll back on any non-local exit.

- DATABASE: a DATABASE.
- FUNCTION: a function of no arguments whose value is returned."
  (bt:with-recursive-lock-held ((database-lock database))
    (db-execute database "BEGIN IMMEDIATE")
    (let ((committed nil))
      (unwind-protect
           (multiple-value-prog1 (funcall function)
             (db-execute database "COMMIT")
             (setf committed t))
        (unless committed
          (db-execute database "ROLLBACK"))))))
