;;;; Reading path; edit and send a pull request.
(:slug "hash-tables" :order 8
 :title (:en "Hash tables and property lists" :pt-br "Tabelas hash e plists")
 :intro (:en "Key-value storage in Lisp: hash tables for speed, alists and plists for small, ordered data." :pt-br "Armazenamento chave-valor em Lisp: tabelas hash para velocidade, alists e plists para dados pequenos e ordenados.")
 :sections (
  ((:en "Hash tables" :pt-br "Tabelas hash") "MAKE-HASH-TABLE" "GETHASH" "REMHASH" "CLRHASH" "MAPHASH" "HASH-TABLE-COUNT" "HASH-TABLE-TEST" "WITH-HASH-TABLE-ITERATOR" "SXHASH")
  ((:en "Association lists" :pt-br "Alists") "ASSOC" "RASSOC" "ACONS" "PAIRLIS" "COPY-ALIST")
  ((:en "Property lists" :pt-br "Plists") "GETF" "REMF" "GET-PROPERTIES" "GET" "REMPROP" "SYMBOL-PLIST")
 ))
