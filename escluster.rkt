#! /usr/bin/env racket
#lang racket/base

(define rebuild-pkg (make-parameter #f))

(module+ main
 (require racket/cmdline
          racket/sandbox
          "elasticsearch.rkt"
          "interactive.rkt"
          "log.rkt"
          "node.rkt")
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
   (rebuild-pkg #t)])
  
 (define interactive 
  ;; This needs more permissions - currently filesystem accesses fail
  (make-evaluator 'racket/base #:requires '("interactive.rkt")))

 (printf "Welcome to escluster! This is a racket (https://racket-lang.org) shell. Type (help) for help or (exit) to exit.~n")

 (parameterize* ([current-eval interactive])
  (let loop ()
   ;; these exn handlers need to be cleaned up - should probably print and loop for exn:fail? or at least exn:fail:ontract?
   (with-handlers ([exn:fail:sandbox-terminated? 
                    (lambda (e) 
                     (if (equal? 'exited (exn:fail:sandbox-terminated-reason e))
                      (exit)
                      (displayln "welp")))]
                   [exn:fail:contract:variable?
                    (lambda (e)
                     (displayln (format "Undefined variable: ~a" (exn:fail:contract:variable-id e)))
                     (loop))]
                   [exn?
                    (lambda (e)
                     (displayln e))])
    (read-eval-print-loop)))))
