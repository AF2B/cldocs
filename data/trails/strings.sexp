;;;; Reading path; edit and send a pull request.
(:slug "strings" :order 4
 :title (:en "Strings and characters" :pt-br "Strings e caracteres")
 :intro (:en "Strings are vectors of characters. Compare them, change their case, trim, search and convert to and from other data." :pt-br "Strings são vetores de caracteres. Compare, mude a caixa, apare, busque e converta de e para outros dados.")
 :sections (
  ((:en "Characters" :pt-br "Caracteres") "CHAR" "CHAR-CODE" "CODE-CHAR" "CHAR-UPCASE" "CHAR-DOWNCASE" "ALPHA-CHAR-P" "DIGIT-CHAR-P" "UPPER-CASE-P" "LOWER-CASE-P" "CHAR=" "CHAR-EQUAL")
  ((:en "Comparing" :pt-br "Comparando") "STRING=" "STRING-EQUAL" "STRING<" "STRING>" "STRING/=" "STRING-LESSP")
  ((:en "Changing" :pt-br "Alterando") "STRING-UPCASE" "STRING-DOWNCASE" "STRING-CAPITALIZE" "STRING-TRIM" "STRING-LEFT-TRIM" "STRING-RIGHT-TRIM")
  ((:en "Searching and slicing" :pt-br "Buscando e fatiando") "SEARCH" "SUBSEQ" "POSITION" "FIND" "CONCATENATE")
  ((:en "Converting" :pt-br "Convertendo") "STRING" "PARSE-INTEGER" "PRINC-TO-STRING" "PRIN1-TO-STRING" "WRITE-TO-STRING" "READ-FROM-STRING" "SYMBOL-NAME" "WITH-OUTPUT-TO-STRING" "WITH-INPUT-FROM-STRING" "MAKE-STRING")
 ))
