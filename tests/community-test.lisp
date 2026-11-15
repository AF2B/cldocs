;;;; community-test.lisp --- Tests for pull-request contributed examples.

(defpackage #:cldocs/tests/community
  (:use #:cl #:fiveam))

(in-package #:cldocs/tests/community)

(def-suite* community-suite :in cldocs/tests/suite:all-tests)

(defparameter *valid-file*
  (format nil ";;; author: octocat~%;;; license: CC0-1.0~%== MAPCAR~%(mapcar #'1+ '(1 2 3))~%")
  "A contribution that satisfies every rule.")

(defun call-with-community-files (files function)
  "Call FUNCTION with a temporary community directory holding FILES.

- FILES: a list of (relative-path . text) conses below community/examples/.
- FUNCTION: a function of no arguments run with the directory active."
  (cldocs/tests/site:call-with-temporary-directory
   (lambda (directory)
     (dolist (file files)
       (let ((pathname (merge-pathnames (concatenate 'string "examples/" (car file)) directory)))
         (ensure-directories-exist pathname)
         (with-open-file (out pathname :direction :output :if-exists :supersede)
           (write-string (cdr file) out))))
     (let ((cldocs/community:*community-directory* directory))
       (funcall function)))))

(defun problems-for (text &optional (path "common-lisp/mapcar.txt"))
  "Return the validation problems of a contribution holding TEXT stored at PATH.

- TEXT: the file contents.
- PATH: location below community/examples/."
  (call-with-community-files
   (list (cons path text))
   (lambda ()
     (cldocs/community:validate-community-file (first (cldocs/community:community-example-files))))))

(defun mentions (problems fragment)
  "Return true when some problem in PROBLEMS contains FRAGMENT.

- PROBLEMS: a list of strings.
- FRAGMENT: text to look for."
  (some (lambda (problem) (search fragment problem)) problems))

(test a-valid-contribution-has-no-problems
  (is (null (problems-for *valid-file*))))

(test author-and-license-lines-are-required
  (is (mentions (problems-for (format nil ";;; license: CC0-1.0~%== MAPCAR~%(list 1)~%")) "author"))
  (is (mentions (problems-for (format nil ";;; author: -bad-~%;;; license: CC0-1.0~%== MAPCAR~%(list 1)~%")) "author"))
  (is (mentions (problems-for (format nil ";;; author: octocat~%== MAPCAR~%(list 1)~%")) "CC0")))

(test unknown-symbols-and-misplaced-files-are-reported
  (is (mentions (problems-for (format nil ";;; author: octocat~%;;; license: CC0-1.0~%== NOT-A-SYMBOL~%(list 1)~%"))
                "not a documented symbol"))
  (is (mentions (problems-for *valid-file* "common-lisp/reduce.txt") "belongs in")))

(test dangerous-constructs-are-rejected-before-anything-runs
  (dolist (body '("(uiop:run-program \"ls\")"
                  "(sb-ext:exit)"
                  "(sb-posix:getpid)"))
    (is (mentions (problems-for (format nil ";;; author: octocat~%;;; license: CC0-1.0~%== MAPCAR~%~A~%" body))
                  "forbidden")
        "~A was not rejected" body))
  (dolist (body '("(delete-file \"/etc/passwd\")"
                  "(with-open-file (s \"/home/user/.ssh/id_rsa\") (read-line s))"))
    (is (mentions (problems-for (format nil ";;; author: octocat~%;;; license: CC0-1.0~%== MAPCAR~%~A~%" body))
                  "outside")
        "~A was not rejected" body)))

(test file-access-is-allowed-only-below-the-scratch-prefix
  (let ((safe (format nil ";;; author: octocat~%;;; license: CC0-1.0~%== OPEN~%(with-open-file (s \"/tmp/cldocs-demo.txt\" :direction :output :if-exists :supersede) (write-string \"x\" s))~%(delete-file \"/tmp/cldocs-demo.txt\")~%")))
    (is (null (problems-for safe "common-lisp/open.txt"))))
  (is (mentions (problems-for (format nil ";;; author: octocat~%;;; license: CC0-1.0~%== OPEN~%(probe-file \"/etc/hostname\")~%")
                              "common-lisp/open.txt")
                "outside")))

(test syntax-errors-and-empty-files-are-reported
  (is (mentions (problems-for (format nil ";;; author: octocat~%;;; license: CC0-1.0~%== MAPCAR~%(mapcar #'1+ '(1 2~%"))
                "cannot be parsed"))
  (is (mentions (problems-for (format nil ";;; author: octocat~%;;; license: CC0-1.0~%")) "no example block")))

(test files-are-limited-in-examples-and-size
  (let ((many (format nil ";;; author: octocat~%;;; license: CC0-1.0~%~{== MAPCAR~%(list ~D)~%~}"
                      (loop for index from 1 to 5 append (list index)))))
    (is (mentions (problems-for many) "more than")))
  (is (mentions (problems-for (format nil ";;; author: octocat~%;;; license: CC0-1.0~%== MAPCAR~%(list \"~A\")~%"
                                      (make-string 9000 :initial-element #\a)))
                "longer than")))

(test failing-and-endless-examples-are-reported
  (is (mentions (problems-for (format nil ";;; author: octocat~%;;; license: CC0-1.0~%== MAPCAR~%(car 5)~%"))
                "TYPE-ERROR"))
  (let ((cldocs/examples:*step-timeout-seconds* 1))
    (is (mentions (problems-for (format nil ";;; author: octocat~%;;; license: CC0-1.0~%== MAPCAR~%(loop)~%"))
                  "TIMEOUT"))))

(test loading-records-results-and-credits-the-author
  (call-with-community-files
   (list (cons "common-lisp/mapcar.txt" *valid-file*))
   (lambda ()
     (let ((examples (cldocs/community:load-community-examples)))
       (is (= 1 (length examples)))
       (let ((example (first examples)))
         (is (string= "octocat" (cldocs/examples:example-author example)))
         (is (string= "MAPCAR" (cldocs/examples:example-name example)))
         (is (equal '("(2 3 4)")
                    (getf (first (cldocs/examples:example-steps example)) :values))))))))

(test a-broken-file-stops-the-build-with-a-readable-report
  (call-with-community-files
   (list (cons "common-lisp/mapcar.txt" (format nil ";;; author: octocat~%== MAPCAR~%(list 1)~%")))
   (lambda ()
     (handler-case (progn (cldocs/community:load-community-examples) (fail "expected an error"))
       (cldocs/conditions:community-example-invalid (condition)
         (is (plusp (length (cldocs/conditions:community-example-invalid-problems condition))))
         (is (search "mapcar.txt" (princ-to-string condition))))))))

(test community-examples-are-labelled-with-their-author-on-the-page
  (call-with-community-files
   (list (cons "common-lisp/mapcar.txt" *valid-file*))
   (lambda ()
     (let* ((examples (cldocs/community:load-community-examples))
            (html (cldocs/render:render-examples examples)))
       (is (search "@octocat" html))
       (is (search "https://github.com/octocat" html))))))

(test the-checked-in-community-directory-is-valid
  (dolist (pathname (cldocs/community:community-example-files))
    (is (null (cldocs/community:validate-community-file pathname))
        "~A has problems" pathname)))

(test url-encoding-keeps-unreserved-characters-and-escapes-the-rest
  (is (string= "abc-1._~" (cldocs/urls:url-encode "abc-1._~")))
  (is (string= "a%20b%2Fc%3D" (cldocs/urls:url-encode "a b/c=")))
  (is (string= "%C3%A9" (cldocs/urls:url-encode "é"))))
