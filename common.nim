import ./cpsloop, cps, lockfreequeues, options
import std/[asyncdispatch, httpclient]

proc doSomeShit(s: string) {.cps:C.} =
  var client = newAsyncHttpClient()
  let resp = cwait client.getContent(s)
  if resp.failed():
    # fuck me in the TODO
    discard
  var v = resp.read()
  echo v

var iodispatcher = initIoDispatcher()
var workConsumer = iodispatcher.work.getConsumer()
var workProducer = iodispatcher.work.getProducer()
var c = whelp doSomeShit("http://google.com")
c.io = iodispatcher
discard workProducer.push(c)
var p = whelp doSomeShit("http://www.google.com/search?q=hello")
p.io = iodispatcher
discard workProducer.push(p)
import os
while true:
  let work = workConsumer.pop()
  if work.isNone:
    sleep(500)
    continue
  var cont = work.get()
  while cont.running():
    cont = trampoline cont