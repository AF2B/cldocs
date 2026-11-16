;;;; Reading path; edit and send a pull request.
(:slug "libraries" :order 15
 :title (:en "Essential libraries" :pt-br "Bibliotecas essenciais")
 :intro (:en "The libraries almost every Common Lisp project reaches for, one theme at a time, all loadable with Quicklisp." :pt-br "As bibliotecas que quase todo projeto Common Lisp usa, um tema por vez, todas carregáveis com Quicklisp.")
 :sections (
  ((:en "Everyday utilities (Alexandria)" :pt-br "Utilitários do dia a dia (Alexandria)") "ALEXANDRIA:IOTA" "ALEXANDRIA:FLATTEN" "ALEXANDRIA:CURRY" "ALEXANDRIA:RCURRY" "ALEXANDRIA:COMPOSE" "ALEXANDRIA:ENSURE-LIST" "ALEXANDRIA:HASH-TABLE-KEYS" "ALEXANDRIA:HASH-TABLE-VALUES" "ALEXANDRIA:ALIST-HASH-TABLE" "ALEXANDRIA:WHEN-LET" "ALEXANDRIA:IF-LET" "ALEXANDRIA:WITH-GENSYMS" "ALEXANDRIA:CLAMP" "ALEXANDRIA:MEAN" "ALEXANDRIA:STARTS-WITH-SUBSEQ")
  ((:en "Strings (str)" :pt-br "Strings (str)") "STR:CONCAT" "STR:JOIN" "STR:SPLIT" "STR:WORDS" "STR:LINES" "STR:TRIM" "STR:SUBSTRING" "STR:REPLACE-ALL" "STR:CONTAINS?" "STR:STARTS-WITH?" "STR:CAMEL-CASE" "STR:SNAKE-CASE" "STR:PAD-LEFT" "STR:SHORTEN")
  ((:en "Splitting sequences" :pt-br "Dividindo sequências") "SPLIT-SEQUENCE:SPLIT-SEQUENCE" "SPLIT-SEQUENCE:SPLIT-SEQUENCE-IF" "SPLIT-SEQUENCE:SPLIT-SEQUENCE-IF-NOT")
  ((:en "Regular expressions (cl-ppcre)" :pt-br "Expressões regulares (cl-ppcre)") "CL-PPCRE:SCAN" "CL-PPCRE:SCAN-TO-STRINGS" "CL-PPCRE:ALL-MATCHES-AS-STRINGS" "CL-PPCRE:REGEX-REPLACE-ALL" "CL-PPCRE:SPLIT" "CL-PPCRE:REGISTER-GROUPS-BIND" "CL-PPCRE:CREATE-SCANNER")
  ((:en "Iteration (iterate)" :pt-br "Iteração (iterate)") "ITERATE:ITER" "ITERATE:FOR" "ITERATE:COLLECT" "ITERATE:SUM" "ITERATE:FINDING" "ITERATE:WHILE" "ITERATE:UNTIL" "ITERATE:WITH")
  ((:en "Anaphoric macros (anaphora)" :pt-br "Macros anafóricas (anaphora)") "ANAPHORA:AIF" "ANAPHORA:AWHEN" "ANAPHORA:AAND" "ANAPHORA:ACOND" "ANAPHORA:ALAMBDA" "ANAPHORA:IT")
  ((:en "Character encodings (babel)" :pt-br "Codificações de caracteres (babel)") "BABEL:STRING-TO-OCTETS" "BABEL:OCTETS-TO-STRING" "BABEL:STRING-SIZE-IN-OCTETS" "BABEL:LIST-CHARACTER-ENCODINGS")
  ((:en "Threads (bordeaux-threads)" :pt-br "Threads (bordeaux-threads)") "BORDEAUX-THREADS:MAKE-THREAD" "BORDEAUX-THREADS:JOIN-THREAD" "BORDEAUX-THREADS:MAKE-LOCK" "BORDEAUX-THREADS:WITH-LOCK-HELD" "BORDEAUX-THREADS:MAKE-SEMAPHORE" "BORDEAUX-THREADS:MAKE-CONDITION-VARIABLE")
  ((:en "Dates and times (local-time)" :pt-br "Datas e horas (local-time)") "LOCAL-TIME:NOW" "LOCAL-TIME:PARSE-TIMESTRING" "LOCAL-TIME:FORMAT-TIMESTRING" "LOCAL-TIME:TIMESTAMP+" "LOCAL-TIME:TIMESTAMP-DIFFERENCE" "LOCAL-TIME:ADJUST-TIMESTAMP" "LOCAL-TIME:ENCODE-TIMESTAMP" "LOCAL-TIME:DECODE-TIMESTAMP" "LOCAL-TIME:UNIX-TO-TIMESTAMP")
  ((:en "Testing (FiveAM)" :pt-br "Testes (FiveAM)") "FIVEAM:DEF-TEST" "FIVEAM:IS" "FIVEAM:IS-TRUE" "FIVEAM:SIGNALS" "FIVEAM:DEF-SUITE" "FIVEAM:RUN!" "FIVEAM:FOR-ALL" "FIVEAM:DEF-FIXTURE")
  ((:en "Weak references (trivial-garbage)" :pt-br "Referências fracas (trivial-garbage)") "TRIVIAL-GARBAGE:MAKE-WEAK-POINTER" "TRIVIAL-GARBAGE:WEAK-POINTER-VALUE" "TRIVIAL-GARBAGE:MAKE-WEAK-HASH-TABLE" "TRIVIAL-GARBAGE:FINALIZE" "TRIVIAL-GARBAGE:GC")
  ((:en "Named reader tables (named-readtables)" :pt-br "Tabelas de leitura nomeadas (named-readtables)") "EDITOR-HINTS.NAMED-READTABLES:DEFREADTABLE" "EDITOR-HINTS.NAMED-READTABLES:IN-READTABLE" "EDITOR-HINTS.NAMED-READTABLES:FIND-READTABLE" "EDITOR-HINTS.NAMED-READTABLES:MERGE-READTABLES-INTO")
 ))
