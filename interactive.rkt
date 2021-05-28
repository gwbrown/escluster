#lang racket/base

(require racket/class
         "cluster.rkt")

(provide
 number-of-nodes
 add-node
 get-node
 start-all
 stop-all
 start
 get-node-dir
 get-node-stdout
 get-node-stderr)

(define number-of-nodes (make-parameter 3))

(define cluster (new cluster% [size (number-of-nodes)]))

(define (add-node)
 (send cluster add-node))

(define (get-node node-id)
 (send cluster get-node node-id))
 
(define (start-all)
 (send cluster start-all))

(define (stop-all)
 (send cluster stop-all))

(define (start node-id #:debug (debug #f) #:reset (reset #f))
 (send cluster start node-id #:debug debug #:reset reset))

(define (get-node-dir node-id)
 (let ([node (get-node node-id)])
  (send node node-dir)))

(define (get-node-stdout node-id)
 (send (get-node node-id) get-stdout))

(define (get-node-stderr node-id)
 (send (get-node node-id) get-stderr))

