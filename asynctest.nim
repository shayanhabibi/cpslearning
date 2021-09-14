import asyncdispatch, httpclient, times

var time {.global.} = epochTime()

proc doSomeShit(s: string): Future[string] {.async.} =
  var client = newAsyncHttpClient()
  let resp = await client.getContent(s)
  var v = resp
  echo epochTime() - time
  return v

var waiters: seq[Future[string]]

for i in 0..10:
  var c = doSomeShit("http://google.com")
  var p = doSomeShit("http://www.google.com/search?q=hello")
  waiters.add(c)
  waiters.add(p)

runForever()