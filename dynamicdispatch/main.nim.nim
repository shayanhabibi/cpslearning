
import ./common, ./mod1, ./mod2, ./mod3

proc doMagic(c: C): C {.cpsMagic.} =
  return c.o.getCont

proc letsGo() {.cps:C.} =
  doMagic()
  echo "i shouldnt get here IIRC"

var o = Obj2()
var c = whelp letsGo()
c.o = o
while c.running():
  c = trampoline c