## This loop should exist on a single thread
## The thread will take any IO operations and
## cycle them to see when they're finished to
## pass back to operation threads

import lockfreequeues, cps, uuids, sets, locks, asyncdispatch, deques
import options
type
  WaitToken = UUID
  Waiter = ref object
    token: WaitToken
    fut: Future[string]
    c: C
  ThreadArg = object
    io: IoDispatcher
  IoDispatcher* = ref object
    id: int
    qc: Continuation
    queue: MupSic[32, 8, C]
    waiters: HashSet[Waiter]
    complete: Deque[Waiter]
    waitlock: Lock
    work*: MupMuc[64, 8, 8, C]

  C* = ref object of Continuation
    io*: IoDispatcher
    fut: Future[string]

import hashes

var cpsLoop* {.global.}: Thread[ThreadArg]

proc hash*(x: Waiter): Hash = x.token.hash()
proc `==`*(x,y: Waiter): bool = x.token.hash() == y.token.hash()

proc qc() {.cps:Continuation.} =
  echo "quit called"
  discard

proc close*(iod: IoDispatcher) =
  while iod.qc.running():
    discard trampoline iod.qc

proc pass*(cFrom,cTo: C): C =
  cTo.io = cFrom.io
  return cTo

proc getDispatchThread*(): Thread[ThreadArg] =
  return cpsLoop

proc register*(c: C): C {.cpsMagic.} =
  var prod = c.io.queue.getProducer()
  if not prod.push(c): echo "Failed to push baby on register"
  return nil

proc registerWaiter*(c: C, fut: Future[string]): C {.cpsMagic.} =
  var waiter = Waiter(token: genUUID(), fut: fut, c: c)
  c.fut = fut
  c.io.waiters.incl(waiter)
  return nil

proc getFuture*(c: C): Future[string] {.cpsVoodoo.} =
  return c.fut

template cwait*(body: untyped): untyped =
  register()
  var fut = body
  registerWaiter(fut)
  getFuture()


proc ioThread(targ: ThreadArg) {.thread.} =
  var iod = targ.io
  echo "yo"
  iod.id = getThreadId()
  var queueConsumer = iod.queue
  var workConsumer = iod.work.getConsumer()
  var workProducer = iod.work.getProducer()
  while iod.qc.running():
    var newjob = queueConsumer.pop()
    if newjob.isSome():
      var njc = newjob.get()
      while njc.running():
        njc = trampoline njc
    
    if hasPendingOperations():
      poll()
    
    var completed: seq[Waiter]
    for i in iod.waiters:
      if i.fut.finished():
        completed.add(i)
    for i in 0..<completed.len():
      var job = completed.pop()
      iod.waiters.excl(job)
      job.c.fut = job.fut
      if not workProducer.push(job.c): echo "failed to push work boi"

proc initIoDispatcher*(): IoDispatcher =
  var waiters = initHashSet[Waiter]()
  var complete = initDeque[Waiter]()

  var qcont = whelp qc()
  assert qcont.running()

  
  var res = IoDispatcher()
  res.qc = qcont
  res.queue = initMupsic[32, 8, C]()
  res.waiters = initHashSet[Waiter]()
  res.complete = initDeque[Waiter]()
  initLock(res.waitLock)
  res.work = initMupmuc[64, 8, 8, C]()
  var targ = ThreadArg(io: res)
  createThread(cpsLoop, ioThread, targ)
  return res