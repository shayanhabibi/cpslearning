# CPSLearning

Good fun. I like that I can incorporate await/async pretty easily. It's actually better using CPS (?even in performance?) because I find the semantics so much easier to reason about.

I've tested the possibility of using callbacks in cpsmagic to put work to the front of the queue which works, but it's slowed down by the overhead.

I am definitely committing to refactoring Pishtaq and Parthian to use CPS. Painful :(, on the plus side this means I get to use orc/arc, but I was really hoping to use libp2p which isn't compatible with orc/arc.

I'm sure it is better if I could make all the net async handled by cps but I'm just not that knowledgable.