import ./common, ./mod1, ./mod2

proc sayYourName(c: P): string {.cpsVoodoo.} =
  return "I am P"
proc doThis(o: Obj2) {.cps:P.} =
  echo "Obj2, P"
  echo sayYourName()
method getCont(o: Obj2): C =
  return whelp doThis(o)
