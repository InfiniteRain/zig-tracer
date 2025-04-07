const std = @import("std");
const tracer = @import("./mod.zig");
const alloc = std.heap.c_allocator;
const log = std.log.scoped(.racer);
const root = @import("root");

threadlocal var path: []const u8 = undefined;
threadlocal var file: std.fs.File = undefined;
threadlocal var buffered_writer: std.io.BufferedWriter(4096, std.fs.File.Writer) = undefined;

pub fn init() !void {}

pub fn deinit() void {}

pub fn init_thread(dir: std.fs.Dir) !void {
    path = try std.fmt.allocPrint(alloc, "trace.chrome.json", .{});
    file = try dir.createFile(path, .{});
    buffered_writer = std.io.bufferedWriter(file.writer());

    try buffered_writer.writer().writeAll("[\n");
}

pub fn deinit_thread() void {
    defer alloc.free(path);
    defer file.close();

    buffered_writer.writer().writeAll("]\n") catch {};
    buffered_writer.flush() catch {};
    log.debug("{s}", .{path});
}

pub inline fn trace_begin(ctx: tracer.Ctx, comptime ifmt: []const u8, iargs: anytype) void {
    buffered_writer.writer().print(
        \\{{"cat":"function", "name":"{s}:{d}:{d} ({s})
    ++ ifmt ++
        \\", "ph": "B", "pid": 0, "tid": 0, "ts": {d}}},
        \\
    ,
        .{
            ctx.src.file,
            ctx.src.line,
            ctx.src.column,
            ctx.src.fn_name,
        } ++ iargs ++ .{
            std.time.microTimestamp(),
        },
    ) catch {};
}

pub inline fn trace_end(ctx: tracer.Ctx) void {
    _ = ctx;
    buffered_writer.writer().print(
        \\{{"cat":"function", "ph": "E", "pid": 0, "tid": 0, "ts": {d}}},
        \\
    ,
        .{
            std.time.microTimestamp(),
        },
    ) catch {};
}
