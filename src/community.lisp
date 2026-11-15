;;;; community.lisp --- Examples contributed through pull requests.
;;;;
;;;; A contribution is one text file in community/examples/<package>/<symbol>.txt
;;;; using the authoring format of the seeded examples, plus two header lines:
;;;;
;;;;   ;;; author: github-login
;;;;   ;;; license: CC0-1.0
;;;;
;;;; Files are validated statically (author, license, symbol, safety) and then
;;;; executed with a timeout; the site build refuses to publish a broken file.
;;;; Review by a maintainer remains the real gate: the static checks are
;;;; defence in depth, not a sandbox.

(defpackage #:cldocs/community
  (:use #:cl)
  (:import-from #:cldocs/conditions
                #:community-example-invalid
                #:malformed-example-source)
  (:import-from #:cldocs/examples
                #:example-author
                #:example-name
                #:example-package
                #:example-steps
                #:example-system
                #:example-uses
                #:make-example
                #:parse-examples-source
                #:run-example)
  (:import-from #:cldocs/slug
                #:slugify)
  (:import-from #:cldocs/store
                #:read-package-data
                #:stored-package-names)
  (:export #:*community-directory*
           #:+max-examples-per-file+
           #:community-directory
           #:community-example-files
           #:unsafe-reason
           #:validate-community-file
           #:load-community-examples))

(in-package #:cldocs/community)

(alexandria:define-constant +max-examples-per-file+ 4
  :test #'eql
  :documentation "Most examples one contributed file may hold.")

(alexandria:define-constant +max-file-characters+ 8000
  :test #'eql
  :documentation "Longest accepted contribution file, in characters.")

(defvar *community-directory* nil
  "When non-NIL, a directory pathname that overrides the checked-in community/.")

(defparameter *examples-subdirectory* "examples/"
  "Directory below community/ that holds contributed example files.")

(defparameter *file-type* "txt"
  "File type of contributed example files.")

(defparameter *license-line* ";;; license: CC0-1.0"
  "Exact line every contributed file must carry.")

(defparameter *author-marker* ";;; author:"
  "Prefix of the line naming the contributor.")

(defparameter *github-login-length* 39
  "Longest GitHub login.")

(defparameter *forbidden-tokens*
  '("run-program" "sb-ext:run" "sb-posix" "sb-alien" "alien-funcall" "load-shared-object"
    "delete-directory" "sb-ext:exit" "sb-ext:quit" "(exit" "(quit" "sb-sys:" "sb-unix"
    "sb-thread::" "uiop:run" "uiop:delete" "uiop:rename" "ironclad" "drakma" "dexador"
    "usocket" "sb-bsd-sockets" "getenv" "posix-getenv" "(require ")
  "Substrings that disqualify a contributed file outright (matched in lowercase).")

(defparameter *file-io-heads*
  '("(open " "with-open-file" "delete-file" "rename-file" "(load " "compile-file"
    "(directory " "ensure-directories-exist" "copy-file" "read-file-into" "write-string-into-file"
    "write-byte-vector-into-file" "with-output-to-file" "with-input-from-file" "probe-file")
  "Forms that touch the file system; their paths must stay under the scratch prefix.")

(defparameter *scratch-prefix* "/tmp/cldocs-"
  "Every absolute path an example touches must start with this prefix.")

(defun community-directory ()
  "Return the directory holding community contributions."
  (or *community-directory*
      (asdf:system-relative-pathname "cldocs" "community/")))

(defun community-example-files ()
  "Return every contributed example file, sorted by name."
  (sort (directory (merge-pathnames (format nil "~A**/*.~A" *examples-subdirectory* *file-type*)
                                    (community-directory)))
        #'string<
        :key #'namestring))

(defun github-login-p (text)
  "Return true when TEXT is a syntactically valid GitHub login.

- TEXT: a string, or NIL."
  (and (stringp text)
       (<= 1 (length text) *github-login-length*)
       (alphanumericp (char text 0))
       (every (lambda (char) (or (alphanumericp char) (char= char #\-))) text)
       (every (lambda (char) (< (char-code char) 128)) text)))

(defun path-literals (text)
  "Return the string literals of TEXT that look like absolute or home paths.

- TEXT: file contents."
  (let ((found '())
        (position 0))
    (loop
      (let ((start (position #\" text :start position)))
        (unless start (return))
        (let ((end (position #\" text :start (1+ start))))
          (unless end (return))
          (let ((literal (subseq text (1+ start) end)))
            (when (and (plusp (length literal))
                       (member (char literal 0) '(#\/ #\~)))
              (push literal found)))
          (setf position (1+ end)))))
    (nreverse found)))

(defun unsafe-reason (text)
  "Return a sentence explaining why TEXT must not be executed, or NIL when it passes.

- TEXT: the contents of a contributed file."
  (let ((lowercase (string-downcase text)))
    (or (let ((token (find-if (lambda (candidate) (search candidate lowercase))
                              *forbidden-tokens*)))
          (when token (format nil "uses forbidden construct ~S" token)))
        (when (some (lambda (head) (search head lowercase)) *file-io-heads*)
          (let ((stray (find-if-not (lambda (literal)
                                      (uiop:string-prefix-p *scratch-prefix* literal))
                                    (path-literals text))))
            (when stray
              (format nil "touches the file system outside ~A: ~S" *scratch-prefix* stray)))))))

(defun known-symbols ()
  "Return a table of (package . name) conses for every documented symbol."
  (let ((table (make-hash-table :test #'equal)))
    (dolist (package-name (stored-package-names) table)
      (dolist (definition (read-package-data package-name))
        (setf (gethash (cons package-name (cldocs/definition:definition-name definition))
                       table)
              t)))))

(defun expected-location (example)
  "Return the (package-slug . symbol-slug) pair a file holding EXAMPLE must live under.

- EXAMPLE: a parsed EXAMPLE."
  (cons (slugify (example-package example))
        (slugify (example-name example))))

(defun actual-location (pathname)
  "Return the (package-slug . symbol-slug) pair PATHNAME sits under.

- PATHNAME: a contributed file."
  (cons (car (last (pathname-directory pathname)))
        (pathname-name pathname)))

(defun static-problems (text pathname known)
  "Return the problems found by reading TEXT without running it.

- TEXT: the file contents.
- PATHNAME: where the file lives.
- KNOWN: the table returned by KNOWN-SYMBOLS."
  (let ((problems '())
        (author (cldocs/examples:source-author text)))
    (flet ((problem (control &rest arguments)
             (push (apply #'format nil control arguments) problems)))
      (unless (github-login-p author)
        (problem "needs a line \"~A your-github-login\"" *author-marker*))
      (unless (find *license-line* (uiop:split-string text :separator '(#\Newline))
                    :test #'string=)
        (problem "needs the line \"~A\" (CC0 dedication)" *license-line*))
      (when (> (length text) +max-file-characters+)
        (problem "is longer than ~D characters" +max-file-characters+))
      (let ((unsafe (unsafe-reason text)))
        (when unsafe (problem "~A" unsafe)))
      (handler-case
          (let ((examples (parse-examples-source text)))
            (when (null examples)
              (problem "contains no example block (start one with \"== SYMBOL\")"))
            (when (> (length examples) +max-examples-per-file+)
              (problem "has more than ~D examples" +max-examples-per-file+))
            (dolist (example examples)
              (unless (gethash (cons (example-package example) (example-name example)) known)
                (problem "documents ~A:~A, which is not a documented symbol"
                         (example-package example) (example-name example)))
              (unless (equal (expected-location example) (actual-location pathname))
                (problem "block ~A:~A belongs in community/examples/~A/~A.txt"
                         (example-package example)
                         (example-name example)
                         (car (expected-location example))
                         (cdr (expected-location example))))
              (unless (some (lambda (step) (not (getf step :silent)))
                            (example-steps example))
                (problem "block ~A has no visible step" (example-name example)))))
        (malformed-example-source (condition)
          (problem "cannot be parsed: ~A"
                   (cldocs/conditions:malformed-example-source-reason condition)))))
    (nreverse problems)))

(defun run-problems (pathname text)
  "Run the examples in TEXT and return a problem for every step that fails.

- PATHNAME: the contributed file, for messages.
- TEXT: the file contents."
  (declare (ignorable pathname))
  (loop for example in (parse-examples-source text)
        append (loop for step in (run-example example)
                     when (getf step :error)
                       collect (format nil "~A: ~A signals ~A"
                                       (example-name example)
                                       (substitute #\Space #\Newline (getf step :form))
                                       (getf step :error)))))

(defun validate-community-file (pathname &key (run t))
  "Return the list of problems with the contributed file PATHNAME; NIL means valid.

Static problems stop the check before anything is executed.

- PATHNAME: a file under community/examples/.
- RUN: when true, also execute the examples and report failing steps."
  (let* ((text (uiop:read-file-string pathname))
         (static (static-problems text pathname (known-symbols))))
    (cond (static static)
          (run (run-problems pathname text))
          (t '()))))

(defun load-community-examples ()
  "Return every contributed example with its results recorded, ready to display.

Signals COMMUNITY-EXAMPLE-INVALID, naming the file and every problem, as soon
as a file breaks a rule, so a bad contribution can never reach the site."
  (let ((known (known-symbols))
        (loaded '()))
    (dolist (pathname (community-example-files) (nreverse loaded))
      (let* ((text (uiop:read-file-string pathname))
             (problems (static-problems text pathname known)))
        (when problems
          (error 'community-example-invalid :pathname pathname :problems problems))
        (let ((failures (run-problems pathname text)))
          (when failures
            (error 'community-example-invalid :pathname pathname :problems failures)))
        (dolist (example (parse-examples-source text))
          (push (make-example :package (example-package example)
                              :name (example-name example)
                              :uses (example-uses example)
                              :system (example-system example)
                              :author (example-author example)
                              :steps (run-example example))
                loaded))))))
