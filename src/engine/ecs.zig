const std = @import("std");

// Cél:
// Ez csak az E<->C táblázat

// Ez a verzió még egyszerű.

const Entity = struct {id: 32, gen: u32};
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
        // ha lookup[sparse[entity]] == entity -> visszalinkel

        if (self.lookup.items[self.sparse.items[entity]] == entity) return true;
        return false; // Zig nem hiszi el különben. Vagy lehet problémás a logikám. 
    }

    pub fn get(self: *Self, entity: Entity) ?*T {
        // Dolga röviden: Visszaadja a Entitánshoz tartozó komponenset.
        // Piszok egyszerű(nek tűnik)
        if (!self.has(entity)) return null; 
        return &self.dense.items[self.sparse.items[entity]];
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

    // A fentieknek a neve CRUD. Most jön minden más ami kell egy ECS-hez. 
    
    pub const Iterator = struct {
        items: []T,
        index: usize = 0,

        pub fn next(self: *Iterator) ?*T {
            if (self.index >= self.items.len) return null;
            defer self.index += 1;
            return &self.items[self.index];
        }
    };
    
    // VISSZAFELÉ JÖN RÁ ÚRISTEN
    pub const EntityIterator = struct {
        items: []Entity, // ez lookup!
        index: usize = 0,

        pub fn next(self: *EntityIterator) ?*Entity {
            if (self.index >= self.items.len) return null;
            defer self.index += 1;
            return &self.items[self.index];
        }
    };

    pub fn iterator(self: *Self) Iterator {
        return Iterator{ .items = self.dense.items, };
    }

    pub fn entities(self: *Self) Iterator {
        return Iterator{ .items = self.lookup.items, };
    }

    pub fn clear(self: *Self) !void {
        self.sparse.clearAndFree(self.allocator);
        self.dense.clearAndFree(self.allocator);
        self.lookup.clearAndFree(self.allocator);
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

// Ez lopott mert nem vagyok zig compiler géniusz
fn typeId(comptime T: type) usize {
    const S = struct {var id: u8 = 0; };
    _ = T;
    return @intFromPtr(&S.id);
}

const WorldError = error { DeadEntity };

const World = struct {
    // Fő célja az entitáns kezelés. 
    // És a táblázatok összefogása.
    
    const Self = @This();
    
    // Mivel pld removeEntity-nél nem tudjuk mi a T.
    const ContainerWrapper = struct {
        ptr: *anyopaque,
        remove_fn: *const fn(*anyopaque, Entity) void,
        deinit_fn: *const fn(*anyopaque) void,
        bit: u7,
    };

    next_free:   Entity = 0,
    graveyard:   std.ArrayList(Entity),
    alive:       std.DynamicBitSet, 
    generations: std.ArrayList(u32), 
    containers:  std.AutoHashMap(usize, ContainerWrapper),
    allocator:   std.mem.Allocator,
    masks:       std.ArrayList(u128), // Fáj.
    next_bit:    u7 = 0, // EZ ANNÁL IS JOBBAN, u7, úristen ments meg.
                         // Amúgy ez hogy melyik Container-nek mi a bitje.

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .allocator = allocator,
            .graveyard = .empty,
            .alive = .initEmpty(allocator, 1024),
            .generations = .empty,
            .containers = .init(allocator),
            .masks = .empty,
        };
    } 

    pub fn deinit(self: *Self) !void {
        var it = self.containers.valueIterator();
        while (it.next()) |storage| {
            storage.deinit_fn(storage.ptr);
        }

        self.graveyard.deinit(self.allocator);
        self.alive.deinit(self.allocator);
        self.generations.deinit(self.allocator);
        self.containers.deinit(self.allocator);
        self.masks.deinit(self.allocator);
    }

    // Most a műveletek.
    
    pub fn createEntity(self: *Self) !Entity {
        if (self.graveyard.items.len > 0) {
            // Ha már egyszer az entitánst létre lett hozva. 
            const id = self.graveyard.pop(); // A legutolsó
            return Entity{.id = id, .gen = self.generations[id]}; // destroy növeli

        } else {
            // Új entitánst kell létrehozni.
            const id = self.next_free;
            self.next_free += 1;
            try self.generations.append(self.allocator, 0); // Elsőnek születik meg.
            return Entity{.id = id, .gen = 0};

            // MASK logika, kövessük a konvenciót és destroy törli.
            try self.masks.append(self.allocator, 0);
        }

    }

    pub fn destroyEntity(self: *Self, entity: Entity) !void {

        if (!self.isAlive(entity)) return error.DeadEntity;

        self.generations.items[entity.id] += 1;
        self.graveyard.append(self.allocator, entity);

        var it = self.containers.valueIterator();
        while (it.next()) |storage| {
            storage.remove_fn(storage.ptr, entity.id);
        }

        // MASK logika, kövessük a konvenciót és destroy törli.
        try self.masks.insert(entity.id, self.allocator, 0);
    }

    // Komponens kezelés

    // I. Csak az alapjai
    
    pub fn registerComponent(self: *Self, comptime T: type) void {
        const id = typeId(T);
        // Már van ilyen
        if (self.containers.contains(id)) return;
        
        // Heap-re kell allokálni mert pointer
        const container = try self.allocator.create(Container(T));
        container.* = .init(self.allocator);

        try self.containers.put(id, ContainerWrapper{
            .ptr = @ptrCast(container),
            .remove_fn = struct { // Undorító, de csak így lehetséges.
                fn remove(ptr: *anyopaque, entity: Entity) void {
                    const c: *Container(T) = @ptrCast(@alignCast(ptr));
                    c.remove(entity); // c mert rövid, és az LSP szerint foglalt vagy valami.
                }
            }.remove, // és mégegy, így értve már annyira nem undorító :)
            .deinit_fn = struct {
                fn deinit(ptr: *anyopaque) void { 
                    const c: *Container(T) = @ptrCast(@alignCast(ptr));
                    c.deinit();
                }
            }.deinit,
            .bit = self.next_bit,
        });

        self.next_bit += 1;
    }

    pub fn getContainer(self: *Self, comptime T: type) ?*T {
        const id = typeId(T);
        //if (!self.containers.contains(id)) return null; //Felesleges duplicate :/

        const container = self.containers.get(id) orelse return null;
        return @ptrCast(@alignCast(container.ptr));
    }

    // II. Felhasználói műveletek.
    // Erre vártam!

    pub fn assignComponent(self: *Self, comptime T: type, entity: Entity, component: T) !void {

        if (!self.isAlive(entity)) return error.DeadEntity;
        
        const maybe_container = self.getContainer(T);
        var container : *Container(T) = maybe_container orelse self.registerComponent(T);
        
        try container.assign(entity, component);

        // MASK Logika, köszi chatgpt
        self.masks.items[entity.id] |= @as(u64, 1) << container.bit;
    }

    pub fn removeComponent(self: *Self, comptime T: type, entity: Entity) !void {

        if (!self.isAlive(entity)) return error.DeadEntity;
        
        const maybe_container = self.getContainer(T);
        var container : *Container(T) = maybe_container orelse self.registerComponent(T);
        
        try container.remove(entity);

        // MASK Logika, köszi chatgpt
        self.masks.items[entity.id] &= ~@as(u64, 1) << container.bit;
    }
 
    pub fn hasComponent(self: *Self, comptime T: type, entity: Entity) bool {

        if (!self.isAlive(entity)) return false;
        
        const maybe_container = self.getContainer(T);
        var container : *Container(T) = maybe_container orelse self.registerComponent(T);
        
        return container.has(entity);
    }

    pub fn getComponent(self: *Self, comptime T: type, entity: Entity) ?*T {

        if (!self.isAlive(entity)) return null;
        
        const maybe_container = self.getContainer(T);
        var container : *Container(T) = maybe_container orelse self.registerComponent(T);
        
        return container.get(entity);
    }

    // Ja az egyszerű volt
    // Most meg nagy eséllyel kell majd valami bitmask.
    // QUERY!! úristen, eddig még sose ért el egy ECS motorom.
    
    // Az Iterator Query struct (menőn érzem magam ezt leírni)
    fn Query(comptime types: anytype) type {
    return struct {
        //const Self = @This(); // szerintem van fent is egy Self és nem jó (LSP hiszti)

        world: *World,
        mask: u128,
        index: u34 = 0,
        
        // Ki gondolta volna hogy ilyen nehéz lehet ez..
        const Tuple = blk: {
            var fields: [types.len]type = undefined;
            for (types, 0..) |T, i| fields[i] = *T;
            break :blk std.meta.Tuple(&fields);
        };

        pub fn next(self: *@This()) ?Tuple {
            while (self.index < self.world.masks.items.len) { // index nő!
                const id = self.index;
                self.index += 1; // itt!!
                if (self.world.masks.items[id] & self.mask != self.mask) continue; // Ne kérdezz.
                const entity = Entity{.id = id, .gen = self.world.generations.items[id],};
                var result: Tuple = undefined;

                inline for (types, 0..) |T, i| {
                    result[i] = self.world.getContainer(T).?.get(entity).?;
                }
                
                return result;
            }
            return null;
        }
    };
    }

    // Függvénnyel hozzuk létre.
    fn query(self: *Self, comptime types: anytype) Query(types) {
        var mask: u128 = 0;
        inline for (types) |T| {
            const container = self.containers.get(typeId(T));
            mask |= @as(u128, 1) << container.bit;
        }
        return Query(types){.world = self, .mask = mask,};
    }
    
    // Ja de még kellenek isAlive()-ok.
    pub fn isAlive(self: *Self, entity: Entity) bool {
        if (entity.id >= self.generations.items.len) return false;
        if (self.generations.items[entity.id] == entity.gen) return true;
        return false;
    }
}; 
