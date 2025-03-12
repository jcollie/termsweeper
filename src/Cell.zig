const Cell = @This();

const vaxis = @import("vaxis");

const theme = @import("theme.zig");

contents: enum { empty, bomb } = .empty,
state: enum { hidden, revealed, flagged } = .hidden,
neighbors: u8 = 0,
visited: bool = false,

const hidden = "\u{2b1b}";
const bomb = "\u{1f4a3}";
const flag = "\u{26f3}";
const failed_flag = "\u{2620}\u{fe0f}";

const numbers = [10][]const u8{
    "0\xe2\x83\xa3",
    "1\xe2\x83\xa3",
    "2\xe2\x83\xa3",
    "3\xe2\x83\xa3",
    "4\xe2\x83\xa3",
    "5\xe2\x83\xa3",
    "6\xe2\x83\xa3",
    "7\xe2\x83\xa3",
    "8\xe2\x83\xa3",
    "9\xe2\x83\xa3",
};
const colors = [10]vaxis.Style{
    // 0
    .{
        .fg = .{ .rgb = [_]u8{ 0x33, 0x33, 0x33 } },
        .bg = theme.background,
    },
    // 1
    .{
        .fg = .{ .rgb = [_]u8{ 0x33, 0x33, 0xff } },
        .bg = theme.background,
    },
    // 1
    .{
        .fg = .{ .rgb = [_]u8{ 0x00, 0xff, 0x00 } },
        .bg = theme.background,
    },
    // 3
    .{
        .fg = .{ .rgb = [_]u8{ 0xff, 0x00, 0x00 } },
        .bg = theme.background,
    },
    // 4
    .{
        .fg = .{ .rgb = [_]u8{ 0x33, 0x33, 0x8b } },
        .bg = theme.background,
    },
    // 5
    .{
        .fg = .{ .rgb = [_]u8{ 0xa5, 0x2a, 0x2a } },
        .bg = theme.background,
    },
    // 6
    .{
        .fg = .{ .rgb = [_]u8{ 0x00, 0xff, 0xff } },
        .bg = theme.background,
    },
    // 7
    .{
        .fg = .{ .rgb = [_]u8{ 0x00, 0x00, 0x00 } },
        .bg = theme.background,
    },
    // 8
    .{
        .fg = .{ .rgb = [_]u8{ 0x00, 0x00, 0xff } },
        .bg = theme.background,
    },
    // 9
    .{
        .fg = .{ .rgb = [_]u8{ 0xbf, 0xbf, 0xbf } },
        .bg = theme.background,
    },
};
const blank = "  ";

pub fn segment(self: *@This(), exploded: bool) vaxis.Segment {
    return switch (self.state) {
        .hidden => style: {
            if (exploded and self.contents == .bomb)
                break :style .{
                    .text = bomb,
                    .style = .{
                        .bg = .{
                            .rgb = [_]u8{ 0x66, 0x00, 0x00 },
                        },
                    },
                };

            break :style .{
                .text = hidden,
                .style = .{
                    .bg = theme.background,
                },
            };
        },
        .revealed => switch (self.contents) {
            .bomb => .{
                .text = bomb,
                .style = .{
                    .bg = .{
                        .rgb = [_]u8{ 0xff, 0x00, 0x00 },
                    },
                },
            },
            .empty => .{
                .text = numbers[self.neighbors],
                .style = colors[self.neighbors],
            },
        },
        .flagged => .{
            .text = if (exploded and self.contents == .empty) failed_flag else flag,
            .style = .{},
        },
    };
}
