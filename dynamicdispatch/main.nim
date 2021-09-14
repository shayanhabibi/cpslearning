
import ./common, ./mod1, ./mod2, ./mod3

proc doMagic(c: C): C {.cpsMagic.} =
  return c.o.getCont

proc letsGo() {.cps:C.} =
  doMagic()
  echo "i shouldnt get here IIRC"

var o: Obj = Obj2()
var c = whelp letsGo()
c.o = o
while c.running():
  c = trampoline c

# Output = Obj2, P; I am P

o = Obj1()
c = whelp letsGo()
c.o = o
while c.running():
  c = trampoline c

# Output = Obj1, O; I am O

o = Obj()
c = whelp letsGo()
c.o = o
while c.running():
  c = trampoline c

# Output = Obj, C; I am C