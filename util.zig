const std = @import("std");

pub fn get_input(allocator: std.mem.Allocator, year: u16, day: u8) ![]u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var buf: [4096]u8 = undefined;

    const uri_string = try std.fmt.bufPrint(&buf, "https://jbirk.de/~jona/aoc/input/{}/{}", .{ year, day });

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
