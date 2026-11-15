;;;; Reading path; edit and send a pull request.
(:slug "conditions" :order 9
 :title (:en "Conditions and restarts" :pt-br "Condições e restarts")
 :intro (:en "Common Lisp separates signalling a problem from deciding what to do about it. Learn handlers, restarts and the standard condition types." :pt-br "O Common Lisp separa sinalizar um problema de decidir o que fazer com ele. Aprenda handlers, restarts e os tipos padrão de condição.")
 :sections (
  ((:en "Signalling" :pt-br "Sinalizando") "ERROR" "WARN" "SIGNAL" "CERROR" "ASSERT" "CHECK-TYPE" "MAKE-CONDITION" "DEFINE-CONDITION")
  ((:en "Handling" :pt-br "Tratando") "HANDLER-CASE" "HANDLER-BIND" "IGNORE-ERRORS" "UNWIND-PROTECT")
  ((:en "Restarts" :pt-br "Restarts") "RESTART-CASE" "RESTART-BIND" "WITH-SIMPLE-RESTART" "INVOKE-RESTART" "FIND-RESTART" "COMPUTE-RESTARTS" "CONTINUE" "ABORT" "USE-VALUE" "STORE-VALUE" "MUFFLE-WARNING")
  ((:en "Condition types" :pt-br "Tipos de condição") "CONDITION" "SIMPLE-ERROR" "TYPE-ERROR" "DIVISION-BY-ZERO" "UNBOUND-VARIABLE" "UNDEFINED-FUNCTION" "PARSE-ERROR" "END-OF-FILE" "FILE-ERROR" "WARNING" "STYLE-WARNING")
  ((:en "Looking inside" :pt-br "Espiando por dentro") "SIMPLE-CONDITION-FORMAT-CONTROL" "TYPE-ERROR-DATUM" "TYPE-ERROR-EXPECTED-TYPE" "CELL-ERROR-NAME" "RESTART-NAME" "INVOKE-DEBUGGER")
 ))
