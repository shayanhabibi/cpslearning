import ./common

proc sayYourName*(c: C): string {.cpsVoodoo.} =
  return "I am C"
proc doThis*(o: Obj) {.cps:C.} =
  echo "Obj, C"
  echo sayYourName()
method getCont*(o: Obj): C {.base.} =
  return whelp doThis(o)
