const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var buf: [4096]u8 = undefined;
    const uri = try std.Uri.parse("https://jbirk.de/~jona/aoc/input/2024/1");
    var request = try client.open(std.http.Method.GET, uri, .{ .server_header_buffer = &buf });
    defer request.deinit();
    _ = try request.send();
    _ = try request.finish();
    _ = try request.wait();

    const response_body = try request.reader().readAllAlloc(allocator, 4 * 1024 * 1024 * 1024);
    defer allocator.free(response_body);

    var n_lines: u32 = 0;
    for (response_body) |c| {
        if (c == '\n') {
            n_lines += 1;
        }
    }
    var lines = std.mem.splitScalar(u8, response_body, '\n');
    var as = try allocator.alloc(i32, n_lines);
    defer allocator.free(as);
    var bs = try allocator.alloc(i32, n_lines);
    defer allocator.free(bs);

    var i: u32 = 0;

    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        var numbers = std.mem.splitScalar(u8, line, ' ');
        as[i] = try std.fmt.parseInt(i32, numbers.next().?, 10);
        var b: []const u8 = "";
        while (b.len == 0) {
            b = numbers.next().?;
        }
        bs[i] = try std.fmt.parseInt(i32, b, 10);
        i += 1;
    }

    std.mem.sortUnstable(i32, as, {}, comptime std.sort.asc(i32));
    std.mem.sortUnstable(i32, bs, {}, comptime std.sort.asc(i32));

    var total_diff: u32 = 0;
    for (as, bs) |a, b| {
        total_diff += @abs(a - b);
    }
    std.debug.print("part1: {}\n", .{total_diff});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
