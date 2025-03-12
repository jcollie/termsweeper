const TermSweeper = @This();

const std = @import("std");

const vaxis = @import("vaxis");

const Board = @import("Board.zig");
const Event = @import("event.zig").Event;
const Point = @import("Point.zig");
const titles = @import("titles.zig");
const theme = @import("theme.zig");

alloc: std.mem.Allocator,
tty: *vaxis.Tty,
vx: *vaxis.Vaxis,
mouse: ?vaxis.Mouse,
board: Board,
board_mutex: std.Thread.Mutex,

pub fn init(self: *TermSweeper, alloc: std.mem.Allocator, tty: *vaxis.Tty, vx: *vaxis.Vaxis) !void {
    self.* = .{
        .alloc = alloc,
        .tty = tty,
        .vx = vx,
        .mouse = null,
        .board = undefined,
        .board_mutex = .{},
    };
    try self.board.init(alloc, 10, 10, 0.12);
}

pub fn deinit(self: *TermSweeper) void {
    self.board.deinit(self.alloc);
}

pub fn update(self: *TermSweeper, event: Event) !bool {
    switch (event) {
        .key_press => |key| {
            if (key.matches(vaxis.Key.escape, .{}))
                return true;
            if (key.matches('q', .{}))
                return true;
            if (key.matches('c', .{ .ctrl = true }))
                return true;
            if (key.matches('1', .{})) {
                try self.restart(10, 10, 0.12);
            }
        },
        .mouse => |mouse| {
            self.mouse = mouse;
        },
        else => {},
    }

    try self.draw();
    return false;
}

pub fn restart(self: *TermSweeper, width: u16, height: u16, difficulty: f64) !void {
    self.board_mutex.lock();
    defer self.board_mutex.unlock();

    self.board.deinit(self.alloc);
    try self.board.init(self.alloc, width, height, difficulty);
}

pub fn draw(self: *TermSweeper) !void {
    self.board_mutex.lock();
    defer self.board_mutex.unlock();

    var arena = std.heap.ArenaAllocator.init(self.alloc);
    const arena_alloc = arena.allocator();
    defer arena.deinit();

    try self.vx.setTitle(self.tty.anyWriter(), "💣 TermSweeper ⛳");
    // self.vx.setMouseShape(.default);
    const win = self.vx.window();

    if (win.width < 80 or win.height < 24) {
        win.clear();
        const text = try std.fmt.allocPrint(arena_alloc, "{d}c × {d}r is too small!", .{ win.width, win.height });

        _ = win.printSegment(
            .{
                .text = text,
                .style = .{},
            },
            .{
                .col_offset = if (text.len > win.width) 0 else @intCast(win.width / 2 - text.len / 2),
                .row_offset = win.height / 2,
            },
        );

        var buffered = self.tty.bufferedWriter();
        try self.vx.render(buffered.writer().any());
        try buffered.flush();
        return;
    }
    win.clear();

    const board = win.child(
        .{
            .x_off = offset: {
                const window_center = win.width / 2;
                const board_center = (self.board.width * 2 + 2) / 2;
                break :offset @intCast(window_center -| board_center);
            },
            .y_off = offset: {
                const window_center = win.height / 2;
                const board_center = self.board.height / 2;
                break :offset @intCast(window_center -| board_center);
            },
            .width = @intCast(self.board.width * 2 + 2),
            .height = @intCast(self.board.height + 2),
            .border = .{
                .where = .all,
            },
        },
    );

    {
        const status = self.board.status();
        const text = switch (status) {
            .playing => titles.normal_top,
            .won => titles.win_text,
            .lost => titles.lose_text,
        };
        const style: vaxis.Style = switch (status) {
            .playing => .{
                .fg = .{
                    .rgb = [_]u8{ 0x00, 0x00, 0xff },
                },
            },
            .won => .{
                .fg = .{
                    .rgb = [_]u8{ 0x00, 0xff, 0x00 },
                },
            },
            .lost => .{
                .fg = .{
                    .rgb = [_]u8{ 0xff, 0x00, 0x00 },
                },
            },
        };

        const top = win.child(
            .{
                .x_off = (@max(80, win.width) / 2) - (text.width() / 2),
                .y_off = @intCast(board.y_off - text.height() - 3),
                .width = text.width(),
                .height = text.width(),
            },
        );

        {
            var it = std.mem.splitScalar(u8, text.text, '\n');
            var i: u16 = 0;
            while (it.next()) |line| : (i += 1) {
                _ = top.printSegment(
                    .{
                        .text = line,
                        .style = style,
                    },
                    .{
                        .col_offset = 0,
                        .row_offset = i,
                    },
                );
            }
        }
    }

    {
        const status = self.board.status();
        const text = switch (status) {
            .playing => titles.normal_bottom,
            .won => titles.win_text,
            .lost => titles.lose_text,
        };
        const style: vaxis.Style = switch (status) {
            .playing => .{
                .fg = .{
                    .rgb = [_]u8{ 0x00, 0x00, 0xff },
                },
            },
            .won => .{
                .fg = .{
                    .rgb = [_]u8{ 0x00, 0xff, 0x00 },
                },
            },
            .lost => .{
                .fg = .{
                    .rgb = [_]u8{ 0xff, 0x00, 0x00 },
                },
            },
        };

        const bottom = win.child(
            .{
                .x_off = (win.width / 2) - (text.width() / 2),
                .y_off = board.y_off + board.height + 3,
                .width = text.width(),
                .height = text.width(),
            },
        );

        {
            var it = std.mem.splitScalar(u8, text.text, '\n');
            var i: u16 = 0;
            while (it.next()) |line| : (i += 1) {
                _ = bottom.printSegment(
                    .{
                        .text = line,
                        .style = style,
                    },
                    .{
                        .col_offset = 0,
                        .row_offset = i,
                    },
                );
            }
        }
    }

    {
        const status = win.child(.{
            .x_off = board.x_off - 14,
            .y_off = (win.height / 2) - 1,
            .width = 12,
            .height = 3,
        });

        _ = status.printSegment(
            .{
                .text = try std.fmt.allocPrint(arena_alloc, "Bombs:  {d:>3}", .{self.board.bombs()}),
                .style = .{},
            },
            .{
                .col_offset = 0,
                .row_offset = 0,
            },
        );

        _ = status.printSegment(
            .{
                .text = try std.fmt.allocPrint(arena_alloc, "Flags:  {d:>3}", .{self.board.flagged()}),
                .style = .{},
            },
            .{
                .col_offset = 0,
                .row_offset = 1,
            },
        );

        _ = status.printSegment(
            .{
                .text = try std.fmt.allocPrint(arena_alloc, "Missed: {d:>3}", .{self.board.missed()}),
                .style = .{},
            },
            .{
                .col_offset = 0,
                .row_offset = 2,
            },
        );
    }

    board.fill(.{
        .style = .{
            .bg = theme.background,
        },
    });

    var mouse: ?struct {
        point: Point,
        click: enum { none, left, right },
    } = null;

    if (board.hasMouse(self.mouse)) |m| {
        self.mouse = null;
        self.vx.setMouseShape(.pointer);
        const c: u16 = @intCast(m.col - board.x_off);
        const r: u16 = @intCast(m.row - board.y_off);
        mouse = .{
            .point = .{
                .col = c / 2,
                .row = r,
            },
            .click = if (m.type == .release) switch (m.button) {
                .left => .left,
                .right => .right,
                else => .none,
            } else .none,
        };
    } else {
        if (win.hasMouse(self.mouse)) |_|
            self.vx.setMouseShape(.default);
    }

    if (mouse) |m| {
        switch (m.click) {
            .left => try self.board.click(self.alloc, m.point, .left),
            .right => try self.board.click(self.alloc, m.point, .right),
            .none => {},
        }
    }

    for (0..self.board.height) |row| {
        for (0..self.board.width) |col| {
            _ = board.printSegment(
                self.board.segment(.{
                    .col = @intCast(col),
                    .row = @intCast(row),
                }),
                .{
                    .row_offset = @intCast(row),
                    .col_offset = @intCast(col * 2),
                },
            );
        }
    }

    var buffered = self.tty.bufferedWriter();
    try self.vx.render(buffered.writer().any());
    try buffered.flush();
}
