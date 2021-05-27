#lang racket

(require "node.rkt")

(provide cluster%)

(define cluster%
 (class object%
  (super-new)
  (define nodes #())
  

  (define/public (node-count)
   (vector-length nodes))

  (define/public (add-node)
   (set! nodes (vector-append nodes (vector (new node% [id (node-count)])))))

  (define/public (get-node node-id)
   (vector-ref nodes node-id))
  
  (define/public (start-node node-id #:debug (debug #f) #:reset (reset #f))
   (send (get-node node-id) start debug reset))

  (define/public (stop-node node-id)
   (send (get-node node-id) stop))
  
  (define/public (start-all #:reset (reset #f) #:debug-node (debug-node #f))
   (vector-map 
    (lambda (node) 
     (send node start reset (equal? debug-node (send node get-id)))) 
    nodes))
  
  (define/public (stop-all)
   (vector-map 
    (lambda (node) 
     (send node stop))
    nodes))))

 
