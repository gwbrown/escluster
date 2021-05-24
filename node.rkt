#lang racket

(require "elasticsearch.rkt"
         "log.rkt")

(provide
 tmp-dir
 node%)

(define tmp-dir (make-parameter "/Users/gbrown/.escluster"))

(define node% 
 (class object%
  (init id)
  (define node-id id)
  (define subproc #f)
  (super-new)

  (define/public (node-dir)
   (build-path (tmp-dir) "nodes" node-id))

  (define/public (config-dir)
   (build-path (node-dir) "config"))

  (define/public (data-dir)
   (build-path (node-dir) "data"))

  (define/public (logs-dir)
   (build-path (node-dir) "logs"))

  (define (create-dirs (recreate-dirs #f))
   (when recreate-dirs
    (info-log "Removing files for node [~a]" node-id)
    (delete-directory/files (data-dir) #:must-exist? #f)
    (delete-directory/files (logs-dir) #:must-exist? #f)
    (delete-directory/files (config-dir) #:must-exist? #f))
   (verbose-log "Creating config, log, and data dirs for node [~v] at [~v]..." node-id (node-dir))
   (make-directory* (data-dir))
   (make-directory* (logs-dir))
   (copy-directory/files (build-path (extracted-es-dir (tmp-dir)) "config") (config-dir))
   (call-with-output-file (build-path (config-dir) "elasticsearch.yml")
    (lambda (out)
     (fprintf out "
cluster.name: ~a
node.name: ~a
path.data: ~a
path.logs: ~a
http.port: ~a
xpack.license.self_generated.type: ~a
"
      "escluster-cluster"
      (format "node-~a" node-id)
      (data-dir)
      (logs-dir)
      (+ 9200 node-id)
      "basic"))
    #:exists 'append))

  (define/public (reset)
   (create-dirs #t))

  (define/public (start-elasticsearch (recreate-dirs #f) (debug-mode #f))
   (create-dirs recreate-dirs)
   (let* ([path-conf (format "ES_PATH_CONF=~a" (config-dir))]
          [debug-str (if debug-mode 
                      "-agentlib:jdwp=transport=dt_socket,server=n,suspend=y,address=5005"
                      "")]
          [java-opts (format "ES_JAVA_OPTS=~a ~a" 
                             "-Des.shutdown_feature_flag_enabled=true" 
                             debug-str)])
    (let-values ([(sp _1 _2 _3) (subprocess #f #f #f 
                                 "/usr/bin/env" 
                                 path-conf
                                 java-opts 
                                 (build-path (extracted-es-dir tmp-dir) "bin" "elasticsearch"))])
     (set! subproc sp))))

  (define/public (stop-elasticsearch)
   (let loop ([current-status (subprocess-status)])
    (info-log (format "Attempting to stop node [~a] with pid [~a]" node-id (subprocess-pid subproc)))
    (when (equal? 'running current-status)
     (sleep 0.1)
     (loop (subprocess-status subproc)))
    (info-log (format "Stopped node [~a], result [~a]~n" 
               node-id 
               (subprocess-status subproc))))))) 

  
