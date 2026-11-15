;;;; Reading path; edit and send a pull request.
(:slug "control-flow" :order 6
 :title (:en "Control flow" :pt-br "Controle de fluxo")
 :intro (:en "From conditionals to non-local exits: how a Lisp program decides, repeats, escapes and returns several values." :pt-br "De condicionais a saídas não locais: como um programa Lisp decide, repete, escapa e devolve vários valores.")
 :sections (
  ((:en "Conditionals" :pt-br "Condicionais") "IF" "WHEN" "UNLESS" "COND" "CASE" "ECASE" "TYPECASE" "ETYPECASE")
  ((:en "Iteration" :pt-br "Iteração") "LOOP" "DO" "DO*" "DOTIMES" "DOLIST" "LOOP-FINISH")
  ((:en "Blocks and exits" :pt-br "Blocos e saídas") "BLOCK" "RETURN" "RETURN-FROM" "TAGBODY" "GO" "CATCH" "THROW" "UNWIND-PROTECT")
  ((:en "Several values" :pt-br "Vários valores") "VALUES" "VALUES-LIST" "MULTIPLE-VALUE-BIND" "MULTIPLE-VALUE-LIST" "MULTIPLE-VALUE-CALL" "NTH-VALUE" "MULTIPLE-VALUE-SETQ")
  ((:en "Sequencing" :pt-br "Sequenciando") "PROGN" "PROG1" "PROG2" "PROG" "PSETF" "ROTATEF" "SHIFTF")
 ))
