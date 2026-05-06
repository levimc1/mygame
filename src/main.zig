const std = @import("std");

pub fn main(init: std.process.Init) !void {
  
  std.debug.print("Hello, {s}!\n", .{"World"});

  const io = init.io; // egy io instance? 
  var stdout_buffer: [1024]u8 = undefined; // buffer valamiért neki, íráshoz?
  // ez ír?
  var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
  // akkor ez ollvas?
  var stdin_buffer: [1024]u8 = undefined; // buffer valamiért neki, íráshoz?
  var stdin_file_reader: std.Io.File.Reader = .init(.stdout(), io, &stdin_buffer);


  const stdout_writer = &stdout_file_writer.interface;
  const stdin_reader = &stdin_file_reader.interface;
  try stdout_writer.print("Mi a neved? > ", .{});
  try stdout_writer.flush();
  const name = try stdin_reader.takeDelimiterExclusive('\n');

  try stdout_writer.print("Szia {s}!", .{name});
  try stdout_writer.flush();

}
