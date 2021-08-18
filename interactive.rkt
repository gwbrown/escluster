#lang racket/base

(require racket/class
         "cluster.rkt"
         "node.rkt"
         "elasticsearch.rkt")

(provide
 rebuild-elasticsearch
 number-of-nodes
 add-node
 get-node
 start-all
 stop-all
 start
 stop
 get-node-dir
 get-node-stdout
 get-node-stderr)

(define number-of-nodes (make-parameter 3))

(define cluster (new cluster% [size (number-of-nodes)]))

(define (rebuild-elasticsearch)
 (build-elasticsearch)
 (extract-es-pkg (tmp-dir)))

(define (add-node)
 (send cluster add-node))

(define (get-node node-id)
 (send cluster get-node node-id))
 
(define (start-all #:debug-node (debug-node #f) #:reset (reset #f))
 (send cluster start-all #:debug-node debug-node #:reset reset))

(define (stop-all)
 (send cluster stop-all))

(define (start node-id #:debug (debug #f) #:reset (reset #f))
 (send cluster start-node node-id #:debug debug #:reset reset))

(define (stop node-id)
 (send cluster stop-node node-id))

(define (get-node-dir node-id)
 (let ([node (get-node node-id)])
  (send node node-dir)))

(define (get-node-stdout node-id)
 (send (get-node node-id) get-stdout))

(define (get-node-stderr node-id)
 (send (get-node node-id) get-stderr))

