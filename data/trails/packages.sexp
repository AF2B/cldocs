;;;; Reading path; edit and send a pull request.
(:slug "packages" :order 12
 :title (:en "Packages and symbols" :pt-br "Pacotes e símbolos")
 :intro (:en "Packages are namespaces for symbols. See how names are interned, exported and imported." :pt-br "Pacotes são espaços de nomes para símbolos. Veja como nomes são internados, exportados e importados.")
 :sections (
  ((:en "Defining packages" :pt-br "Definindo pacotes") "DEFPACKAGE" "IN-PACKAGE" "MAKE-PACKAGE" "FIND-PACKAGE" "DELETE-PACKAGE" "RENAME-PACKAGE")
  ((:en "Moving symbols" :pt-br "Movendo símbolos") "INTERN" "FIND-SYMBOL" "UNINTERN" "EXPORT" "UNEXPORT" "IMPORT" "SHADOW" "SHADOWING-IMPORT" "USE-PACKAGE" "UNUSE-PACKAGE")
  ((:en "Inspecting" :pt-br "Inspecionando") "PACKAGE-NAME" "PACKAGE-USE-LIST" "PACKAGE-USED-BY-LIST" "LIST-ALL-PACKAGES" "DO-SYMBOLS" "DO-EXTERNAL-SYMBOLS" "APROPOS")
  ((:en "Symbols" :pt-br "Símbolos") "SYMBOL-NAME" "SYMBOL-PACKAGE" "SYMBOL-VALUE" "SYMBOL-FUNCTION" "MAKE-SYMBOL" "GENSYM" "KEYWORDP" "BOUNDP")
 ))
