import pkg/cps
import std/deques

type
  C = ref object of Continuation
  Result = ref object
    v: string

# Define work queue
var work: Deque[C]
work    = initDeque[C]()

proc schedule(c: C): C {.cpsMagic.} =
  echo "I'm going into the queue"
  work.addLast(c)
  return nil

# REVIEW https://github.com/disruptek/cps/issues/235
# I know I can do dynamic dispatch calls as can be seen
# in the dynamicdispatch folder if i separate the procs
# into separate modules, but the point of this test was
# to see if I could successfuly link the caller to the
# dynamic called child
proc dynamicContinuation(res: Result) {.cps:C.} =
  # Want to demonstrate that can use a dynamic
  # method as a go between to achieve dynamic
  # dispatch WHILE keeping the continuation chain
  schedule()  # Putting the continuation back into the queue
  res.v = "Dynamic"  # If we get a series of "I'm going to the deque"
                    # followed by Dynamic in stdout then we know it works


method dynamicBridge(c: C, res: Result): C {.base.} =
  var dynCon = whelp dynamicContinuation(res)
  dynCon.mom = c  # Hack to ensure child properly points to caller
  return dynCon

proc dynamicSchedule(c: C, res: Result): C {.cpsMagic.} =
  return dynamicBridge(c, res)
  # since dynbridge returns the dynamic called continuation
  # it will be the next leg

proc dynamicContTest() {.cps:C.} =
  var res = Result()
  res.v = "NotDynamic"
  dynamicSchedule(res)
  echo res.v

for i in 0..2:
  work.addLast(whelp dynamicContTest())

while work.len > 0:
  var c = work.popFirst()
  while c.running():
    c = trampoline c


## OUTPUT:
## I'm going into the queue
## I'm going into the queue
## I'm going into the queue
## Dynamic
## Dynamic
## Dynamic
##
## This series in the stdout indicates
## successful dynamic dispatch linking
## of the child to the parent

  