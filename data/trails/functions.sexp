;;;; Reading path; edit and send a pull request.
(:slug "functions" :order 7
 :title (:en "Functions and closures" :pt-br "Funções e closures")
 :intro (:en "Functions are values. Define them, pass them around, capture variables and build new functions from old ones." :pt-br "Funções são valores. Defina, passe adiante, capture variáveis e construa funções novas a partir de antigas.")
 :sections (
  ((:en "Defining" :pt-br "Definindo") "DEFUN" "LAMBDA" "FLET" "LABELS" "FUNCTION" "FUNCALL" "APPLY")
  ((:en "Lambda lists" :pt-br "Listas de parâmetros") "&OPTIONAL" "&REST" "&KEY" "&AUX" "&ALLOW-OTHER-KEYS" "DESTRUCTURING-BIND")
  ((:en "Building functions" :pt-br "Construindo funções") "IDENTITY" "CONSTANTLY" "COMPLEMENT")
  ((:en "Higher order" :pt-br "Ordem superior") "MAPCAR" "MAPC" "MAPCAN" "MAPLIST" "REDUCE" "REMOVE-IF" "SORT" "FIND-IF" "EVERY" "SOME")
  ((:en "Introspection" :pt-br "Introspecção") "FBOUNDP" "FDEFINITION" "SYMBOL-FUNCTION" "FUNCTIONP" "COMPILE" "EVAL" "FUNCTION-LAMBDA-EXPRESSION")
 ))
