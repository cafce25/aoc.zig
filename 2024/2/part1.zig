const std = @import("std");
const Allocator = std.mem.Allocator;
const get_input = @import("util").get_input;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var reports = Reports(i32).init(allocator);
    defer reports.deinit();

    {
        const response_body = try get_input(allocator, 2024, 2);
        defer allocator.free(response_body);

        try reports.parse(response_body);
    }

    var safe_count: u32 = 0;
    for (reports.reports.items) |report| {
        if (is_safely_decreasing(report.items) or is_safely_increasing(report.items)) {
            safe_count += 1;
        }
    }

    std.debug.print("part1: {}\n", .{safe_count});
}

fn is_safely_decreasing(items: []i32) bool {
    var safely_decreasing = true;
    for (items[0 .. items.len - 1], items[1..]) |last_item, item| {
        const diff = last_item - item;
        if (diff < 1 or diff > 3) safely_decreasing = false;
    }
    return safely_decreasing;
}

fn is_safely_increasing(items: []i32) bool {
    var safely_increasing = true;
    for (items[0 .. items.len - 1], items[1..]) |last_item, item| {
        const diff = item - last_item;
        if (diff < 1 or diff > 3) safely_increasing = false;
    }

    return safely_increasing;
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
