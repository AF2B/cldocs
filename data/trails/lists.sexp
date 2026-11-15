;;;; Reading path; edit and send a pull request.
(:slug "lists" :order 2
 :title (:en "Lists and conses" :pt-br "Listas e conses")
 :intro (:en "Lists are chains of cons cells. Learn to build them, take them apart, search them and treat them as sets and association tables." :pt-br "Listas são cadeias de células cons. Aprenda a construí-las, desmontá-las, buscar nelas e tratá-las como conjuntos e tabelas de associação.")
 :sections (
  ((:en "Cons cells" :pt-br "Células cons") "CONS" "CAR" "CDR" "CAAR" "CADR" "CDAR" "CDDR" "LIST" "LIST*" "MAKE-LIST" "COPY-LIST" "COPY-TREE" "LIST-LENGTH" "ENDP")
  ((:en "Picking elements" :pt-br "Escolhendo elementos") "FIRST" "SECOND" "THIRD" "FOURTH" "REST" "LAST" "BUTLAST" "NTH" "NTHCDR" "LDIFF" "TAILP")
  ((:en "Building" :pt-br "Construindo") "APPEND" "NCONC" "REVAPPEND" "NRECONC" "PUSH" "POP" "PUSHNEW" "ADJOIN")
  ((:en "Searching" :pt-br "Buscando") "MEMBER" "MEMBER-IF" "FIND" "FIND-IF" "POSITION" "COUNT")
  ((:en "Sets" :pt-br "Conjuntos") "UNION" "INTERSECTION" "SET-DIFFERENCE" "SET-EXCLUSIVE-OR" "SUBSETP")
  ((:en "Association lists and trees" :pt-br "Alists e árvores") "ASSOC" "ASSOC-IF" "RASSOC" "ACONS" "PAIRLIS" "COPY-ALIST" "SUBST" "SUBLIS" "TREE-EQUAL")
 ))
