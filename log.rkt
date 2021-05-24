#lang racket

(provide verbose-mode verbose-log info-log)

(define verbose-mode (make-parameter #t))

(define (verbose-log . body)
  (when (verbose-mode) 
   (apply printf body)
   (printf "~n")))
   

(define (info-log . body)
 (apply printf body)
 (printf "~n"))
