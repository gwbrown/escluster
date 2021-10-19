#lang racket/base

(require racket/class
         racket/file
         racket/format
         racket/port
         "elasticsearch.rkt"
         "log.rkt")

(provide
 tmp-dir
 node%)

(define tmp-dir (make-parameter "/Users/gbrown/.escluster"))

(define node% 
  (class object%
    (init id [versn 'snapshot])
    (define node-id id)
    (define ver versn) 
    (define subproc #f)
    (define stdout #f)
    (define stdin #f)
    (define stderr #f)

    (super-new)

    (define/public (node-dir)
      (build-path (tmp-dir) "nodes" (~a node-id)))

    (define/public (config-dir)
      (build-path (node-dir) "config"))

    (define/public (data-dir)
      (build-path (node-dir) "data"))

    (define/public (logs-dir)
      (build-path (node-dir) "logs"))

    (define/public (get-id)
      node-id)
    
    (define/public (get-stdout)
      (port->string stdout #:close? #f))

    (define/public (get-stderr)
      (port->string stderr #:close? #f))

    (define/public (change-version new-version)
      (set! ver new-version))

    (define/public (create-dirs (recreate-dirs #f))
      (when recreate-dirs
        (info-log "Removing files for node [~a]..." node-id)
        (delete-directory/files (data-dir) #:must-exist? #f)
        (delete-directory/files (logs-dir) #:must-exist? #f)
        (delete-directory/files (config-dir) #:must-exist? #f))
      (verbose-log "Creating log, config and data dirs for node [~v] at [~v]..." node-id (node-dir))
      (make-directory* (data-dir))
      (make-directory* (logs-dir))
      (if (not (directory-exists? (config-dir)))
          (begin
            (verbose-log "Config dir does not exist, copying default config files...")
            (make-parent-directory* (config-dir))
            (copy-directory/files (build-path (extracted-es-dir (tmp-dir) (symbol->string ver)) "config") (config-dir))
            (call-with-output-file (build-path (config-dir) "elasticsearch.yml")
              (lambda (out)
                (fprintf out "
cluster.name: ~a
node.name: ~a
path.data: ~a
path.logs: ~a
http.port: ~a
xpack.license.self_generated.type: ~a
xpack.security.enabled: false
"
                         "escluster-cluster"
                         (format "node-~a" node-id)
                         (data-dir)
                         (logs-dir)
                         (+ 9200 node-id)
                         "basic"))
              #:exists 'append))
          (verbose-log "Config directory exists, ignoring..."))
      (verbose-log "Done setting up data, log, and config directories."))


    (define/public (reset)
      (create-dirs #t))

    (define/public (get-pid)
      (if (eq? #f subproc)
          #f
          (subprocess-pid subproc)))

    (define/public (get-status)
      (if (eq? #f subproc)
          #f
          (subprocess-status subproc)))

    (define/public (start (recreate-dirs #f) (debug-mode #f))
      (create-dirs recreate-dirs)
      (let* ([path-conf (format "ES_PATH_CONF=~a" (config-dir))]
             [debug-str (if debug-mode 
                            "-agentlib:jdwp=transport=dt_socket,server=n,suspend=y,address=5005,suspend=y"
                            "")]
             [java-opts (format "ES_JAVA_OPTS=~a " 
                                debug-str)]
             [es-executable (build-path (extracted-es-dir (tmp-dir) ver) "bin" "elasticsearch")])
        (set!-values (subproc stdout stdin stderr)
                     (parameterize ([current-subprocess-custodian-mode 'kill])
                       (subprocess #f #f #f
                                   "/usr/bin/env"
                                   path-conf
                                   java-opts
                                   es-executable)))))

    (define/public (stop)
      (subprocess-kill subproc #f)
      (info-log (format "Attempting to stop node [~a] with pid [~a]..." node-id (subprocess-pid subproc)))
      (let loop ([current-status (subprocess-status subproc)]
                 [iters 0])
        (when (equal? 'running current-status)
          (when (< 50 iters)
            (info-log "Waited longer than 5 seconds for process to stop, forcibly killing...")
            (subprocess-kill subproc #t))
          (sleep 0.1)
          (loop (subprocess-status subproc) (+ 1 iters))))
      (info-log (format "Stopped node [~a], result [~a]~n" 
                        node-id 
                        (subprocess-status subproc)))))) 

  
