;; NOTE: Assertions have been generated by update_lit_checks.py --all-items and should not be edited.
;; RUN: foreach %s %t wasm-opt -all --possible-types -S -o - | filecheck %s

;; --possible-types does a whole-program analysis that can find opportunities
;; that other passes miss, like the following.
(module
  ;; CHECK:      (type $none_=>_i32 (func (result i32)))

  ;; CHECK:      (type $i32_=>_none (func (param i32)))

  ;; CHECK:      (type $i32_=>_i32 (func (param i32) (result i32)))

  ;; CHECK:      (type $none_=>_none (func))

  ;; CHECK:      (func $foo (result i32)
  ;; CHECK-NEXT:  (i32.const 1)
  ;; CHECK-NEXT: )
  (func $foo (result i32)
    (i32.const 1)
  )

  ;; CHECK:      (func $bar (param $x i32)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result i32)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (select
  ;; CHECK-NEXT:      (block (result i32)
  ;; CHECK-NEXT:       (drop
  ;; CHECK-NEXT:        (call $foo)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:       (i32.const 1)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (i32.const 1)
  ;; CHECK-NEXT:      (local.get $x)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $bar (param $x i32)
    ;; Both arms of the select have identical values, 1. Inlining +
    ;; OptimizeInstructions could of course discover that in this case, but
    ;; possible-types can do so even without inlining.
    (drop
      (select
        (call $foo)
        (i32.const 1)
        (local.get $x)
      )
    )
  )

  ;; CHECK:      (func $baz (param $x i32)
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (select
  ;; CHECK-NEXT:    (block (result i32)
  ;; CHECK-NEXT:     (drop
  ;; CHECK-NEXT:      (call $foo)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (i32.const 1)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (i32.eqz
  ;; CHECK-NEXT:     (i32.eqz
  ;; CHECK-NEXT:      (i32.const 1)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.get $x)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $baz (param $x i32)
    (drop
      (select
        (call $foo)
        ;; As above, but replace 1 with eqz(eqz(1)).This pass assumes any eqz
        ;; etc is a new value, and so here we do not optimize.
        (i32.eqz
          (i32.eqz
            (i32.const 1)
          )
        )
        (local.get $x)
      )
    )
  )

  ;; CHECK:      (func $return (result i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.const 0)
  ;; CHECK-NEXT:   (return
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (i32.const 2)
  ;; CHECK-NEXT: )
  (func $return (result i32)
    ;; Return one result in a return and flow another out.
    (if
      (i32.const 0)
      (return
        (i32.const 1)
      )
    )
    (i32.const 2)
  )

  ;; CHECK:      (func $call-return
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (call $return)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $call-return
    ;; The called function has two possible return values, so we cannot optimize
    ;; anything here.
    (drop
      (call $return)
    )
  )

  ;; CHECK:      (func $locals-no (param $param i32) (result i32)
  ;; CHECK-NEXT:  (local $x i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (local.get $param)
  ;; CHECK-NEXT:   (local.set $x
  ;; CHECK-NEXT:    (i32.const 1)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (local.get $x)
  ;; CHECK-NEXT: )
  (func $locals-no (param $param i32) (result i32)
    (local $x i32)
    (if
      (local.get $param)
      (local.set $x
        (i32.const 1)
      )
    )
    ;; $x has two possible values, the default 0 and 1, so we cannot optimize
    ;; anything here.
    (local.get $x)
  )

  ;; CHECK:      (func $locals-yes (param $param i32) (result i32)
  ;; CHECK-NEXT:  (local $x i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (local.get $param)
  ;; CHECK-NEXT:   (local.set $x
  ;; CHECK-NEXT:    (i32.const 0)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (i32.const 0)
  ;; CHECK-NEXT: )
  (func $locals-yes (param $param i32) (result i32)
    (local $x i32)
    (if
      (local.get $param)
      (local.set $x
        ;; As above, but now we set 0 here. We can optimize in this case.
        (i32.const 0)
      )
    )
    (local.get $x)
  )
)

;; TODO: test "cycles" with various things involved, another thing other
;;       passes fail at