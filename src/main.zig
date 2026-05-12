const std = @import("std");

pub fn main(init: std.process.Init) !void {
    std.debug.print("Hello, {s}!\n", .{"World"});
    
    // -- SETUP --
    // Bufferes és threadelt írás és olvasás 

    // 1 KB Üzenet / flush. Ha többet használsz: hiba.
    var stdout_buffer: [1028]u8 = undefined;
    var stdin_buffer:  [1024]u8 = undefined;
    //var stderr_buffer: [1024]u8 = undefined;

    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    var stdin_reader  = std.Io.File.stdin().reader(init.io, &stdin_buffer);
    //var stderr_writer = std.Io.File.stderr().writer(init.io, stderr_buffer);

    const stdout = &stdout_writer.interface;
    const stdin  = &stdin_reader.interface;
    //const stderr = &stderr_writer.interface;


    // -- APP --
    try stdout.writeAll("Hogy hívnak? > ");
    try stdout.flush();

    const name = try stdin.takeDelimiterExclusive('\n');
    try stdout.print("Szia {s}!\n", .{name});
    try stdout.flush();
    

}
