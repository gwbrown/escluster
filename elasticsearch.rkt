#lang racket 

(require file/gunzip
         file/untar
         "log.rkt")

(provide extracted-es-dir extract-es-pkg build-elasticsearch es-source-dir es-package)

(define es-source-dir (make-parameter "/Users/gbrown/workspace/elasticsearch"))
(define es-package (make-parameter "/Users/gbrown/workspace/elasticsearch/distribution/archives/darwin-tar/build/distributions/elasticsearch-8.0.0-SNAPSHOT-darwin-x86_64.tar.gz"))

(define (extracted-es-dir tmp-dir)
 (build-path tmp-dir "elasticsearch"))

(define (extract-es-pkg tmp-dir)
 (info-log "Extracting Elastcsearch...")
 (if (directory-exists? tmp-dir)
  (verbose-log "Working directory [~v] exists" tmp-dir)
  (begin
   (verbose-log "Working directory [~v] does not exist, creating it..." tmp-dir)
   (make-directory* tmp-dir)))
 (if (directory-exists? (extracted-es-dir tmp-dir))
  (begin
   (info-log "Directory [~v] exists, removing and re-creating..." (extracted-es-dir tmp-dir))
   (delete-directory/files (extracted-es-dir tmp-dir)))
  (begin
   (verbose-log "ES directory [~v] does not exist yet, creating..." (extracted-es-dir tmp-dir))
   (make-directory* (extracted-es-dir tmp-dir))))
 (verbose-log "Starting ungzip...")
 (let [(es-tar (build-path (extracted-es-dir tmp-dir) "espkg.tar"))]
  (call-with-output-file es-tar
   (lambda (out)
    (call-with-input-file (es-package)
     (lambda (in)
      (gunzip-through-ports in out))))
   #:exists 'replace)
  (verbose-log "Elasticsearch gzip extracted to [~v], untarring..." es-tar)
  (untar es-tar 
   #:dest (extracted-es-dir tmp-dir)
   #:strip-count 1
   #:permissive? #t)
  (info-log "Elasticsearch extracted to [~v]." (extracted-es-dir tmp-dir))
  (delete-file es-tar)
  (verbose-log "Deleted temporary tar file at [~v]" es-tar)))

(define (build-elasticsearch)
 (let ([old-dir (current-directory)])
  (info-log "Rebuilding Elasticsearch as requested...")
  (current-directory (es-source-dir))
  (system "./gradlew :distribution:archives:darwin-tar:assemble")
  (info-log "Finished rebulding Elasticsearch.")
  (current-directory old-dir)))
