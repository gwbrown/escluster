#! /usr/bin/env racket
#lang racket

(require file/gunzip
         file/untar
         racket/file
         threading)

(define verbose-mode (make-parameter #t))
(define number-of-nodes (make-parameter 3))
(define es-package (make-parameter "/Users/gbrown/workspace/elasticsearch/distribution/archives/darwin-tar/build/distributions/elasticsearch-8.0.0-SNAPSHOT-darwin-x86_64.tar.gz"))
(define tmp-dir (make-parameter "/Users/gbrown/.escluster"))
(define rebuild-pkg (make-parameter #f))
(define es-source-dir (make-parameter "/Users/gbrown/workspace/elasticsearch"))

(define (verbose-log . body)
  (when (verbose-mode) 
   (apply printf body)
   (printf "~n")))
   

(define (info-log . body)
 (apply printf body)
 (printf "~n"))

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

(verbose-log "Verbose logging is enabled.")
(info-log "Configured cluster size is [~v]." (number-of-nodes))
(verbose-log "Using Elasticsearch package at: [~v]." (es-package))
(verbose-log "Using directory: [~v]." (tmp-dir))

(define elasticsearch-dir (~> (tmp-dir)
                           (string->path)
                           (build-path _ "elasticsearch")))
                           
(if (directory-exists? (tmp-dir))
 (verbose-log "Directory [~v] exists" (tmp-dir))
 (begin
  (info-log "Directory [~v] does not exist, creating it..." (tmp-dir))
  (make-directory* (tmp-dir))))

(if (directory-exists? elasticsearch-dir)
 (begin
  (info-log "Directory [~v] exists, removing and re-creating..." elasticsearch-dir)
  (delete-directory/files elasticsearch-dir))
 (begin
  (info-log "ES directory [~v] does not exist yet, creating..." elasticsearch-dir)))
(make-directory elasticsearch-dir)

(when (rebuild-pkg)
 (let ([old-dir (current-directory)])
  (info-log "Rebuilding Elasticsearch as requested...")
  (current-directory (es-source-dir))
  (system "./gradlew :distribution:archives:darwin-tar:assemble")
  (info-log "Finished rebulding Elasticsearch.")
  (current-directory old-dir)))
 

(info-log "Extracting Elasticsearch package...")

(let [(es-tar (build-path elasticsearch-dir "espkg.tar"))]
 (call-with-output-file es-tar
  (lambda (out)
   (call-with-input-file (es-package)
    (lambda (in)
     (gunzip-through-ports in out))))
  #:exists 'replace)
 (verbose-log "Elasticsearch package extracted to [~v], untarring..." es-tar)
 (untar es-tar 
  #:dest elasticsearch-dir
  #:strip-count 1
  #:permissive? #t)
 (info-log "Elasticsearch extracted to [~v]." elasticsearch-dir)
 (delete-file es-tar)
 (verbose-log "Deleted temporary tar file at [~v]" es-tar))

(define config-dirs (mutable-set))

(let [(nodes-dir (build-path (tmp-dir) "nodes"))]
 (info-log "Creating data dir(s) at [~v]" nodes-dir)
 (define (create-dirs-for node)
  (let* [(node-dir (build-path nodes-dir (~v node)))
         (config-dir (build-path node-dir "config"))
         (data-dir (build-path node-dir "data"))
         (logs-dir (build-path node-dir "logs"))]
   (verbose-log "Creating config, log, and data dirs for node [~v] at [~v]..." node node-dir)
   (delete-directory/files data-dir)
   (make-directory* data-dir)
   (make-directory* logs-dir)
   (delete-directory/files config-dir)
   (copy-directory/files (build-path elasticsearch-dir "config") config-dir)
   (call-with-output-file (build-path config-dir "elasticsearch.yml")
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
      (format "node-~a" node)
      data-dir
      logs-dir
      (+ 9200 node)
      "basic"))
    #:exists 'append)
   (set-add! config-dirs config-dir)))
 (for ([node (number-of-nodes)])
  (create-dirs-for node)))

(verbose-log "Created [~v] data dirs" (number-of-nodes))

;; Start nodes specifying config path with ES_PATH_CONF
(define (start-elasticsearch config-dir)
 (subprocess #f #f #f 
  "/usr/bin/env" 
  (format "ES_PATH_CONF=~a" config-dir) 
  (format "ES_JAVA_OPTS=~a" "-Des.shutdown_feature_flag_enabled=true") 
  (build-path elasticsearch-dir "bin" "elasticsearch")))

(info-log "Starting [~a] nodes..." (number-of-nodes))
(define (fuck-values . values)
 (let-values ([(the-one-you-care-about useless1 useless2 useless3) values])
  the-one-you-care-about))

(define subprocs 
 (set-map config-dirs 
  (lambda (node-config) 
   (let-values ([(sp dontcare1 dontcare2 dontcare3) (start-elasticsearch node-config)])
    sp))))

(printf "Pids: ")
(for ([sp subprocs])
 (printf "~a " (subprocess-pid sp)))
(printf "~n~n")

(printf "Cluster is running. Press enter to kill the cluster.")

(read-line (current-input-port) 'any)
(for ([sp subprocs])
 (printf "Killing ~a..." (subprocess-pid sp))
 (printf "~a, " (subprocess-kill sp #t))
 (let loop ([current-status (subprocess-status sp)])
  ;;(verbose-log "Current status: [~s], equal to 'running: [~s]" current-status (equal? current-status 'running))
  (when (equal? 'running current-status)
   (sleep 0.1)
   (loop (subprocess-status sp))))
 (printf "result: ~a~n" (subprocess-status sp)))

