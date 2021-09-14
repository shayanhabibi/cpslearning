## Further testing mixing async with cps to see if async can be sped up using
## cps for normal usage
## 
## This actually seems to perform faster with an abstract test methodology
## compared to just using async/await on its own. However it is variable,
## I still prefer the semantics of using CPS to await

import cps, asyncdispatch, httpclient, deques, times, os

var time {.global.} = epochTime()

type
  Work = ref object
    queue: Deque[C]
  C* = ref object of Continuation
    work: Work
    

proc pass(cFrom,cTo: C): C =
  cTo.work = cFrom.work
  return cTo

proc register(c: C): C {.cpsMagic.} =
  c.work.queue.addLast(c)
  return nil
proc register(c: C, fut: Future[string]): C {.cpsMagic.} =
  if fut.finished(): return c
  c.work.queue.addLast(c)
  return nil

proc push(c: C, fut: Future[string]): C {.cpsMagic.} =
  if fut.finished(): return c
  # fut.callBack = proc() = c.work.queue.addFirst(c)    # This slows down perf significantly but has the advantage of prioritizing the finished continuations
  # fut.callBack = proc() =
  #   {.cast(gcsafe).}: discard c.fn(c)
  c.work.queue.addLast(c)
  return nil

template cwait(body: untyped): untyped =
  var fut = body
  push(fut)
  while not fut.finished():
    if hasPendingOperations():
      poll()
    register(fut)
  fut

proc doSomeShit(s: string) {.cps:C.} =
  var client = newAsyncHttpClient()
  var resp = cwait client.getContent(s)
  var v = resp.read()
  echo epochTime() - time

proc push(w: Work, c: C) =
  c.work = w
  w.queue.addLast(c)

var work = Work()
work.queue = initDeque[C]()
for i in 0..10:
  work.push whelp doSomeShit("http://google.com")
  work.push whelp doSomeShit("http://www.google.com/search?q=hello")

while work.queue.len > 0:
  var j = work.queue.popFirst()
  while j.running():
    j = trampoline j