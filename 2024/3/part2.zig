const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const util = @import("util");
const pc = util.parser_combinator;
const parser = pc.parser;
const combinator = pc.combinator;
const get_input = util.get_input;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const response_body = try get_input(alloc, 2024, 3);
    defer alloc.free(response_body);

    var mul_open_parser = parser.Literal.init("mul(");
    var num_parser = try parser.Number(i32).init(.{.wa});
    var comma_parser = parser.Character.init(',');
    var mul_close_parser = parser.Character.init(')');

    var mul_parser = combinator.Seq(&.{
        []const u8,
        i32,
        u8,
        i32,
        u8,
    }).init(.{
        &mul_open_parser.parser,
        &num_parser.parser,
        &comma_parser.parser,
        &num_parser.parser,
        &mul_close_parser.parser,
    });
    var do_parser = parser.Literal.init("do()");
    var dont_parser = parser.Literal.init("don't()");

    const Instruction = union(enum) { do, dont, mul: [2]i32 };

    var mul_mapped = combinator.Map(std.meta.Tuple(&.{
        []const u8,
        i32,
        u8,
        i32,
        u8,
    }), Instruction, void).init(&mul_parser.parser, struct {
        fn map(input: std.meta.Tuple(&.{
            []const u8,
            i32,
            u8,
            i32,
            u8,
        }), _: *?void) pc.Error!?Instruction {
            return .{ .mul = .{ input[1], input[3] } };
        }
    }.map, .{});

    var do_mapped = combinator.Map([]const u8, Instruction, void).init(&do_parser.parser, struct {
        fn map(_: []const u8, _: *?void) pc.Error!?Instruction {
            return .do;
        }
    }.map, .{});

    var dont_mapped = combinator.Map([]const u8, Instruction, void).init(&dont_parser.parser, struct {
        fn map(_: []const u8, _: *?void) pc.Error!?Instruction {
            return .dont;
        }
    }.map, .{});

    var instruction_parser = combinator.OneOf(Instruction).init(&.{
        &mul_mapped.parser,
        &do_mapped.parser,
        &dont_mapped.parser,
    });

    var read_till_instruction = combinator.ReadTillInclusive(Instruction).init(&instruction_parser.parser);
    var read_till_instruction_mapped = combinator.Map(std.meta.Tuple(&.{ []const u8, Instruction }), Instruction, void).init(&read_till_instruction.parser, struct {
        fn map(input: std.meta.Tuple(&.{ []const u8, Instruction }), _: *?void) pc.Error!?Instruction {
            return input[1];
        }
    }.map, .{});

    var remaining = response_body;
    var do = true;
    var sum_of_products: i32 = 0;
    while (try read_till_instruction_mapped.parse(&remaining)) |instruction| {
        switch (instruction) {
            .do => {
                do = true;
            },
            .dont => {
                do = false;
            },
            .mul => |factors| {
                if (do) {
                    sum_of_products += factors[0] * factors[1];
                }
            },
        }
    }

    std.debug.print("part 2: {}", .{sum_of_products});
}
