## This loop should exist on a single thread
## The thread will take any IO operations and
## cycle them to see when they're finished to
## pass back to operation threads

import pkg/[lockfreequeues, cps, uuids]
import std/[options, hashes, sets, locks, asyncdispatch, deques]
export cps, lockfreequeues

type
  WaitToken = UUID      ## Unique tokens can be used
  Waiter = ref object   ## later to interact with the
    token: WaitToken    ## IoDispatcher and its job
    fut: Future[string] ## queue
    c: C
  ThreadArg = object
    io: IoDispatcher
  IoDispatcher* = ref object
    id: int                     # Thread ID of the IoDispatcher
    qc: Continuation            # TODO give some state for quitting related things
    queue: MupSic[32, 8, C]     # Async code to be run and sizzled
    waiters: HashSet[Waiter]    # Async jobs waiting to complete/fail
    complete: Deque[Waiter]     # Completed jobs waiting to be put to work
    waitlock: Lock              # REVIEW no need for this atm
    work*: MupMuc[64, 8, 8, C]  # Work queue to be run on non-io threads
    # TODO want to make it so
    # that each thread has a
    # set of continuations that
    # it concurrently runs to
    # complete. Once one of those
    # completes (or via magic)
    # it can acquire more thread jobs
    # from this work queue.
    # This way I don't have to keep hacking
    # away at a pretty costly pop() proc

  C* = ref object of Continuation
    ## Base continuation type that acts like a prison wallet
    ## and contains the IoDispatcher
    io*: IoDispatcher
    fut: Future[string] # Used internally when queuing it for works
    # STUB - Low Priority - want to make it so that I can shoot a few different
    # futures to await before I want computation to continue



var cpsLoop {.global.}: Thread[ThreadArg]
  ## Access to the thread which runs the IoDispatcher
  ## so that we can make joinThread calls if required

proc hash*(x: Waiter): Hash = x.token.hash()
proc `==`*(x,y: Waiter): bool = x.token.hash() == y.token.hash()

proc qc() {.cps:Continuation.} = ## gen continuation
  echo "quit called"
  discard

proc close*(iod: IoDispatcher) =  # Can call to finish the
  while iod.qc.running():         # iodispatcher loop
    iod.qc = trampoline iod.qc

proc pass*(cFrom,cTo: C): C =
  cTo.io = cFrom.io # Share the iodispatcher
  return cTo        # guys, come on.

proc getDispatchThread*(): Thread[ThreadArg] =  # Exposed api to access the
  return cpsLoop                                # cpsLoop global

proc register*(c: C): C {.cpsMagic.} =
  ## This is called before a async call is about
  ## to be made. It will transfer the continuation
  ## to the IoDispatcher.
  var prod = c.io.queue.getProducer()
  if not prod.push(c): echo "Failed to push baby on register"
  return nil

proc registerWaiter*(c: C, fut: Future[string]): C {.cpsMagic.} =
  ## This is called after a async call has been made
  ## with the future that is being awaited. This will
  ## create a Waiter which will be iterated over until
  ## it is completed. Once completed it will return to a
  ## non-ioThread queue
  var waiter = Waiter(token: genUUID(), fut: fut, c: c)
  c.fut = fut
  c.io.waiters.incl(waiter)
  return nil

proc getFuture*(c: C): Future[string] {.cpsVoodoo.} =
  ## Voodoo to access the future result
  return c.fut

template cwait*(body: untyped): untyped =
  ## Template which abstracts away
  ## all the details of handling the
  ## continuation with magic and voodoo
  ## when doing async calls.
  register()
  var fut = body
  registerWaiter(fut)
  getFuture()


proc ioThread(targ: ThreadArg) {.thread.} =
  ## Main IODispatch thread loop
  var iod = targ.io
  iod.id = getThreadId()  # Assign our id to IoD since we are the iodispatch thread
  var queueConsumer = iod.queue               #
  var workConsumer = iod.work.getConsumer()   # Cleaner access to our queues
  var workProducer = iod.work.getProducer()   #
  while iod.qc.running():
    # By completing the iod.qc continuation we can
    # effectively stop this thread loop.
    # If we add some state to the continuation we can even
    # do more.
    var newjob = queueConsumer.pop()    ## Check first for any operations that
    if newjob.isSome():                 ## are queued for async IO. If there is
      echo "num"
      var njc = newjob.get()            ## one then we will trampoline it until
      while njc.running():              ## it hits the registerWaiter() and 
        njc = trampoline njc            ## pushes itself to the waiting queue
    
    if hasPendingOperations():          ## Check if we have a pending operation
      poll()                            ## Poll the async dispatcher
    
    var completed: seq[Waiter]
    for i in iod.waiters:
      if i.fut.finished():
        completed.add(i)

    for i in 0..<completed.len():
      var job = completed.pop()
      iod.waiters.excl(job)
      job.c.fut = job.fut
      if not workProducer.push(job.c):
        echo "failed to push work boi"

proc initIoDispatcher*(): IoDispatcher =
  ## Initialises the IoDispatcher object
  ## and starts the IoDispatcher thread.
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