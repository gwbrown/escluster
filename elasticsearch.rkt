#lang racket 

(require file/gunzip
         file/untar
         "log.rkt")

(provide extracted-es-dir extract-es-pkg build-elasticsearch es-source-dir built-es-package package-url)

(define es-source-dir (make-parameter (build-path (find-system-path 'home-dir) "workspace" "elasticsearch")))

(define/contract (built-es-package platform arch)
  (-> string? string? path-string?)
  (build-path
   (es-source-dir)
   "distribution"
   "archives"
   (format "~a-tar" platform)
   "build"
   "distributions"
   (format "elasticsearch-8.0.0-SNAPSHOT-~a-~a.tar.gz" platform arch)))

;; This only works for versions >=7.0.0, but that's okay for now.
(define/contract (package-url ver platform arch)
  (-> (or/c symbol? string?) string? string? path-string?)
  (if (eq? ver 'snapshot)
      (built-es-package platform arch)
      (format "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-~a-~a-~a.tar.gz" ver platform arch)))

(define (extracted-es-dir base-dir ver)
  (build-path base-dir "elasticsearch" ver))

(define (extract-es-pkg tmp-dir es-package ver)
  (info-log "Extracting Elasticsearch...")
  (if (directory-exists? tmp-dir)
      (verbose-log "Working directory [~v] exists" tmp-dir)
      (begin
        (verbose-log "Working directory [~v] does not exist, creating it..." tmp-dir)
        (make-directory* tmp-dir)))
  (let ((target-dir (extracted-es-dir tmp-dir ver)))
    (if (directory-exists? (extracted-es-dir tmp-dir ver))
        (begin
          (info-log "Directory [~v] exists, removing and re-creating..." target-dir)
          (delete-directory/files target-dir)
          (make-directory* target-dir))
        (begin
          (verbose-log "ES directory [~v] does not exist yet, creating..." target-dir)
          (make-directory* target-dir))))
  (verbose-log "Starting ungzip...")
  (let* [(target-dir (extracted-es-dir tmp-dir ver))
         (es-tar (build-path target-dir "espkg.tar"))]
    (call-with-output-file es-tar
      (lambda (out)
        (call-with-input-file es-package
          (lambda (in)
            (gunzip-through-ports in out))))
      #:exists 'replace)
    (verbose-log "Elasticsearch gzip extracted to [~v], untarring..." es-tar)
    (untar es-tar 
           #:dest target-dir
           #:strip-count 1
           #:permissive? #t)
    (info-log "Elasticsearch extracted to [~v]." target-dir)
    (delete-file es-tar)
    (verbose-log "Deleted temporary tar file at [~v]" es-tar)))

(define (build-elasticsearch)
  (let ([old-dir (current-directory)])
    (info-log "Rebuilding Elasticsearch as requested...")
    (current-directory (es-source-dir))
    (system "./gradlew :distribution:archives:darwin-tar:assemble")
    (info-log "Finished rebulding Elasticsearch.")
    (current-directory old-dir)))
