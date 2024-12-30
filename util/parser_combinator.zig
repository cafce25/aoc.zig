const std = @import("std");
const Allocator = std.mem.Allocator;

pub const parser = @import("parser_combinator/parser.zig");
pub const combinator = @import("parser_combinator/combinator.zig");

pub const Parser = parser.Parser;

pub const Error = error{} || std.mem.Allocator.Error || std.fmt.ParseIntError;
