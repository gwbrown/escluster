#lang racket

(require "node.rkt")

(provide cluster%)

(define cluster%
 (class object%
  (init [size 0])
  (super-new)

  (define nodes 
   (list->vector 
    (map (lambda (node-id) (new node% [id node-id])) 
     (range size))))
  

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
 
(module+ test
 (require rackunit)

 (test-case "Cluster is initialized with the right number of nodes"
  (let ([cluster (new cluster% [size 5])])
   (check-equal? 5 (send cluster node-count))))

 (test-case "Cluster's default size is correct"
  (let ([cluster (new cluster%)])
   (check-equal? 0 (send cluster node-count))))
 
 (test-case "Adding nodes to a cluster works as expected"
  (let ([cluster (new cluster%)]
        [node? (lambda (node) (is-a? node node%))])
   (for ([node-id (range 3)])
    (send cluster add-node)
    (check-equal? (+ 1 node-id) (send cluster node-count))
    (check-pred node? (send cluster get-node node-id) (format "node ~a is not a node!" node-id))))))
  
