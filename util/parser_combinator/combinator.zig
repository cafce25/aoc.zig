const std = @import("std");
const Allocator = std.mem.Allocator;

const pc = @import("../parser_combinator.zig");
const Parser = pc.Parser;
const Error = pc.Error;

pub fn OneOf(comptime T: type) type {
    return struct {
        const Self = @This();
        const Value = T;

        parsers: []const *Parser(T),
        parser: Parser(Value),

        pub fn parse(self: *Self, src: *[]const u8) Error!?Value {
            const orig_src = src.*;
            for (self.parsers) |current| {
                const value = try current.parse(src);
                if (value != null) {
                    return value;
                }
                src.* = orig_src;
            }
            return null;
        }

        pub fn init(parsers: []const *Parser(T)) Self {
            return Self{ .parsers = parsers, .parser = .{
                ._parse = struct {
                    fn parse(parser: *Parser(Value), src: *[]const u8) Error!?Value {
                        const self: *Self = @fieldParentPtr("parser", parser);
                        return self.parse(src);
                    }
                }.parse,
            } };
        }
    };
}

pub fn ManySource(comptime T: type) type {
    return struct {
        const Self = @This();
        const Value = []const u8;

        element_parser: *Parser(T),
        parser: Parser(Value),

        pub fn parse(self: *Self, src: *[]const u8) Error!?Value {
            const orig_source = src.*;
            var last_value = try self.element_parser.parse(src);
            while (last_value != null) : (last_value = try self.element_parser.parse(src)) {}
            if (std.mem.eql(u8, orig_source, src.*)) {
                return null;
            }
            return orig_source[0..(orig_source.len - src.len)];
        }

        pub fn init(element_parser: *Parser(T)) Self {
            return Self{ .element_parser = element_parser, .parser = .{
                ._parse = struct {
                    fn parse(parser: *Parser(Value), src: *[]const u8) Error!?Value {
                        const self: *Self = @fieldParentPtr("parser", parser);
                        return self.parse(src);
                    }
                }.parse,
            } };
        }
    };
}

pub fn Many(comptime T: type) type {
    return struct {
        const Value = std.ArrayList(T);
        const Self = @This();

        element_parser: *Parser(T),
        parser: Parser(Value),
        allocator: Allocator,

        pub fn parse(self: *Self, src: *[]const u8) !?std.ArrayList(T) {
            var values = std.ArrayList(T).init(self.allocator);
            var last_value = try self.element_parser.parse(src);
            while (last_value != null) : (last_value = try self.element_parser.parse(src)) {
                try values.append(last_value);
            }
            if (values.items.len == 0) {
                values.deinit();
                return null;
            }
            return values;
        }

        pub fn init(allocator: Allocator, element_parser: *Parser(T)) @This() {
            return @This(){ .allocator = allocator, .element_parser = element_parser, .parser = .{
                ._parse = struct {
                    fn parse(parser: *Parser(Value), src: *[]const u8) Error!?Value {
                        const self: *Many(T) = @fieldParentPtr("parser", parser);
                        return self.parse(src);
                    }
                }.parse,
            } };
        }
    };
}

pub fn Optional(comptime T: type) type {
    return struct {
        const Value = ?T;
        const Self = @This();

        parser: Parser(Value),
        inner: *Parser(T),

        pub fn parse(self: *Self, src: []const u8) Error!?Value {
            return self.inner.parse(src);
        }
        pub fn init(inner: *Parser(T)) @This() {
            return .{
                .parser = .{ ._parse = struct {
                    fn parse(parser: *Self, src: []const u8) Error!?Value {
                        const self: *Self = @fieldParentPtr("parser", parser);
                        return self.parse(src);
                    }
                }.parse },
                .inner = inner,
            };
        }
    };
}

pub fn Seq(comptime Types: []const type) type {
    return struct {
        const Value = std.meta.Tuple(Types);
        const Parsers = std.meta.Tuple(&map_types(ParserPtr, Types));
        const Self = @This();

        parser: Parser(Value),
        parsers: Parsers,

        pub fn parse(self: *Self, src: *[]const u8) Error!?Value {
            const orig_src = src.*;
            var values: Value = undefined;

            inline for (self.parsers, 0..) |elem_parser, i| {
                if (try elem_parser.parse(src)) |value| {
                    values[i] = value;
                } else {
                    src.* = orig_src;
                    return null;
                }
            }

            return values;
        }
        pub fn init(parsers: Parsers) @This() {
            return @This(){
                .parser = .{
                    ._parse = struct {
                        fn parse(parser: *Parser(Value), src: *[]const u8) Error!?Value {
                            const self: *Self = @fieldParentPtr("parser", parser);
                            return self.parse(src);
                        }
                    }.parse,
                },
                .parsers = parsers,
            };
        }
    };
}

pub fn Separated(comptime Value: type, comptime Separator: type) type {
    return struct {
        parser: Parser(std.ArrayList(Value)),
        value_parser: *Parser(Value),
        separator_parser: *Parser(Separator),
        allocator: Allocator,

        pub fn init(allocator: Allocator, value_parser: *Parser(Value), separator_parser: *Parser(Separator)) @This() {
            return .{
                .parser = .{ ._parse = @This().parse },
                .value_parser = value_parser,
                .separator_parser = separator_parser,
                .allocator = allocator,
            };
        }

        fn parse(parser: *Parser(std.ArrayList(Value)), src: *[]const u8) Error!?std.ArrayList(Value) {
            const self: *@This() = @fieldParentPtr("parser", parser);

            const first_value = try self.value_parser.parse(src);

            if (first_value) |f| {
                var values = std.ArrayList(Value).init(self.allocator);
                try values.append(f);

                while (transpose_opt(&.{ Separator, Value }, .{ try self.separator_parser.parse(src), try self.value_parser.parse(src) })) |value| {
                    try values.append(value[1]);
                }

                if (values.items.len == 0) {
                    values.deinit();
                } else {
                    return values;
                }
            }
            return null;
        }
    };
}

pub fn ReadTill(comptime T: type) type {
    return struct {
        parser: Parser(std.meta.Tuple(&.{ []const u8, T })),
        terminator: *Parser(T),

        pub fn init(terminator: *Parser(T)) @This() {
            return @This(){
                .parser = .{ ._parse = @This().parse },
                .terminator = terminator,
            };
        }

        fn parse(parser: *Parser(std.meta.Tuple(&.{ []const u8, T })), src: *[]const u8) Error!?std.meta.Tuple(&.{ []const u8, T }) {
            const self: *@This() = @fieldParentPtr("parser", parser);
            const orig_src = src.*;
            var i: usize = 0;
            while (i < orig_src.len) : (i += 1) {
                var skipped = src.*[i..];
                if (try self.terminator.parse(&skipped)) |parsed| {
                    src.* = src.*[i..];
                    return .{ orig_src[0..i], parsed };
                }
            }
            return null;
        }
    };
}

pub fn ReadTillInclusive(comptime T: type) type {
    return struct {
        parser: Parser(std.meta.Tuple(&.{ []const u8, T })),
        terminator: *Parser(T),

        pub fn init(terminator: *Parser(T)) @This() {
            return @This(){
                .parser = .{ ._parse = @This().parse },
                .terminator = terminator,
            };
        }

        fn parse(parser: *Parser(std.meta.Tuple(&.{ []const u8, T })), src: *[]const u8) Error!?std.meta.Tuple(&.{ []const u8, T }) {
            const self: *@This() = @fieldParentPtr("parser", parser);
            const orig_src = src.*;
            var i: usize = 0;
            while (i < orig_src.len) : (i += 1) {
                var skipped = src.*[i..];
                if (try self.terminator.parse(&skipped)) |parsed| {
                    src.* = skipped;
                    return .{ orig_src[0..i], parsed };
                }
            }
            return null;
        }
    };
}

pub fn Map(comptime T: type, comptime U: type, comptime Ctx: type) type {
    return struct {
        const Value = U;
        const Self = @This();

        parser: Parser(Value),
        inner: *Parser(T),
        map: *const fn (T, *?Ctx) Error!?U,
        context: ?Ctx = null,

        pub fn init(inner: *Parser(T), map: *const fn (T, *?Ctx) Error!?U, opts: anytype) @This() {
            var this = @This(){
                .parser = .{ ._parse = struct {
                    fn parse(parser: *Parser(Value), src: *[]const u8) Error!?Value {
                        const self: *Self = @fieldParentPtr("parser", parser);
                        return self.parse(src);
                    }
                }.parse },
                .inner = inner,
                .map = map,
            };

            if (@hasField(@TypeOf(opts), "context")) {
                this.context = opts.context;
            }

            return this;
        }

        pub fn parse(self: *Self, src: *[]const u8) Error!?Value {
            const orig_src = src.*;
            errdefer src.* = orig_src;

            const t = (try self.inner.parse(src)) orelse return null;
            const u = try self.map(t, &self.context);
            if (u) |value| {
                return value;
            } else {
                src.* = orig_src;
                return null;
            }
        }
    };
}

fn ParserPtr(comptime T: type) type {
    return *Parser(T);
}

fn map_types(comptime map_type: fn (type) type, comptime Ts: []const type) [Ts.len]type {
    comptime var mapped: [Ts.len]type = undefined;
    inline for (Ts, 0..) |T, i| {
        mapped[i] = map_type(T);
    }

    return mapped;
}

fn map_opt(comptime T: type) type {
    return ?T;
}

fn spread_opt_tuple(comptime Ts: []const type) [Ts.len]type {
    return map_types(map_opt, Ts);
}

fn transpose_opt(comptime Ts: []const type, tuple_opts: std.meta.Tuple(&spread_opt_tuple(Ts))) ?std.meta.Tuple(Ts) {
    var opt_tuple: std.meta.Tuple(Ts) = undefined;
    inline for (Ts, 0..) |_, i| {
        if (tuple_opts[i]) |v| {
            opt_tuple[i] = v;
        } else {
            return null;
        }
    }
    return opt_tuple;
}

test "separated" {
    var input: []const u8 = "a,a,a,a";
    var value_parser = pc.parser.Character.init('a');
    var separator_parser = pc.parser.Character.init(',');

    var separated_parser = Separated(u8, u8).init(std.testing.allocator, &value_parser.parser, &separator_parser.parser);

    const parsed = (try separated_parser.parser.parse(&input)).?;
    defer parsed.deinit();

    try std.testing.expectEqualSlices(u8, "aaaa", parsed.items);
}

test "seq" {
    var input: []const u8 = "ab12c";
    var str_parser = pc.parser.Literal.init("ab");
    var num_parser = try pc.parser.Number(i8).init(.{});
    var char_parser = pc.parser.Character.init('c');
    var seq_parser = Seq(&.{ []const u8, i8, u8 }).init(.{
        &str_parser.parser,
        &num_parser.parser,
        &char_parser.parser,
    });
    const p = &seq_parser.parser;

    const result = (try p.parse(&input)).?;

    try std.testing.expectEqualStrings("ab", result[0]);
    try std.testing.expectEqual(12, result[1]);
    try std.testing.expectEqual('c', result[2]);
}

test "read_till" {
    var input: []const u8 = "dutrianedutrinaedtrunaidetrn1";

    var digit_parser = pc.parser.Digit.init();
    var read_till_digit = ReadTill(u8).init(&digit_parser.parser);

    const p = &read_till_digit.parser;

    const result = (try p.parse(&input)).?;
    try std.testing.expectEqualStrings("dutrianedutrinaedtrunaidetrn", result[0]);
    try std.testing.expectEqual('1', result[1]);
}

test "map" {
    var input: []const u8 = "1";
    var digit_parser = pc.parser.Digit.init();
    var map = Map(u8, u8, void)
        .init(&digit_parser.parser, struct {
        fn next_digit(d: u8, _: *?void) Error!?u8 {
            if (d >= '9' or d < '0') {
                return '0';
            } else {
                return d + 1;
            }
        }
    }.next_digit, .{});

    const p = &map.parser;

    const result = (try p.parse(&input)).?;
    try std.testing.expectEqual('2', result);
}
