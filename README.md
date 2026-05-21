# LEGENDARY ENGINE
Veziózás: Kiadott verzió.szubverzió.ötlet

Egyszerűnek és gyorsnak kell lennie.
Egyszerű mint a minecraft Skriptelés, kivéve hogy itt te csinálod azt az 
"alap"-ot amire írod a Skripteket! 

## V0.0.2
 - Entity <-> Component táblázat -> ecs.zig
 - Systemek
 - Listenerek
 - Tick alapú futás
 - Modul design
 - builtin modulok

 **Idegen fogalmak ebben**
 Tick alapú futtatás: Flag alapján dönt melyik System/Listener fut. (State) (FSM)
 builtin modulok: Ebben a verzióban csak Allocator, Window, Renderer, Input.
 Modul: Egy "rész" a pipeline-ban. Csak egy gépezet ami az adatból játékot csinál. 
        És azon a játékon futnak a Skriptjeid ahogy előbb említettem!
        Maga az adat amin operálnak ezek a motortól vagy a builtin-ektől származnak.

**Mindenből csak a legegyszerűbb formában! ez egy fajta prototípus jelenleg**
