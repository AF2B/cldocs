;;;; Reading path; edit and send a pull request.
(:slug "clos" :order 10
 :title (:en "CLOS: classes and generic functions" :pt-br "CLOS: classes e funções genéricas")
 :intro (:en "The Common Lisp Object System: classes, generic functions, methods and method combination, plus the protocol hooks that make it extensible." :pt-br "O Common Lisp Object System: classes, funções genéricas, métodos e combinação de métodos, mais os ganchos de protocolo que o tornam extensível.")
 :sections (
  ((:en "Classes and instances" :pt-br "Classes e instâncias") "DEFCLASS" "MAKE-INSTANCE" "SLOT-VALUE" "WITH-SLOTS" "WITH-ACCESSORS" "SLOT-BOUNDP" "SLOT-EXISTS-P" "CLASS-OF" "FIND-CLASS" "CLASS-NAME")
  ((:en "Generic functions" :pt-br "Funções genéricas") "DEFGENERIC" "DEFMETHOD" "CALL-NEXT-METHOD" "NEXT-METHOD-P" "NO-APPLICABLE-METHOD" "COMPUTE-APPLICABLE-METHODS")
  ((:en "Method combination" :pt-br "Combinação de métodos") "DEFINE-METHOD-COMBINATION" "CALL-METHOD" "METHOD-QUALIFIERS" "FIND-METHOD" "ADD-METHOD" "REMOVE-METHOD")
  ((:en "Object lifecycle" :pt-br "Ciclo de vida do objeto") "INITIALIZE-INSTANCE" "REINITIALIZE-INSTANCE" "SHARED-INITIALIZE" "CHANGE-CLASS" "UPDATE-INSTANCE-FOR-REDEFINED-CLASS" "PRINT-OBJECT" "DESCRIBE-OBJECT")
  ((:en "Structures" :pt-br "Estruturas") "DEFSTRUCT" "COPY-STRUCTURE")
 ))
