#lang info
(define collection "escluster")
(define deps '("base" "threading"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/escluster.scrbl" ())))
(define pkg-desc "Creates and manages a local Elasticsearch cluster for development purposes.")
(define version "0.1")
(define pkg-authors '(gwbrown))
