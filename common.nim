import ./cpsloop, cps, lockfreequeues, options
import std/[asyncdispatch, httpclient]
import times

var time {.global.}: float
proc doSomeShit(s: string) {.cps:C.} =
  var client = newAsyncHttpClient()
  let resp = cwait client.getContent(s)
  if resp.failed():
    # fuck me in the TODO
    discard
  var v = resp.read()
  echo epochTime() - time

var iodispatcher = initIoDispatcher()
var workConsumer = iodispatcher.work.getConsumer()
var workProducer = iodispatcher.work.getProducer()

time = epochTime()
for i in 0..6:
  var c = whelp doSomeShit("http://google.com")
  var p = whelp doSomeShit("http://www.google.com/search?q=hello")
  c.io = iodispatcher
  p.io = iodispatcher
  discard workProducer.push(c)
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