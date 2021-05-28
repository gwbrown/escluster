#! /usr/bin/env racket
#lang racket

(require file/gunzip
         file/untar
         racket/file
         threading
         "elasticsearch.rkt"
         "log.rkt"
         "node.rkt")

(define number-of-nodes (make-parameter 3))
(define rebuild-pkg (make-parameter #f))
(define debug-mode (make-parameter #f))

(command-line
 #:program "escluster"
 #:once-each
 [("-v" "--verbose") "Run in verbose mode"
                     (verbose-mode #t)]
 [("-n" "--nodes") nodes
                   "Set the number of nodes in the cluster"
                   (number-of-nodes nodes)]
 [("-f" "--file") filename
  "Set the Elasticsearch package to use"
  (es-package filename)]
 [("-d" "--dir") dirname
  "Set the directory to use for Elasticsearch cluster files"
  (tmp-dir dirname)]
 [("-r" "--rebuild") 
  "Trigger a rebuild of the Elasticsearch package before starting the cluster."
  (rebuild-pkg #t)]
 [("-D" "--debug") 
  "Start the last node in 'debug' mode"
  (debug-mode #t)])

(verbose-log "Verbose logging is enabled.")
(info-log "Configured cluster size is [~v]." (number-of-nodes))
(verbose-log "Using Elasticsearch package at: [~v]." (es-package))
(verbose-log "Using directory: [~v]." (tmp-dir))
