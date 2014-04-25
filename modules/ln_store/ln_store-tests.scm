(unit-test "store-data" "Verify the store sets and returns data properly"
  (lambda ()
    (define store (make-store (time->timestamp (current-time))))
    (define str "this is a string")
    (define int 1234)
    (define float 3.141526)
    (define fraction 1/3)
    (define function sin)
    (define lst (list (list "a" "b" 1 2 3) (list "c" "d" 4 5 6)))
    (define bool #t)
    (define complex 2+3i)
    (define symbol 'asdf)
    (define u8vec (u8vector 8 7 3 189 23 21 1))
    (define vect (vector 1 2 4 4 3 2 112))
    (define vars (list str int float fraction function lst bool complex symbol u8vec vect))
    (define varn (list "str" "int" "float" "fraction" "function" "lst" "bool" "complex"
                       "symbol" "u8vect" "vect"))
    (set! ##now 0.)
    ;; Set and retrieve all variables
    (set! part1 (let loop ((k varn) (v vars) (pass #t))
      (if (null? k)
        pass
        (begin
          (store-set! store (car k) (car v))
          (loop (cdr k) (cdr v) (and pass (equal? (car v) (store-ref store (car k) #f))))
        )
      )
    ))
    ;; Clear all variables and see if they are gone (and fallback options)
    (store-clear! store varn)
    (set! part2 (fx= 0 (apply + (map (lambda (v) (store-ref store v 0)) varn))))
    ;; Test data store expiry
    (set! part3 (let ((v 31))
      (store-set! store "v" v)
      (and (= (store-timedref store "v" #f) v)
           (begin
             (set! ##now (+ ##now 32))
             (not (store-timedref store "v" #f))
           )
           (= (store-ref store "v" #f) v)
      )
    ))
    ;; Test store category retrieval
    (set! part4 (let ((vars (list "a" "b" "c")))
      (for-each (lambda (v) (store-set! store v v "mycat")) vars)
      (equal? vars (map car (store-listcat store "mycat")))
    ))
    ;; Test timestamps and setnew
    (set! part5 (let ((v 80))
      (store-set! store "ln" v)
      (set! time-before (store-timestamp store "ln"))
      (set! ##now (+ ##now 5))
      (store-setnew! store "ln" v)
      (set! time-after (store-timestamp store "ln"))
      (store-set! store "ln" 1234)
      (set! time-new (store-timestamp store "ln"))
      (and (= time-before time-after) (= time-new (+ time-before 5)))
    ))
    ;; Return the combined test results
    (and part1 part2 part3 part4 part5)
  ))

(unit-test "store-events" "Verify the Event functionality of the store"
  (lambda ()
    (define store (make-store (time->timestamp (current-time))))
    (set! ##now 0.5)
    ;; Event submission and retrival
    (set! part1 (let ((prio 1)
          (id "monitor")
          (payload "alarm"))
      (store-event-add store prio id payload)
      (equal? (list (list 0.5 (string-append id ":" payload) prio)) (store-event-listnew store))
    ))
    ;; Event Graylisting
    (set! part2 (let ((prio 2)
                      (id "monitor")
                      (payload "**alarm**"))
      (set! ##now (+ ##now 120))
      (store-event-add store prio id payload)
      (set! ##now (+ ##now 15))
      (store-event-add store prio id payload)
      (set! ##now (+ ##now 15))
      (store-event-add store prio id payload)
      (set! ##now (+ ##now 15))
      (store-event-add store prio id payload)
      (equal? (list (list 120.5 (string-append id ":" payload) prio)) (store-event-listnew store 120))
    ))
    ;; Make sure none are missed
    (set! part3 (let loop ((i 0))
      (if (fx= i 10000) 
        (and (= i (length (store-event-listnew store 150)))
             (= 0 (length (store-event-listnew store ##now))))
        (begin
          (store-event-add store 0 "test" i)
          (set! ##now (+ ##now (random-real)))
          (loop (fx+ i 1))
        )
      )
    ))
    (and part1 part2 part3)
  ))
;;eof
