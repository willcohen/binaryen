;; NOTE: Assertions have been generated by update_lit_checks.py --all-items and should not be edited.
;; RUN: foreach %s %t wasm-opt --once-reduction -all -S -o - | filecheck %s

(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    ;; A minimal "once" function.
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $caller
    ;; Call a once function more than once, in a way that we can optimize: the
    ;; first dominates the second.
    (call $once)
    (call $once)
  )
)

(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (i32.const 100)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
    ;; Add some more content in the function.
    (drop (i32.const 100))
  )

  ;; CHECK:      (func $caller-if-1
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (block $block
  ;; CHECK-NEXT:    (call $once)
  ;; CHECK-NEXT:    (nop)
  ;; CHECK-NEXT:    (nop)
  ;; CHECK-NEXT:    (nop)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $caller-if-1
    ;; Add more calls, and ones that are conditional.
    (if
      (i32.const 1)
      (block
        (call $once)
        (call $once)
        (call $once)
        (call $once)
      )
    )
    (call $once)
    (call $once)
  )

  ;; CHECK:      (func $caller-if-2
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (call $once)
  ;; CHECK-NEXT:   (block $block
  ;; CHECK-NEXT:    (call $once)
  ;; CHECK-NEXT:    (nop)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $caller-if-2
    ;; Call in both arms. As we only handle dominance, and not merges, the first
    ;; call after the if is *not* optimized.
    (if
      (i32.const 1)
      (call $once)
      (block
        (call $once)
        (call $once)
      )
    )
    (call $once)
    (call $once)
  )

  ;; CHECK:      (func $caller-loop-1
  ;; CHECK-NEXT:  (loop $loop
  ;; CHECK-NEXT:   (if
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:    (call $once)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (call $once)
  ;; CHECK-NEXT:   (nop)
  ;; CHECK-NEXT:   (br_if $loop
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $caller-loop-1
    ;; Add calls in a loop.
    (loop $loop
      (if
        (i32.const 1)
        (call $once)
      )
      (call $once)
      (call $once)
      (br_if $loop (i32.const 1))
    )
    (call $once)
    (call $once)
  )

  ;; CHECK:      (func $caller-loop-2
  ;; CHECK-NEXT:  (loop $loop
  ;; CHECK-NEXT:   (if
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:    (call $once)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (br_if $loop
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $caller-loop-2
    ;; Add a single conditional call in a loop.
    (loop $loop
      (if
        (i32.const 1)
        (call $once)
      )
      (br_if $loop (i32.const 1))
    )
    (call $once)
    (call $once)
  )

  ;; CHECK:      (func $caller-single
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller-single
    ;; A short function with a single call.
    (call $once)
  )

  ;; CHECK:      (func $caller-empty
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $caller-empty
    ;; A tiny function with nothing at all.
  )
)

;; Corner case: Initial value is not zero. We can still optimize this here,
;; though in fact the function will never execute the payload call of foo(),
;; which in theory we could further optimize.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (import "env" "foo" (func $foo))
  (import "env" "foo" (func $foo))

  ;; CHECK:      (global $once (mut i32) (i32.const 42))
  (global $once (mut i32) (i32.const 42))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call $foo)
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
    (call $foo)
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
  )
)

;; Corner case: function is not quite once, there is code before the if.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (import "env" "foo" (func $foo))
  (import "env" "foo" (func $foo))

  ;; CHECK:      (global $once (mut i32) (i32.const 42))
  (global $once (mut i32) (i32.const 42))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call $foo)
  ;; CHECK-NEXT: )
  (func $once
    (nop)
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
    (call $foo)
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
  )
)

;; Corner case: a nop after the if.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (import "env" "foo" (func $foo))
  (import "env" "foo" (func $foo))

  ;; CHECK:      (global $once (mut i32) (i32.const 42))
  (global $once (mut i32) (i32.const 42))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call $foo)
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (nop)
    (global.set $once (i32.const 1))
    (call $foo)
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
  )
)

;; Corner case: The if has an else.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (import "env" "foo" (func $foo))
  (import "env" "foo" (func $foo))

  ;; CHECK:      (global $once (mut i32) (i32.const 42))
  (global $once (mut i32) (i32.const 42))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:   (call $foo)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call $foo)
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
      (call $foo)
    )
    (global.set $once (i32.const 1))
    (call $foo)
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
  )
)

;; Corner case: different global names in the get and set
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once1 (mut i32) (i32.const 0))
  (global $once1 (mut i32) (i32.const 0))
  ;; CHECK:      (global $once2 (mut i32) (i32.const 0))
  (global $once2 (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once1)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once2
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once1)
      (return)
    )
    (global.set $once2 (i32.const 1))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
  )
)

;; Corner case: The global is written a zero.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 0)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 0))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
  )
)

;; Corner case: The global is written a zero elsewhere.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 0)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
    (global.set $once (i32.const 0))
  )
)

;; Corner case: The global is written a non-zero value elsewhere. This is ok to
;; optimize, and in fact we can write a value different than 1 both there and
;; in the "once" function, and we can still optimize.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 42)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 42))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
    (global.set $once (i32.const 1337))
  )

  ;; CHECK:      (func $caller-2
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1337)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $caller-2
    ;; Reverse order of the above.
    (global.set $once (i32.const 1337))
    (call $once)
    (call $once)
  )
)

;; It is ok to call the "once" function inside itself - as that call appears
;; behind a set of the global, the call is redundant and we optimize it away.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
    (call $once)
  )
)

;; Corner case: Non-integer global, which we ignore.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut f64) (f64.const 0))
  (global $once (mut f64) (f64.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.trunc_f64_s
  ;; CHECK-NEXT:    (global.get $once)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (f64.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      ;; We must cast this to an integer for the wasm to validate.
      (i32.trunc_f64_s
        (global.get $once)
      )
      (return)
    )
    (global.set $once (f64.const 1))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
  )
)

;; Corner case: Non-constant initial value.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (import "env" "glob" (global $import i32))
  (import "env" "glob" (global $import i32))

  ;; CHECK:      (global $once (mut i32) (global.get $import))
  (global $once (mut i32) (global.get $import))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
  )
)

;; Corner case: Non-constant later value.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.eqz
  ;; CHECK-NEXT:    (i32.eqz
  ;; CHECK-NEXT:     (i32.const 1)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.eqz (i32.eqz (i32.const 1))))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
  )
)

;; Corner case: "Once" function has a param.
(module
  ;; CHECK:      (type $i32_=>_none (func (param i32)))

  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once (param $x i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once (param $x i32)
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $caller
    (call $once (i32.const 1))
    (call $once (i32.const 1))
  )
)

;; Corner case: "Once" function has a result.
(module
  ;; CHECK:      (type $none_=>_i32 (func (result i32)))

  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once (result i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return
  ;; CHECK-NEXT:    (i32.const 2)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (i32.const 3)
  ;; CHECK-NEXT: )
  (func $once (result i32)
    (if
      (global.get $once)
      (return (i32.const 2))
    )
    (global.set $once (i32.const 1))
    (i32.const 3)
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (call $once)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (call $once)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $caller
    (drop (call $once))
    (drop (call $once))
  )
)

;; Corner case: "Once" function body is not a block.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (loop $loop
  ;; CHECK-NEXT:   (if
  ;; CHECK-NEXT:    (global.get $once)
  ;; CHECK-NEXT:    (return)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (global.set $once
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (loop $loop
      (if
        (global.get $once)
        (return)
      )
      (global.set $once (i32.const 1))
    )
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
  )
)

;; Corner case: Once body is too short.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
  )
)

;; Corner case: Additional reads of the global.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
    (drop (global.get $once))
  )
)

;; Corner case: Additional reads of the global in the "once" func.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
    (drop (global.get $once))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
  )
)

;; Corner case: Optimization opportunties in unreachable code (which we can
;; ignore, but should not error on.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (unreachable)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $caller
    (call $once)
    (call $once)
    (unreachable)
    (call $once)
    (call $once)
  )
)

;; Add a very long chain of control flow.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
  )

  ;; CHECK:      (func $caller
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (call $once)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (call $once)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (call $once)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (nop)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (nop)
  ;; CHECK-NEXT:   (nop)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (nop)
  ;; CHECK-NEXT:   (nop)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (nop)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (nop)
  ;; CHECK-NEXT:   (nop)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (nop)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:   (nop)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $caller
    (if
      (i32.const 1)
      (call $once)
    )
    (if
      (i32.const 1)
      (call $once)
    )
    (if
      (i32.const 1)
      (call $once)
    )
    (call $once)
    (if
      (i32.const 1)
      (call $once)
    )
    (call $once)
    (if
      (i32.const 1)
      (nop)
      (nop)
    )
    (call $once)
    (if
      (i32.const 1)
      (nop)
      (call $once)
    )
    (call $once)
    (if
      (i32.const 1)
      (call $once)
    )
    (call $once)
    (if
      (i32.const 1)
      (nop)
      (call $once)
    )
    (call $once)
    (if
      (i32.const 1)
      (call $once)
    )
    (call $once)
    (if
      (i32.const 1)
      (call $once)
    )
    (call $once)
    (call $once)
  )
)

;; A test with a try-catch. This verifies that we emit their contents properly
;; in reverse postorder and do not hit any assertions.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (type $i32_=>_none (func (param i32)))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (tag $tag (param i32))
  (tag $tag (param i32))

  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
  )

  ;; CHECK:      (func $try-catch
  ;; CHECK-NEXT:  (try $label$5
  ;; CHECK-NEXT:   (do
  ;; CHECK-NEXT:    (if
  ;; CHECK-NEXT:     (i32.const 1)
  ;; CHECK-NEXT:     (call $once)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (catch $tag
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (pop i32)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $try-catch
    (try $label$5
      (do
        (if
          (i32.const 1)
          (call $once)
        )
      )
      (catch $tag
        (drop
          (pop i32)
        )
      )
    )
  )
)

(module
  ;; Test a module with more than one global that we can optimize, and more than
  ;; one that we cannot.

  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once1 (mut i32) (i32.const 0))
  (global $once1 (mut i32) (i32.const 0))
  ;; CHECK:      (global $many1 (mut i32) (i32.const 0))
  (global $many1 (mut i32) (i32.const 0))
  ;; CHECK:      (global $once2 (mut i32) (i32.const 0))
  (global $once2 (mut i32) (i32.const 0))
  ;; CHECK:      (global $many2 (mut i32) (i32.const 0))
  (global $many2 (mut i32) (i32.const 0))

  ;; CHECK:      (func $once1
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once1)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once1
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (call $many1)
  ;; CHECK-NEXT:  (call $once2)
  ;; CHECK-NEXT:  (call $many2)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (call $many1)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (call $many2)
  ;; CHECK-NEXT: )
  (func $once1
    (if
      (global.get $once1)
      (return)
    )
    (global.set $once1 (i32.const 1))
    (call $once1)
    (call $many1)
    (call $once2)
    (call $many2)
    (call $once1)
    (call $many1)
    (call $once2)
    (call $many2)
  )

  ;; CHECK:      (func $many1
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $many1)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $many1
  ;; CHECK-NEXT:   (i32.const 0)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call $many2)
  ;; CHECK-NEXT:  (call $once1)
  ;; CHECK-NEXT:  (call $many1)
  ;; CHECK-NEXT:  (call $once2)
  ;; CHECK-NEXT:  (call $many2)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (call $many1)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $many1
    (if
      (global.get $many1)
      (return)
    )
    (global.set $many1 (i32.const 0)) ;; prevent this global being "once"
    (call $many2)
    (call $once1)
    (call $many1)
    (call $once2)
    (call $many2)
    (call $once1)
    (call $many1)
    (call $once2)
  )

  ;; CHECK:      (func $once2
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once2)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once2
  ;; CHECK-NEXT:   (i32.const 2)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (call $many2)
  ;; CHECK-NEXT:  (call $once1)
  ;; CHECK-NEXT:  (call $many1)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (call $many2)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (call $many1)
  ;; CHECK-NEXT: )
  (func $once2
    (if
      (global.get $once2)
      (return)
    )
    (global.set $once2 (i32.const 2))
    (call $once2)
    (call $many2)
    (call $once1)
    (call $many1)
    (call $once2)
    (call $many2)
    (call $once1)
    (call $many1)
  )

  ;; CHECK:      (func $many2
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $many2)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $many1
  ;; CHECK-NEXT:   (i32.const 0)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (call $many1)
  ;; CHECK-NEXT:  (call $once2)
  ;; CHECK-NEXT:  (call $many2)
  ;; CHECK-NEXT:  (call $once1)
  ;; CHECK-NEXT:  (call $many1)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT:  (call $many2)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $many2
    (if
      (global.get $many2)
      (return)
    )
    (global.set $many1 (i32.const 0))
    (call $many1)
    (call $once2)
    (call $many2)
    (call $once1)
    (call $many1)
    (call $once2)
    (call $many2)
    (call $once1)
  )
)

;; Test for propagation of information about called functions: if A->B->C->D
;; and D calls some "once" functions, then A can infer that it's call to B does
;; so.
(module
  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (global $once (mut i32) (i32.const 0))
  (global $once (mut i32) (i32.const 0))

  ;; CHECK:      (func $once
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (global.get $once)
  ;; CHECK-NEXT:   (return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (global.set $once
  ;; CHECK-NEXT:   (i32.const 1)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $once
    (if
      (global.get $once)
      (return)
    )
    (global.set $once (i32.const 1))
  )

  ;; CHECK:      (func $A
  ;; CHECK-NEXT:  (call $B)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $A
    ;; We can infer that calling B calls C and then D, and D calls this "once"
    ;; function, so we can remove the call after it
    (call $B)
    (call $once)
  )

  ;; CHECK:      (func $B
  ;; CHECK-NEXT:  (call $C)
  ;; CHECK-NEXT: )
  (func $B
    (call $C)
  )

  ;; CHECK:      (func $C
  ;; CHECK-NEXT:  (call $D)
  ;; CHECK-NEXT: )
  (func $C
    (call $D)
  )

  ;; CHECK:      (func $D
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $D
    (call $once)
    (call $once)
  )

  ;; CHECK:      (func $bad-A
  ;; CHECK-NEXT:  (call $bad-B)
  ;; CHECK-NEXT:  (call $once)
  ;; CHECK-NEXT: )
  (func $bad-A
    ;; Call a function that does *not* do anything useful. We should not remove
    ;; the second call here.
    (call $bad-B)
    (call $once)
  )

  ;; CHECK:      (func $bad-B
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $bad-B
  )
)
