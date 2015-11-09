#lang typed/racket

(require "lib.rkt")

(displayln "Make started")
;(current-directory "..")

; TODO:
;raco pkg install alexis-util
;And some other collections too.
;
;cat graph/structure.lp2.rkt | awk '{if (length > 80) print NR "\t" length "\t" $0}' | sed -e 's/^\([0-9]*\t[0-9]*\t.\{80\}\)\(.*\)$/\1\x1b[0;30;41m\2\x1b[m/'

;; TODO: should directly exclude them in find-files-by-extension.
(define excluded-dirs (list "docs/" "bug/" "lib/doc/bracket/" "lib/doc/math-scribble/" "lib/doc/MathJax/"))
(define (exclude-dirs [files : (Listof Path)] [excluded-dirs : (Listof String) excluded-dirs])
  (filter-not (λ ([p : Path])
                (ormap (λ ([excluded-dir : String])
                         (string-prefix? excluded-dir (path->string p)))
                       excluded-dirs))
              files))

(define scrbl-files (exclude-dirs (find-files-by-extension ".scrbl")))
(define lp2-files (exclude-dirs (find-files-by-extension ".lp2.rkt")))
(define rkt-files (exclude-dirs (find-files-by-extension ".rkt")))
(define html-sources (append scrbl-files lp2-files))
(define html-files (map (λ ([scrbl-or-lp2 : Path]) (build-path "docs/" (regexp-case (path->string scrbl-or-lp2) [#rx"\\.scrbl" ".html"] [#rx"\\.lp2\\.rkt" ".lp2.html"])))
                        html-sources))
(define mathjax-links (map (λ ([d : Path]) (build-path d "MathJax")) (remove-duplicates (map dirname html-files))))

(: scribble (→ Path (Listof Path) Any))
(define (scribble file all-files)
  (run `(,(or (find-executable-path "scribble") (error "Can't find executable 'scribble'"))
         "--html"
         "--dest" ,(build-path "docs/" (dirname file))
         "+m"
         "--redirect-main" "http://docs.racket-lang.org/"
         "--info-out" ,(build-path "docs/" (path-append file ".sxref"))
         ,@(append-map (λ ([f : Path-String]) : (Listof Path-String)
                         (let ([sxref (build-path "docs/" (path-append f ".sxref"))])
                           (if (file-exists? sxref)
                               (list "++info-in" sxref)
                               (list))))
                       (remove file all-files))
         ,file)))

;(make-collection "phc" rkt-files (argv))
;(make-collection "phc" '("graph/all-fields.rkt") #("zo"))
;(require/typed compiler/cm [managed-compile-zo (->* (Path-String) ((→ Any Input-Port Syntax) #:security-guard Security-Guard) Void)])
;(managed-compile-zo (build-path (current-directory) "graph/all-fields.rkt"))

;; make-collection doesn't handle dependencies due to (require), so if a.rkt requires b.rkt, and b.rkt is changed, a.rkt won't be rebuilt.
;; this re-compiles each-time, even when nothing was changed.
;((compile-zos #f) rkt-files 'auto)

;; This does not work, because it tries to create the directory /usr/local/racket-6.2.900.6/collects/syntax/parse/private/compiled/drracket/
;(require/typed compiler/cm [managed-compile-zo (->* (Path-String) ((→ Any Input-Port Syntax) #:security-guard Security-Guard) Void)])
;(for ([rkt rkt-files])
;  (managed-compile-zo (build-path (current-directory) rkt)))

(run! `(,(or (find-executable-path "raco") (error "Can't find executable 'raco'"))
       "make"
       ,@rkt-files))

(make/proc
 (rules (list "zo" (append html-files
                           mathjax-links))
        (for/rules ([scrbl-or-lp2 html-sources]
                    [html html-files])
                   (html)
                   (scrbl-or-lp2)
                   (scribble scrbl-or-lp2 html-sources))
        (for/rules ([mathjax-link mathjax-links])
                   (mathjax-link)
                   ()
                   (make-file-or-directory-link (simplify-path (apply build-path `(same ,@(map (λ (x) 'up) (explode-path (dirname mathjax-link))) "lib" "doc" "MathJax")) #f)
                                                mathjax-link)))
 (argv))

(run! `(,(or (find-executable-path "raco") (error "Can't find executable 'raco'"))
       "cover"
       ,@(exclude-dirs rkt-files (list "make/"))))