const std = @import("std");

// Cél:
// Ez csak az E<->C táblázat

// Ez a verzió még egyszerű.

const Entity = u32;
const NULL   = std.math.maxInt(usize);

pub fn Container(comptime T: type) type {
return struct {
    // 4 fő művelet: has, assign, remove, get
    // Ez a Entity <-> Component tároló.

    const Self = @This();
    
    sparse: std.ArrayList(usize),  // this[Entity] -> dense_index. 
    dense: std.ArrayList(T),       // Az igazi értékek itt tárolva. \ 
    lookup: std.ArrayList(Entity), // this[dense_index] -> Entity   / Párhuzamosak 
    
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .sparse = .empty,
            .dense  = .empty,
            .lookup = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.sparse.deinit(self.allocator);
        self.dense.deinit(self.allocator);
        self.lookup.deinit(self.allocator);
    }

    // Na és most az igazi logika!
    // Tudom hogy az LLVM IR brutálisan optimizál, de nem fogok csak 4 függvényt írni.
    // Így egyszerűbb rá gondolni.

    pub fn assign(self: *Self, entity: Entity, component: T) !void {
        // Dolga röviden: Az adott entitánshoz hozzárendelni a komponenset.
        // Hogyan?
        // Ha még nem létezik > Feltöltés
        // Ha NULL > Létrehozás
        // Ha már létezik sparse-ban > Beállítás
        
        // Ha még nincsen
        if (entity >= self.sparse.items.len) {
            // Feltöltés
            try self.sparse.appendNTimes(self.allocator, NULL, entity - self.sparse.items.len + 1);
        }

        if (self.sparse.items[entity] == NULL) {
            // Létrehozás
            self.sparse.items[entity] = self.dense.items.len;
            try self.dense.append(self.allocator, component);
            try self.lookup.append(self.allocator, entity);
        } else {
            // Beállítás
            self.dense.items[self.sparse.items[entity]] = component;
        }

        // Ja szerintem ennyi. 
    }

    pub fn has(self: *Self, entity: Entity) bool {
        // Dolga röviden: Van-e ilyen entitáns a táblázatban?
        // Ha Entitáns nagyobb mint sparse mérete > nincsen
        // ha sparse[Entitáns] NULL > nincsen
        // ha lookup[sparse[entity]] == entity -> visszalinkel

        if (entity >= self.sparse.items.len)                        return false;
        if (self.sparse.items[entity] == NULL)                      return false; // Ez lehet szükségtelen.
        if (self.lookup.items[self.sparse.items[entity]] == entity) return true;
        return false; // Zig nem hiszi el különben. Vagy lehet problémás a logikám. 
    }

    pub fn get(self: *Self, entity: Entity) *T {
        // FILOZÓFIAI DÖNTÉS!!! Legyen benne has check? ne. csak pánik.
        // Dolga röviden: Visszaadja a Entitánshoz tartozó komponenset.
        // Piszok egyszerű(nek tűnik)
        return &self.dense.items[self.sparse.items[entity]];
        // JAJJ! A SOK CRASH ÉS AKÁR UB AMIT EZ FOG OKOZNI! 
    }
    
    // Biztonságosabb mód! talán.
    pub fn has_get(self: *Self, entity: Entity) ?T {
        if (self.has(entity)) return self.get(entity)
        else return null;
    }

    pub fn remove(self: *Self, entity: Entity) !void {
        // Ez meg már komplikált! -- És szerintem ez se biztonságos.
        // Dolga röviden: Törölni az entitánst a táblázatból.
        // dense-ből swap és pop.
        // sparse-ban a DENSE utolsó elemét kicseréljük a törölendőre.
        
        // BIZTONSÁG!!!
        if (!self.has(entity)) return;
        
        if (self.dense.items.len > 1) {
            const last = self.lookup.getLast();
            _ = self.dense.swapRemove(self.sparse.items[entity]);
            std.mem.swap(usize, &self.sparse.items[last], &self.sparse.items[entity]);
        } else {
            _ = self.dense.pop(); // ha csak 1 van nincs szükség arra. 
        }
    }
    
};
}

// Na és az igazság pillanata. működőképes-e?
test "SparseSet container dolog" {

    var container = Container(u32).init(std.testing.allocator);
    defer container.deinit(); // Őszintén ezt elsőnek kihagytam és pánikoltam (mármint valóságban).

    try container.assign(0, 67);
    std.debug.print("{}", .{container.get(0)});
    try container.remove(0);
    try container.remove(0); // ha minden igaz meg vagyunk védve.
    
    try std.testing.expect(!container.has(67));

    // Na most durvább teszt!

    try container.assign(100000, 67); // Pagination nélkül ez fájhat.
    try std.testing.expect(!container.has(99999));
    try std.testing.expect(container.get(100000).* == @as(u32, 67));
    
    var i: u32 = 0;
    while ( i < 1000000) : (i += 1) {
        try container.assign(i, 42); // Egymillió!!!
    }

    i = 0;
    while ( i < 1000000) : (i += 1) {
        try container.remove(i);
    }

    // Ja. A többit majd runtime! 
}

const World = struct {
    // Fő célja az entitáns kezelés. 
    // És a táblázatok összefogása.
}; 
