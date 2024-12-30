const std = @import("std");
const Allocator = std.mem.Allocator;
const pc = @import("../parser_combinator.zig");
const Error = pc.Error;

pub fn Parser(comptime T: type) type {
    return struct {
        pub const Value = T;
        _parse: *const fn (*Parser(T), *[]const u8) Error!?T,

        pub fn parse(self: *Parser(T), src: *[]const u8) Error!?T {
            return self._parse(self, src);
        }
    };
}

pub const Character = struct {
    want: u8,
    parser: Parser(u8),

    fn parse(parser: *Parser(u8), src: *[]const u8) Error!?u8 {
        const self: *Character = @fieldParentPtr("parser", parser);
        if (src.len == 0) {
            return null;
        }
        const value = src.*[0];
        if (self.want == value) {
            src.* = src.*[1..];
            return value;
        } else {
            return null;
        }
    }
    pub fn init(want: u8) Character {
        return Character{
            .parser = .{
                ._parse = Character.parse,
            },
            .want = want,
        };
    }
};

pub const Literal = struct {
    const T = []const u8;
    want: T,
    parser: Parser(T),
    fn parse(parser: *Parser(T), src: *[]const u8) Error!?T {
        const self: *Literal = @fieldParentPtr("parser", parser);
        const value = src.*[0..self.want.len];
        if (std.mem.eql(u8, self.want, value)) {
            src.* = src.*[self.want.len..];
            return value;
        } else {
            return null;
        }
    }

    pub fn init(want: []const u8) @This() {
        return @This(){
            .want = want,
            .parser = .{
                ._parse = Literal.parse,
            },
        };
    }
};

pub const Digit = struct {
    parser: Parser(u8),
    fn parse(_: *Parser(u8), src: *[]const u8) Error!?u8 {
        if (src.len == 0) {
            return null;
        }
        const digit = src.*[0];
        if (digit >= '0' and digit <= '9') {
            src.* = src.*[1..];
            return digit;
        }
        return null;
    }
    pub fn init() @This() {
        return .{ .parser = .{
            ._parse = @This().parse,
        } };
    }
};

pub fn Number(comptime T: type) type {
    return struct {
        parser: Parser(T),
        base: u8,
        max_digits: u64,
        fn parse(parser: *Parser(T), src: *[]const u8) Error!?T {
            const self: *Number(T) = @fieldParentPtr("parser", parser);
            const orig_src = src.*;
            var digit_parse = Digit.init();
            var num_parse = pc.combinator.ManySource(u8).init(&digit_parse.parser);
            var plus_sign = Character.init('+');
            var minus_sign = Character.init('-');

            var sign_parse =
                if (@typeInfo(T).Int.signedness == .signed) pc.combinator.OneOf(u8).init(&.{
                &plus_sign.parser,
                &minus_sign.parser,
            }) else pc.combinator.OneOf(u8).init(&.{
                &plus_sign.parser,
            });

            const sign = try sign_parse.parser.parse(src) orelse '+';

            const num = try num_parse.parser.parse(src) orelse {
                src.* = orig_src;
                return null;
            };
            if (num.len > self.max_digits) {
                src.* = orig_src;
                return null;
            }
            if (@typeInfo(T).Int.signedness == .signed and sign == '-') {
                return -try std.fmt.parseInt(T, num, self.base);
            } else {
                return try std.fmt.parseInt(T, num, self.base);
            }
        }
        pub fn init(args: anytype) !@This() {
            return @This(){ .base = if (@hasField(@TypeOf(args), "base")) args.base else 10, .max_digits = if (@hasField(@TypeOf(args), "max_digits")) args.max_digits else 1 + @ceil(@as(f64, @floatFromInt(@typeInfo(T).Int.bits)) * @log10(2.0)), .parser = .{
                ._parse = @This().parse,
            } };
        }
    };
}

const Any = struct {
    parser: Parser(u8),
    pub fn init() @This() {
        return @This(){ .parser = .{
            ._parse = @This().parse,
        } };
    }
    fn parse(_: *Parser(u8), src: *[]const u8) Error!?u8 {
        if (src.len == 0) {
            return null;
        }
        const value = src.*[0];
        src.* = src.*[1..];
        return value;
    }
};

test "literal parser" {
    var input: []const u8 = "Hello World!";
    var l = Literal.init("Hello");
    const p = &l.parser;
    const parsed = try p.parse(&input);
    try std.testing.expect(parsed != null);
    try std.testing.expectEqualStrings("Hello", parsed.?);
}

test "character parser" {
    var input: []const u8 = "Hello World!";
    var c = Character.init('H');
    const p = &c.parser;
    const parsed = try p.parse(&input);
    try std.testing.expectEqual('H', parsed);
}

test "any parser" {
    var input: []const u8 = "Hello World!";
    var a = Any.init();
    const p = &a.parser;
    var parsed = try p.parse(&input);
    try std.testing.expectEqual('H', parsed);
    parsed = try p.parse(&input);
    try std.testing.expectEqual('e', parsed);
}
