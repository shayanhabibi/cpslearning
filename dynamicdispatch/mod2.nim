import ./common, ./mod1

proc sayYourName*(c: O): string {.cpsVoodoo.} =
  return "I am O"
proc doThis*(o: Obj1) {.cps:O.} =
  echo "Obj1, O"
  echo sayYourName()
method getCont*(o: Obj1): C =
  return whelp doThis(o)
