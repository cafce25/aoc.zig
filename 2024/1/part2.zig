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

    {
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
    }

    std.mem.sortUnstable(i32, as, {}, comptime std.sort.asc(i32));
    std.mem.sortUnstable(i32, bs, {}, comptime std.sort.asc(i32));

    var total_similarity: u32 = 0;
    var i: u32 = 0;
    var j: u32 = 0;

    while (i < as.len and j < bs.len) {
        if (as[i] < bs[j]) {
            i += 1;
            continue;
        } else if (as[i] > bs[j]) {
            j += 1;
            continue;
        }
        const a = as[i];
        const first_i = i;
        const b = bs[j];
        const first_j = j;
        while (i + 1 < as.len and as[i + 1] == a) {
            i += 1;
        }
        while (j + 1 < bs.len and bs[j + 1] == b) {
            j += 1;
        }
        total_similarity += @as(u32, @bitCast(a)) * (i - first_i + 1) * (j - first_j + 1);
        i += 1;
        j += 1;
    }

    std.debug.print("part2: {}\n", .{total_similarity});
}
