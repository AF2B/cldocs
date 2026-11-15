;;;; Reading path; edit and send a pull request.
(:slug "streams" :order 13
 :title (:en "Input, output and streams" :pt-br "Entrada, saída e streams")
 :intro (:en "Streams unify the terminal, strings and files. Read and write characters, lines and Lisp data, and control how objects print." :pt-br "Streams unificam o terminal, strings e arquivos. Leia e escreva caracteres, linhas e dados Lisp, e controle como os objetos são impressos.")
 :sections (
  ((:en "Writing" :pt-br "Escrevendo") "WRITE-STRING" "WRITE-LINE" "WRITE-CHAR" "TERPRI" "FRESH-LINE" "FORMAT" "PRINT" "PRIN1" "PRINC" "PPRINT")
  ((:en "Reading" :pt-br "Lendo") "READ" "READ-LINE" "READ-CHAR" "PEEK-CHAR" "UNREAD-CHAR" "READ-FROM-STRING" "READ-SEQUENCE" "LISTEN")
  ((:en "Files" :pt-br "Arquivos") "OPEN" "CLOSE" "WITH-OPEN-FILE" "PROBE-FILE" "DELETE-FILE" "RENAME-FILE" "FILE-LENGTH" "FILE-POSITION" "DIRECTORY")
  ((:en "String streams" :pt-br "Streams de string") "MAKE-STRING-INPUT-STREAM" "MAKE-STRING-OUTPUT-STREAM" "GET-OUTPUT-STREAM-STRING" "WITH-OUTPUT-TO-STRING" "WITH-INPUT-FROM-STRING")
  ((:en "Pathnames" :pt-br "Pathnames") "PATHNAME" "MAKE-PATHNAME" "MERGE-PATHNAMES" "NAMESTRING" "PATHNAME-NAME" "PATHNAME-TYPE" "PATHNAME-DIRECTORY")
  ((:en "Controlling the printer" :pt-br "Controlando o printer") "*PRINT-BASE*" "*PRINT-CASE*" "*PRINT-CIRCLE*" "*PRINT-LENGTH*" "*PRINT-LEVEL*" "*PRINT-PRETTY*" "*PRINT-READABLY*" "*READ-EVAL*" "*READTABLE*")
 ))
