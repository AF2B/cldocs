;;;; fetch-clhs-map.lisp --- Regenerate data/clhs-map.sexp.
;;;; Stores only the factual symbol-name -> page-name pairs published by LispWorks
;;;; in the HyperSpec's Data/Map_Sym.txt; no HyperSpec text or images are kept.
;;;; Usage: sbcl --non-interactive --load scripts/fetch-clhs-map.lisp

(defpackage #:cldocs/scripts/fetch-clhs-map
  (:use #:cl))

(in-package #:cldocs/scripts/fetch-clhs-map)

(defparameter *map-url*
  "https://www.lispworks.com/documentation/HyperSpec/Data/Map_Sym.txt"
  "Official symbol-to-page index of the HyperSpec.")

(defparameter *page-prefix* "../"
  "Prefix that the official index puts before every page path.")

(defparameter *output-pathname*
  (merge-pathnames "../data/clhs-map.sexp" (uiop:pathname-directory-pathname *load-truename*))
  "Where the generated map is written.")

(defun fetch-lines ()
  "Return the lines of the official index, without carriage returns."
  (mapcar (lambda (line) (string-trim '(#\Return #\Space) line))
          (uiop:split-string
           (uiop:run-program (list "curl" "-fsS" "--max-time" "60" *map-url*)
                             :output :string)
           :separator '(#\Newline))))

(defun strip-prefix (page)
  "Return PAGE without the leading ../ of the official index.

- PAGE: a page path as published in the index."
  (if (uiop:string-prefix-p *page-prefix* page)
      (subseq page (length *page-prefix*))
      page))

(defun main ()
  "Fetch the index and write the sorted symbol-name/page pairs."
  (let* ((lines (remove "" (fetch-lines) :test #'string=))
         (pairs (loop for (name page) on lines by #'cddr
                      collect (cons name (strip-prefix page)))))
    (ensure-directories-exist *output-pathname*)
    (with-standard-io-syntax
      (with-open-file (out *output-pathname*
                           :direction :output
                           :if-exists :supersede
                           :external-format :utf-8)
        (format out ";;;; symbol name -> HyperSpec page (facts only; see scripts/fetch-clhs-map.lisp)~%(")
        (dolist (pair (sort pairs #'string< :key #'car))
          (format out "~%  ~S" pair))
        (format out ")~%")))
    (format t "~&Wrote ~D pairs to ~A~%" (length pairs) *output-pathname*)))

(main)
