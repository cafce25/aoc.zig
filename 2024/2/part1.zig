const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var reports = Reports(i32).init(allocator);
    defer reports.deinit();

    {
        const response_body = try get_input(allocator, 2);
        defer allocator.free(response_body);

        try reports.parse(response_body);
    }

    var safe_count: u32 = 0;
    for (reports.reports.items) |report| {
        var safely_decreasing = true;
        for (report.items[0 .. report.items.len - 1], report.items[1..]) |last_item, item| {
            const diff = last_item - item;
            if (diff < 1 or diff > 3) safely_decreasing = false;
        }

        if (safely_decreasing) {
            safe_count += 1;
            continue;
        }

        var safely_increasing = true;
        for (report.items[0 .. report.items.len - 1], report.items[1..]) |last_item, item| {
            const diff = item - last_item;
            if (diff < 1 or diff > 3) safely_increasing = false;
        }

        if (safely_increasing) {
            safe_count += 1;
            continue;
        }
    }

    std.debug.print("part1: {}\n", .{safe_count});
}

fn get_input(allocator: Allocator, day: u8) ![]u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var buf: [4096]u8 = undefined;

    // const uri_buffer_size = "https://jbirk.de/~jona/aoc/input/2024/{}".len;
    // const uri_buffer: [uri_buffer_size]u8 = undefined;
    const uri_string = try std.fmt.bufPrint(&buf, "https://jbirk.de/~jona/aoc/input/2024/{}", .{day});

    // const uri_string = std.fmt.allocPrint(allocator, "https://jbirk.de/~jona/aoc/input/2024/{}", .{day});

    const uri = try std.Uri.parse(uri_string);
    var request = try client.open(std.http.Method.GET, uri, .{ .server_header_buffer = &buf });
    defer request.deinit();
    _ = try request.send();
    _ = try request.finish();
    _ = try request.wait();

    var response_body = try request.reader().readAllAlloc(allocator, 4 * 1024 * 1024 * 1024);
    const trimmed = std.mem.trimRight(u8, response_body, " \n\r").len;
    if (allocator.resize(response_body, trimmed)) {
        response_body.len = trimmed;
        return response_body;
    } else {
        return try allocator.realloc(response_body, trimmed);
    }
}

fn Reports(comptime T: type) type {
    return struct {
        const Self = @This();
        reports: std.ArrayList(std.ArrayList(T)),
        allocator: Allocator,

        fn init(allocator: Allocator) Self {
            return Self{
                .reports = std.ArrayList(std.ArrayList(T)).init(allocator),
                .allocator = allocator,
            };
        }

        fn deinit(self: Self) void {
            for (self.reports.items) |report| {
                report.deinit();
            }
            self.reports.deinit();
        }

        fn parse(self: *Self, response_body: []u8) !void {
            var lines_iter = std.mem.splitScalar(u8, response_body, '\n');

            while (lines_iter.next()) |line| {
                var level_iter = std.mem.splitScalar(u8, line, ' ');
                var levels = std.ArrayList(T).init(self.allocator);

                while (level_iter.next()) |level| {
                    try levels.append(try std.fmt.parseInt(T, level, 10));
                }
                try self.reports.append(levels);
            }
        }
    };
}
