;;;; Reading path; edit and send a pull request.
(:slug "sequences" :order 3
 :title (:en "Sequences and arrays" :pt-br "Sequências e arrays")
 :intro (:en "Functions that work on lists, vectors and strings alike, plus the array machinery underneath." :pt-br "Funções que servem a listas, vetores e strings, mais a maquinaria de arrays por baixo.")
 :sections (
  ((:en "Basics" :pt-br "O básico") "LENGTH" "ELT" "SUBSEQ" "COPY-SEQ" "REVERSE" "NREVERSE" "CONCATENATE" "MAKE-SEQUENCE" "FILL" "REPLACE")
  ((:en "Searching and counting" :pt-br "Buscando e contando") "FIND" "FIND-IF" "POSITION" "POSITION-IF" "COUNT" "COUNT-IF" "SEARCH" "MISMATCH")
  ((:en "Filtering and changing" :pt-br "Filtrando e alterando") "REMOVE" "REMOVE-IF" "REMOVE-IF-NOT" "REMOVE-DUPLICATES" "DELETE" "SUBSTITUTE" "SUBSTITUTE-IF")
  ((:en "Sorting and merging" :pt-br "Ordenando e mesclando") "SORT" "STABLE-SORT" "MERGE")
  ((:en "Mapping and reducing" :pt-br "Mapeando e reduzindo") "MAP" "MAP-INTO" "REDUCE" "EVERY" "SOME" "NOTANY" "NOTEVERY")
  ((:en "Arrays" :pt-br "Arrays") "MAKE-ARRAY" "AREF" "VECTOR" "VECTOR-PUSH" "VECTOR-PUSH-EXTEND" "VECTOR-POP" "FILL-POINTER" "ADJUST-ARRAY" "ARRAY-DIMENSIONS" "ARRAY-TOTAL-SIZE" "BIT")
 ))
