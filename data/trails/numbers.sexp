;;;; Reading path; edit and send a pull request.
(:slug "numbers" :order 5
 :title (:en "Numbers" :pt-br "Números")
 :intro (:en "Integers that never overflow, exact rationals, floats and the arithmetic, rounding and bit operations around them." :pt-br "Inteiros que nunca estouram, racionais exatos, floats e a aritmética, os arredondamentos e as operações de bits ao redor.")
 :sections (
  ((:en "Arithmetic" :pt-br "Aritmética") "+" "-" "*" "/" "1+" "1-" "MOD" "REM" "ABS" "MAX" "MIN" "EXPT" "SQRT" "ISQRT" "GCD" "LCM")
  ((:en "Comparing" :pt-br "Comparando") "=" "/=" "<" ">" "<=" ">=" "ZEROP" "PLUSP" "MINUSP" "EVENP" "ODDP")
  ((:en "Rounding" :pt-br "Arredondando") "FLOOR" "CEILING" "TRUNCATE" "ROUND" "FFLOOR" "FCEILING" "NUMERATOR" "DENOMINATOR" "RATIONAL" "FLOAT")
  ((:en "Transcendental" :pt-br "Transcendentes") "EXP" "LOG" "SIN" "COS" "TAN" "ASIN" "ACOS" "ATAN" "SINH" "PI")
  ((:en "Bits" :pt-br "Bits") "LOGAND" "LOGIOR" "LOGXOR" "LOGNOT" "ASH" "LDB" "DPB" "LOGCOUNT" "INTEGER-LENGTH" "LOGBITP")
  ((:en "Random and limits" :pt-br "Aleatório e limites") "RANDOM" "MAKE-RANDOM-STATE" "MOST-POSITIVE-FIXNUM" "SINGLE-FLOAT-EPSILON" "DECODE-FLOAT")
 ))
