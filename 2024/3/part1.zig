const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const get_input = @import("util").get_input;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const response_body = try get_input(allocator, 2024, 3);
    defer allocator.free(response_body);

    const State = enum {
        Outside,
        M,
        U,
        L,
        LParen,
        FirstDigit,
        SecondDigit,
        RParen,
    };

    var current_state = State.Outside;
    var first_number = ArrayList(u8).init(allocator);
    defer first_number.deinit();
    var second_number = ArrayList(u8).init(allocator);
    defer second_number.deinit();

    var sum_of_products: i32 = 0;

    for (response_body) |char| {
        if (char == 'm') {
            current_state = State.M;
        } else if (current_state == State.M and char == 'u') {
            current_state = State.U;
        } else if (current_state == State.U and char == 'l') {
            current_state = State.L;
        } else if (current_state == State.L and char == '(') {
            first_number.clearRetainingCapacity();
            second_number.clearRetainingCapacity();
            current_state = State.FirstDigit;
        } else if (current_state == State.FirstDigit) {
            if (char >= '0' and char <= '9') {
                try first_number.append(char);
                if (first_number.items.len > 3) {
                    current_state = State.Outside;
                }
            } else if (char == ',') {
                current_state = State.SecondDigit;
            } else {
                current_state = State.Outside;
            }
        } else if (current_state == State.SecondDigit) {
            if (char >= '0' and char <= '9') {
                try second_number.append(char);
                if (second_number.items.len > 3) {
                    current_state = State.Outside;
                }
            } else if (char == ')') {
                const a = try std.fmt.parseInt(i32, first_number.items, 10);
                const b = try std.fmt.parseInt(i32, second_number.items, 10);
                sum_of_products += a * b;
                current_state = State.Outside;
            } else {
                current_state = State.Outside;
            }
        }
    }

    std.debug.print("part1: {}\n", .{sum_of_products});
}
