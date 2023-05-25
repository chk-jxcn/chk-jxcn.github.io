---
title: "HtDP1e 部分习题解"
date: 2022-11-23
categories:
- HtDP
- scheme
---





看了几天SICP没看明白，于是决定先看看HtDP，感觉scheme的入门书籍还挺有意思的



<!--more-->





# 11.4 阶乘

```scheme
#lang racket

(require racket/trace)
(define (sub1 x) (- x 1))
(trace-define (! x)
  (trace-let !-helper ([y x] [val 1]) 
  (cond
    [(zero? y) val]
    [else (!-helper (sub1 y) (* val y))]
    )))

(trace-define (o! x)
  (cond
    [(zero? x) 1]
    [else (* x (o! (sub1 x)))]
    ))
```



# 12.4 单词重列

```scheme
#lang racket
(require racket/trace)
; x + () = ()
; x + (a) = (xa ax)
; x + (b a) = ((b (x + (a))) (x (b a)))

;; list of word -> list of word
;; a (x y z) -> (ax ay az)
(define (concat-word a low)
  (cond
    [(empty? low) empty]
    [else (append (list (cons a (first low))) (concat-word a (rest low)))]
))

;; word -> list of word
(define (insert-inword a word)
  (cond
    [(empty? word) (list (list a))]
    [else (append (list (cons a word)) (concat-word (first word) (insert-inword a (rest word))))]
    ))

;; list of word -> list of word
;; insert a in list of word
(define (insert-inlist a list-of-word)
  (cond
    [(empty? list-of-word) empty]
    [else (append (insert-inword a (first list-of-word)) (insert-inlist a (rest list-of-word)))]
  ))

;; word : '(a b c)
;; arrangements: works -> list-of-words
;; create list of a-word
(define (arrangement a-word)
  (cond
    [(empty? a-word) empty]
    [(empty? (cdr a-word)) (list a-word)]
    [else (insert-inlist (first a-word) (arrangement (cdr a-word)))]
    ))
```





# 14.2 二叉搜索树

```scheme
#lang racket

(struct node (ssn name left right)
  #:methods gen:custom-write
  [(define (write-proc node-val output-port output-mode)
     (fprintf output-port "#<node:~a ~a L:~a R:~a>" (node-ssn node-val)
              (node-name node-val)
              (node-left node-val)
              (node-right node-val)))])


(define (inorder BT)
  (cond
    [(and (boolean? BT) (false? BT)) empty]
    ; (inorder BT-left) + BT + (inorder BT-right)
    [else (append (inorder (node-left BT)) (list BT) (inorder (node-right BT)))]
    )
  )

; 
(define (search-bst B n)
  (cond
    [(and (boolean? B) (false? B)) #f]
    [(= (node-ssn B) n) (node-name B)]
    [else (or (search-bst (node-left B) n) (search-bst (node-right B) n))]
    ))

; create a BST base on BST B
(define (create-bst B SSN Name)
  (cond
    [(eq? B #f) (node SSN Name #f #f)]
    [else 
     (cond
       [(< SSN (node-ssn B))
        (node (node-ssn B)
              (node-name B)
              (create-bst (node-left B) SSN Name)
              (node-right B))]
       [(> SSN (node-ssn B))
        (node (node-ssn B)
              (node-name B)
              (node-left B)
              (create-bst (node-right B) SSN Name)
              )]
       )]
    ))

(define (create-bst-from-list l)
  (cond
    [(empty? l) #f]
    [else (create-bst (create-bst-from-list (cdr l)) (caar l) (cdar l))]
    )
  )
```



# 16.3 目录树

```scheme
#lang racket


(struct dir (name dirs files))
(struct file (name size content)
    #:methods gen:custom-write
  [(define (write-proc node-val output-port output-mode)
     (fprintf output-port "#<file:~a>" (file-name node-val)
))])


(define (how-many-file lof)
  (cond
    [(empty? lof) 0]
    [else (+ 1 (how-many-file (cdr lof)))]
    ))

(define (how-many-file-indirs lod)
  (cond
    [(empty? lod) 0]
    [else (+ (how-many (car lod)) (how-many-file-indirs (cdr lod))) ]
    ))

(define (how-many d)
  (+ (how-many-file (dir-files d)) (how-many-file-indirs (dir-dirs d)))
  )

(define (size-files files)
  (cond
    [(empty? files) 0 ]
    [else (+ (file-size (car files)) (size-files (cdr files)))]
    ))

(define (size-dirs dirs)
  (cond
    [(empty? dirs) 0]
    [else (+ (du-dir (car dirs)) (size-dirs (cdr dirs)))]
    ))

(define (du-dir d)
  (+ (size-files (dir-files d)) (size-dirs (dir-dirs d))))


(require racket/trace)

(define (find-files files name)
  (cond
    [(empty? files) #f]
    [(symbol=? name (file-name (car files))) #t]
    [else (find-files (cdr files) name)]
    ))

; find name in dirs, return list or false
; empty -> false
; if found in a dir return (cons + (find dirs))
(define (find-dirs dirs name)
  (cond
    [(empty? dirs) #f]
    [(find-files (dir-files (first dirs)) name) (list (dir-name (first dirs)))]
    [(list? (find (first dirs) name)) (cons (dir-name (first dirs)) (find-dirs (dir-dirs (first dirs)) name))]
    [else (find-dirs (cdr dirs) name)]
    )
)


; find name in dir, return list or false
; (find d name) = find files -> return d -> ()
(define (find d name)
  (cond
    [(find-files (dir-files d) name) (list (dir-name d))]
    [(list? (find-dirs (dir-dirs d) name)) (cons (dir-name d) (find-dirs (dir-dirs d) name))]
    [else #f]
  ))


(define make-file file)
(define make-dir dir)

;; files: 
(define hang (make-file 'hang 8 empty))
(define draw (make-file 'draw 2 empty))
(define read (make-file 'read! 19 empty))
(define one  (make-file 'part1 99 empty))
(define two  (make-file 'part2 52 empty))
(define thre (make-file 'part3 17 empty))
(define rdme (make-file 'read 10 empty))

;; directories: 
(define Code (make-dir 'Code '() (list hang draw)))
(define Docs (make-dir 'Docs '() (list read)))
(define Libs (make-dir 'Libs (list Code Docs) '()))
(define Text (make-dir 'Text '() (list one two thre)))
(define Top  (make-dir 'TS (list Text Libs) (list rdme)))
```



# 22.3.1 list->number

```scheme
;; 其实这里可以用foldr
;; (foldr (lambda (digit num) (+ (* num 10) digit)) 0 lod)
;; 但是foldr不是尾调用，虽然看起来更简单
(define (build-number x)
  (local ((define (build-number-helper lod num)
  (cond
    [(empty? lod) num]
    [else (build-number-helper (cdr lod) (+ (car lod) (* num 10))) ]
    )))
  (build-number-helper x 0))
)
```



# 22.2.3 pad->gui

```scheme
(require htdp/gui)

;; pad->gui : (listof (listof number|symbol))  ->  (listof (listof gui-item))
;; convert a list of number|symbol list to gui-item list. 
;; the first row displays the latest button that the user clicked.
;; others are button genrate base on argument.
(define (pad->gui pad)
  (local 
    ((define val (make-message "N")))
    (cons (list val)
          (map
           (lambda (x)
             (map
              (lambda (x)
                ((lambda (x) (make-button x (lambda (e) (draw-message val x))))
                 (cond
                   [(symbol? x) (symbol->string x)]
                   [(number? x) (number->string x)]
                   [else "unknow"]
                   ))
                ) x)) pad))
    )
  )

;; Example
(define pad
  '((1 2 3)
    (4 5 6)
    (7 8 9)
    (\# 0 *)))
   	
(define pad2 
  '((1 2 3  +)
    (4 5 6  -)
    (7 8 9  *)
    (0 = \. /)))
(create-window (append (list (list (make-message "Calculator"))) (pad->gui pad)))
```



# 23.1.1 series-local

```scheme
;; series: (number -> number) -> ((number -> number))
;; input a sequence function, return a function return sum of sequence.
(define (series-local f)
  (local
    ((define (series n)
       (cond
    [(= n 0) (f n)]
    [else (+ (f n) 
	     (series (- n 1)))])
       ))
    series
    )
)

(define (make-even i)
  (* 2 i))

((series-local make-even) 10)
```



# 23.2 arithmetic sequence

```scheme
(define (a-fives n)
  (cond
    [(= n 0) (+ 3 5)]
    [else (+ 5 (a-fives (- n 1)))]
    )
  )

(define (a-fives-closed n)
  (+ (* n 5) (+ 3 5)))

(define (my-build-list n f)
  (cond
    [(= n 0) (list (f 0))]
    [else (append (my-build-list (- n 1) f) (list (f n)))]
  ))

(define (seq-g-fives n)
  (my-build-list n a-fives)
  )

;; example
(seq-g-fives 10)

(define (arithmetic-series start s)
  (local
    ((define (a n)
       (+ (* n 5) (+ start s))))
       
  a
    ))

((arithmetic-series 0 2) 10)
```

