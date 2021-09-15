# O. Giersch and J. Nolte, "Fast and Portable Concurrent FIFO Queues With Deterministic Memory Reclamation," in IEEE Transactions on Parallel and Distributed Systems, vol. 33, no. 3, pp. 604-616, 1 March 2022, doi: 10.1109/TPDS.2021.3097901.

import pkg/cps
import std/atomics

const
  RESUME = 0b001
  WRITER = 0b010
  READER = 0b100
  N      = 1024

type
  C = ref object of Continuation

  Node = ptr object
    slots: array[0..N, Atomic[uint]]    # these will be pointers to Continuations which
    next: Node                          # are kept safe by either being in a hash set bec
    ctrl: ControlBlock                  # -ause im a noob or by using GC_ref/unref or something fuck

  Tag = tuple
    cptr: Node
    idx: uint16

  CpsQueue = object
    head: Atomic[uint] 
    tail: Atomic[uint]
    currTail: C
  
  ControlBlock = object
    headMask: Atomic[(uint16, uint16)]
    tailMask: Atomic[(uint16, uint16)]
    reclaim: Atomic[uint8]

  AdvTail = enum
    AdvAndInserted, AdvOnly

proc enqueue(queue: var CpsQueue, el: C) =
  while true:
    var t: Node
    var i: uint16
    (t, i) = cast[ptr Tag](queue.tail.fetchAdd(1))[]
    if i < N:
      GC_ref(el)
      var w = (cast[uint](el) or WRITER)
      let prev = t[].slots[i].fetchAdd(w)
      if prev <= RESUME: return
      if prev == (READER or RESUME):
        discard t[].slots[i-1].compareExchange(w, prev) #what do i do if this fucking fails lol
      continue
    else:
      case AdvTail(cast[uint](el) and cast[uint](t))
      of AdvAndInserted: return
      of AdvOnly: continue