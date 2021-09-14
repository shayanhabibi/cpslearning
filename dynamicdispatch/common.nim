import cps
export cps

type
  C* = ref object of Continuation
    o*: Obj
  O* = ref object of C
  P* = ref object of C
  Obj* = ref object of RootObj
  Obj1* = ref object of Obj
  Obj2* = ref object of Obj