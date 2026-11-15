;;;; Reading path; edit and send a pull request.
(:slug "types" :order 14
 :title (:en "Types and structures" :pt-br "Tipos e estruturas")
 :intro (:en "Common Lisp is dynamically typed with a rich type language. Test, declare and define your own types." :pt-br "O Common Lisp é dinamicamente tipado e tem uma linguagem de tipos rica. Teste, declare e defina seus próprios tipos.")
 :sections (
  ((:en "Testing" :pt-br "Testando") "TYPEP" "TYPE-OF" "SUBTYPEP" "COERCE" "ATOM" "CONSP" "LISTP" "NULL" "SYMBOLP" "STRINGP" "NUMBERP" "INTEGERP" "FUNCTIONP")
  ((:en "Declaring" :pt-br "Declarando") "DECLARE" "DECLAIM" "TYPE" "FTYPE" "INLINE" "OPTIMIZE" "SPECIAL" "IGNORE" "IGNORABLE" "THE")
  ((:en "Defining" :pt-br "Definindo") "DEFTYPE" "SATISFIES" "DEFSTRUCT" "CHECK-TYPE" "ETYPECASE")
  ((:en "Numeric and sequence types" :pt-br "Tipos numéricos e de sequência") "INTEGER" "FIXNUM" "BIGNUM" "RATIO" "SINGLE-FLOAT" "DOUBLE-FLOAT" "SEQUENCE" "SIMPLE-VECTOR" "BIT-VECTOR")
  ((:en "Equality" :pt-br "Igualdade") "EQ" "EQL" "EQUAL" "EQUALP")
 ))
