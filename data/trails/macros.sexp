;;;; Reading path; edit and send a pull request.
(:slug "macros" :order 11
 :title (:en "Macros and metaprogramming" :pt-br "Macros e metaprogramação")
 :intro (:en "Code is data. Write programs that write programs, expand them to see what they do, and stay hygienic." :pt-br "Código é dado. Escreva programas que escrevem programas, expanda-os para ver o que fazem e mantenha a higiene.")
 :sections (
  ((:en "Defining macros" :pt-br "Definindo macros") "DEFMACRO" "DEFINE-SYMBOL-MACRO" "MACROLET" "SYMBOL-MACROLET" "DEFINE-COMPILER-MACRO" "DEFINE-MODIFY-MACRO")
  ((:en "Expanding" :pt-br "Expandindo") "MACROEXPAND" "MACROEXPAND-1" "MACRO-FUNCTION" "COMPILER-MACRO-FUNCTION")
  ((:en "Writing macros" :pt-br "Escrevendo macros") "GENSYM" "DESTRUCTURING-BIND" "&BODY" "&ENVIRONMENT" "&WHOLE" "EVAL-WHEN")
  ((:en "Places" :pt-br "Places") "SETF" "DEFSETF" "DEFINE-SETF-EXPANDER" "GET-SETF-EXPANSION" "PSETF" "SHIFTF" "ROTATEF")
  ((:en "Evaluation" :pt-br "Avaliação") "EVAL" "COMPILE" "LOAD-TIME-VALUE" "THE" "LOCALLY")
 ))
