const std = @import("std");
const vaxis = @import("vaxis");
const xev = @import("xev");

pub const panic = vaxis.panic_handler;
pub const std_options: std.Options = .{
    .log_scope_levels = &.{
        .{ .scope = .vaxis, .level = .warn },
        .{ .scope = .vaxis_parser, .level = .warn },
        .{ .scope = .vaxis_xev, .level = .warn },
    },
};

const TitleText = struct {
    text: []const u8,

    pub fn width(self: *const @This()) usize {
        var it = std.mem.splitScalar(u8, self.text, '\n');
        var max: usize = 0;
        while (it.next()) |line| {
            max = @max(max, line.len);
        }
        return max;
    }

    pub fn height(self: *const @This()) usize {
        var it = std.mem.splitScalar(u8, self.text, '\n');
        var count: usize = 0;
        while (it.next()) |_| {
            count += 1;
        }
        return count;
    }
};

const lose_text: TitleText = .{
    .text =
    \\____    ____   ______    __    __     __        ______        _______. _______  __
    \\\   \  /   /  /  __  \  |  |  |  |   |  |      /  __  \      /       ||   ____||  |
    \\ \   \/   /  |  |  |  | |  |  |  |   |  |     |  |  |  |    |   (----`|  |__   |  |
    \\  \_    _/   |  |  |  | |  |  |  |   |  |     |  |  |  |     \   \    |   __|  |  |
    \\    |  |     |  `--'  | |  `--'  |   |  `----.|  `--'  | .----)   |   |  |____ |__|
    \\    |__|      \______/   \______/    |_______| \______/  |_______/    |_______|(__)
    ,
};

const win_text: TitleText = .{
    .text =
    \\____    ____   ______    __    __    ____    __    ____  __  .__   __.  __
    \\\   \  /   /  /  __  \  |  |  |  |   \   \  /  \  /   / |  | |  \ |  | |  |
    \\ \   \/   /  |  |  |  | |  |  |  |    \   \/    \/   /  |  | |   \|  | |  |
    \\  \_    _/   |  |  |  | |  |  |  |     \            /   |  | |  . `  | |  |
    \\    |  |     |  `--'  | |  `--'  |      \    /\    /    |  | |  |\   | |__|
    \\    |__|      \______/   \______/        \__/  \__/     |__| |__| \__| (__)
    ,
};

const normal_top: TitleText = .{
    .text =
    \\.___________. _______ .______      .___  ___.
    \\|           ||   ____||   _  \     |   \/   |
    \\`---|  |----`|  |__   |  |_)  |    |  \  /  |
    \\    |  |     |   __|  |      /     |  |\/|  |
    \\    |  |     |  |____ |  |\  \----.|  |  |  |
    \\    |__|     |_______|| _| `._____||__|  |__|
    ,
};

const normal_bottom: TitleText = .{
    .text =
    \\     _______.____    __    ____  _______  _______ .______    _______ .______
    \\    /       |\   \  /  \  /   / |   ____||   ____||   _  \  |   ____||   _  \
    \\   |   (----` \   \/    \/   /  |  |__   |  |__   |  |_)  | |  |__   |  |_)  |
    \\    \   \      \            /   |   __|  |   __|  |   ___/  |   __|  |      /
    \\.----)   |      \    /\    /    |  |____ |  |____ |  |      |  |____ |  |\  \----.
    \\|_______/        \__/  \__/     |_______||_______|| _|      |_______|| _| `._____|
    ,
};

const Point = struct {
    col: usize,
    row: usize,
};

const background = vaxis.Color{
    .rgb = [_]u8{ 0x09, 0x09, 0x09 },
};

const Cell = struct {
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
            .bg = background,
        },
        // 1
        .{
            .fg = .{ .rgb = [_]u8{ 0x33, 0x33, 0xff } },
            .bg = background,
        },
        // 1
        .{
            .fg = .{ .rgb = [_]u8{ 0x00, 0xff, 0x00 } },
            .bg = background,
        },
        // 3
        .{
            .fg = .{ .rgb = [_]u8{ 0xff, 0x00, 0x00 } },
            .bg = background,
        },
        // 4
        .{
            .fg = .{ .rgb = [_]u8{ 0x33, 0x33, 0x8b } },
            .bg = background,
        },
        // 5
        .{
            .fg = .{ .rgb = [_]u8{ 0xa5, 0x2a, 0x2a } },
            .bg = background,
        },
        // 6
        .{
            .fg = .{ .rgb = [_]u8{ 0x00, 0xff, 0xff } },
            .bg = background,
        },
        // 7
        .{
            .fg = .{ .rgb = [_]u8{ 0x00, 0x00, 0x00 } },
            .bg = background,
        },
        // 8
        .{
            .fg = .{ .rgb = [_]u8{ 0x00, 0x00, 0xff } },
            .bg = background,
        },
        // 9
        .{
            .fg = .{ .rgb = [_]u8{ 0xbf, 0xbf, 0xbf } },
            .bg = background,
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
                        .bg = background,
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
};

const Status = enum {
    playing,
    won,
    lost,
};

const Board = struct {
    gpa_alloc: std.mem.Allocator,
    exploded: ?Point = null,
    height: usize,
    width: usize,
    cells: []Cell,

    fn index(self: *@This(), col: usize, row: usize) usize {
        std.debug.assert(row < self.height);
        std.debug.assert(col < self.width);
        return col * self.height + row;
    }

    pub fn cell(self: *@This(), col: usize, row: usize) *Cell {
        return &self.cells[self.index(col, row)];
    }

    pub fn init(gpa_alloc: std.mem.Allocator, width: usize, height: usize, difficulty: f64) !*@This() {
        const b = try gpa_alloc.create(@This());
        b.gpa_alloc = gpa_alloc;
        b.exploded = null;
        b.width = width;
        b.height = height;
        b.cells = try gpa_alloc.alloc(Cell, width * height);

        var random = std.rand.DefaultPrng.init(seed: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :seed seed;
        });

        var rand = random.random();

        for (0..width) |c| {
            for (0..height) |r| {
                b.cell(c, r).* = .{
                    .contents = if (rand.float(f64) < difficulty) .bomb else .empty,
                    .state = .hidden,
                    .neighbors = 0,
                };
            }
        }

        for (0..width) |col| {
            for (0..height) |row| {
                const c = b.cell(col, row);
                var it = b.neigbors(col, row);
                while (it.next()) |p| {
                    const cn = b.cell(p.col, p.row);
                    if (cn.contents == .bomb) c.neighbors += 1;
                }
            }
        }

        return b;
    }

    pub fn deinit(self: *@This()) void {
        const alloc = self.gpa_alloc;
        alloc.free(self.cells);
        alloc.destroy(self);
    }

    pub fn segment(self: *@This(), point: Point) vaxis.Segment {
        return self.cell(point.col, point.row).segment(self.exploded != null);
    }

    pub fn click(self: *@This(), point: Point, style: enum { left, right }) !void {
        if (self.status() != .playing) return;

        const c = self.cell(point.col, point.row);
        switch (style) {
            .left => {
                switch (c.state) {
                    .hidden, .flagged => {
                        c.state = .revealed;
                        switch (c.contents) {
                            .bomb => {
                                self.exploded = point;
                            },
                            .empty => {
                                try self.floodFill(point);
                            },
                        }
                    },
                    .revealed => {},
                }
            },
            .right => {
                switch (c.state) {
                    .hidden => c.state = .flagged,
                    .flagged => c.state = .hidden,
                    .revealed => {},
                }
            },
        }
    }

    const Neighbors = struct {
        col: usize,
        row: usize,
        width: usize,
        height: usize,
        index: usize,

        pub fn next(self: *@This()) ?Point {
            while (self.index <= 8) {
                self.index += 1;
                switch (self.index) {
                    1 => {
                        if (self.col == 0) continue;
                        const c = self.col - 1;
                        if (self.row == 0) continue;
                        const r = self.row - 1;
                        return .{ .col = c, .row = r };
                    },
                    2 => {
                        const c = self.col;
                        if (self.row == 0) continue;
                        const r = self.row - 1;
                        return .{ .col = c, .row = r };
                    },
                    3 => {
                        const c = self.col + 1;
                        if (c >= self.width) continue;
                        if (self.row == 0) continue;
                        const r = self.row - 1;
                        return .{ .col = c, .row = r };
                    },
                    4 => {
                        if (self.col == 0) continue;
                        const c = self.col - 1;
                        const r = self.row;
                        return .{ .col = c, .row = r };
                    },
                    5 => {
                        continue;
                    },
                    6 => {
                        const c = self.col + 1;
                        if (c >= self.width) continue;
                        const r = self.row;
                        return .{ .col = c, .row = r };
                    },
                    7 => {
                        if (self.col == 0) continue;
                        const c = self.col - 1;
                        const r = self.row + 1;
                        if (r >= self.height) continue;
                        return .{ .col = c, .row = r };
                    },
                    8 => {
                        const c = self.col;
                        const r = self.row + 1;
                        if (r >= self.height) continue;
                        return .{ .col = c, .row = r };
                    },
                    9 => {
                        const c = self.col + 1;
                        if (c >= self.width) continue;
                        const r = self.row + 1;
                        if (r >= self.height) continue;
                        return .{ .col = c, .row = r };
                    },
                    else => unreachable,
                }
            }
            return null;
        }
    };

    pub fn neigbors(self: *@This(), col: usize, row: usize) Neighbors {
        return .{
            .col = col,
            .row = row,
            .width = self.width,
            .height = self.height,
            .index = 0,
        };
    }

    fn clearVisited(self: *@This()) void {
        for (self.cells) |*c| c.visited = false;
    }

    fn floodFill(self: *@This(), point: Point) !void {
        self.clearVisited();

        var stack = std.ArrayList(Point).init(self.gpa_alloc);
        defer stack.deinit();

        {
            const c = self.cell(point.col, point.row);
            c.state = .revealed;

            var it = self.neigbors(point.col, point.row);
            while (it.next()) |p| {
                try stack.append(p);
            }
        }

        while (stack.popOrNull()) |p0| {
            const c = self.cell(p0.col, p0.row);
            if (c.visited) continue;
            c.visited = true;
            if (c.contents == .empty and c.state == .hidden) {
                c.state = .revealed;
                if (c.neighbors == 0) {
                    var it = self.neigbors(p0.col, p0.row);
                    while (it.next()) |pn| try stack.append(pn);
                }
            }
        }

        self.clearVisited();
    }

    pub fn bombs(self: *@This()) usize {
        var count: usize = 0;
        for (self.cells) |c| {
            if (c.contents == .bomb) count += 1;
        }
        return count;
    }

    pub fn flagged(self: *@This()) usize {
        var count: usize = 0;
        for (self.cells) |c| {
            if (c.state == .flagged) count += 1;
        }
        return count;
    }

    pub fn missed(self: *@This()) usize {
        var count: usize = 0;
        for (self.cells) |c| {
            if (c.contents == .bomb and c.state != .flagged) count += 1;
        }
        return count;
    }

    pub fn status(self: *@This()) Status {
        if (self.exploded != null) return .lost;
        var count: usize = 0;
        for (self.cells) |c| {
            if (c.contents == .bomb and c.state != .flagged) count += 1;
        }
        if (count == 0) return .won;
        return .playing;
    }
};

const TermSweeper = struct {
    gpa_alloc: std.mem.Allocator,
    tty: *vaxis.Tty,
    vx: *vaxis.Vaxis,
    mouse: ?vaxis.Mouse,
    board: *Board,
    board_mutex: std.Thread.Mutex,

    pub fn init(gpa_alloc: std.mem.Allocator, tty: *vaxis.Tty, vx: *vaxis.Vaxis) !TermSweeper {
        const board = try Board.init(gpa_alloc, 10, 10, 0.12);
        return .{
            .gpa_alloc = gpa_alloc,
            .tty = tty,
            .vx = vx,
            .mouse = null,
            .board = board,
            .board_mutex = .{},
        };
    }

    pub fn deinit(self: *TermSweeper) void {
        self.board.deinit();
    }

    pub fn update(self: *TermSweeper, event: vaxis.xev.Event) !bool {
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

    pub fn restart(self: *TermSweeper, width: usize, height: usize, difficulty: f64) !void {
        self.board_mutex.lock();
        defer self.board_mutex.unlock();

        const old = self.board;
        self.board = try Board.init(self.gpa_alloc, width, height, difficulty);
        old.deinit();
    }

    pub fn draw(self: *TermSweeper) !void {
        self.board_mutex.lock();
        defer self.board_mutex.unlock();

        var arena = std.heap.ArenaAllocator.init(self.gpa_alloc);
        const arena_alloc = arena.allocator();
        defer arena.deinit();

        try self.vx.setTitle(self.tty.anyWriter(), "💣 TermSweeper ⛳");
        // self.vx.setMouseShape(.default);
        const win = self.vx.window();

        if (win.width < 80 or win.height < 24) {
            win.clear();
            const text = try std.fmt.allocPrint(arena_alloc, "{d}c × {d}r is too small!", .{ win.width, win.height });

            _ = try win.printSegment(
                .{
                    .text = text,
                    .style = .{},
                },
                .{
                    .col_offset = if (text.len > win.width) 0 else win.width / 2 - text.len / 2,
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
                    break :offset window_center -| board_center;
                },
                .y_off = offset: {
                    const window_center = win.height / 2;
                    const board_center = self.board.height / 2;
                    break :offset window_center -| board_center;
                },
                .width = .{
                    .limit = self.board.width * 2 + 2,
                },
                .height = .{
                    .limit = self.board.height + 2,
                },
                .border = .{
                    .where = .all,
                },
            },
        );

        {
            const status = self.board.status();
            const text = switch (status) {
                .playing => normal_top,
                .won => win_text,
                .lost => lose_text,
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
                    .y_off = board.y_off - text.height() - 3,
                    .width = .{
                        .limit = text.width(),
                    },
                    .height = .{
                        .limit = text.width(),
                    },
                },
            );

            {
                var it = std.mem.splitScalar(u8, text.text, '\n');
                var i: usize = 0;
                while (it.next()) |line| : (i += 1) {
                    _ = try top.printSegment(
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
                .playing => normal_bottom,
                .won => win_text,
                .lost => lose_text,
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
                    .width = .{
                        .limit = text.width(),
                    },
                    .height = .{
                        .limit = text.width(),
                    },
                },
            );

            {
                var it = std.mem.splitScalar(u8, text.text, '\n');
                var i: usize = 0;
                while (it.next()) |line| : (i += 1) {
                    _ = try bottom.printSegment(
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
                .width = .{
                    .limit = 12,
                },
                .height = .{
                    .limit = 3,
                },
            });

            _ = try status.printSegment(
                .{
                    .text = try std.fmt.allocPrint(arena_alloc, "Bombs:  {d:>3}", .{self.board.bombs()}),
                    .style = .{},
                },
                .{
                    .col_offset = 0,
                    .row_offset = 0,
                },
            );

            _ = try status.printSegment(
                .{
                    .text = try std.fmt.allocPrint(arena_alloc, "Flags:  {d:>3}", .{self.board.flagged()}),
                    .style = .{},
                },
                .{
                    .col_offset = 0,
                    .row_offset = 1,
                },
            );

            _ = try status.printSegment(
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
                .bg = background,
            },
        });

        var mouse: ?struct {
            point: Point,
            click: enum { none, left, right },
        } = null;

        if (board.hasMouse(self.mouse)) |m| {
            self.mouse = null;
            self.vx.setMouseShape(.pointer);
            const c = m.col - board.x_off;
            const r = m.row - board.y_off;
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
                .left => try self.board.click(m.point, .left),
                .right => try self.board.click(m.point, .right),
                .none => {},
            }
        }

        for (0..self.board.height) |row| {
            for (0..self.board.width) |col| {
                _ = try board.printSegment(
                    self.board.segment(.{ .col = col, .row = row }),
                    .{
                        .row_offset = row,
                        .col_offset = col * 2,
                    },
                );
            }
        }

        var buffered = self.tty.bufferedWriter();
        try self.vx.render(buffered.writer().any());
        try buffered.flush();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) {
            std.log.err("memory leak", .{});
        }
    }
    const gpa_alloc = gpa.allocator();

    var tty = try vaxis.Tty.init();
    defer tty.deinit();

    var vx = try vaxis.init(gpa_alloc, .{});
    defer vx.deinit(gpa_alloc, tty.anyWriter());

    var pool = xev.ThreadPool.init(.{});
    var loop = try xev.Loop.init(.{
        .thread_pool = &pool,
    });
    defer loop.deinit();

    var app = try TermSweeper.init(gpa_alloc, &tty, &vx);
    defer app.deinit();

    var vx_loop: vaxis.xev.TtyWatcher(TermSweeper) = undefined;
    try vx_loop.init(&tty, &vx, &loop, &app, eventCallback);

    try vx.enterAltScreen(tty.anyWriter());
    try vx.queryTerminalSend(tty.anyWriter());
    try vx.setMouseMode(tty.anyWriter(), true);

    const ws = try vaxis.Tty.getWinsize(tty.fd);
    try vx.resize(gpa_alloc, tty.anyWriter(), ws);
    try app.draw();

    const query_timer = try xev.Timer.init();
    var query_timer_cmp: xev.Completion = .{};
    query_timer.run(&loop, &query_timer_cmp, 1000, TermSweeper, &app, queryTimerCallback);

    const periodic_timer = try xev.Timer.init();
    var peridoic_timer_cmp: xev.Completion = .{};
    periodic_timer.run(&loop, &peridoic_timer_cmp, 500, TermSweeper, &app, periodicTimerCallback);

    try loop.run(.until_done);
}

fn queryTimerCallback(
    ud: ?*TermSweeper,
    l: *xev.Loop,
    c: *xev.Completion,
    r: xev.Timer.RunError!void,
) xev.CallbackAction {
    _ = r catch @panic("timer error");
    _ = l;
    _ = c;

    var app = ud orelse return .disarm;
    app.vx.enableDetectedFeatures(app.tty.anyWriter()) catch @panic("TODO");

    return .disarm;
}

fn eventCallback(
    ud: ?*TermSweeper,
    loop: *xev.Loop,
    watcher: *vaxis.xev.TtyWatcher(TermSweeper),
    event: vaxis.xev.Event,
) xev.CallbackAction {
    const app = ud orelse unreachable;
    switch (event) {
        .winsize => |ws| {
            watcher.vx.resize(app.gpa_alloc, watcher.tty.anyWriter(), ws) catch @panic("TODO");
            app.draw() catch @panic("TODO");
        },
        else => {
            const stop = app.update(event) catch @panic("TODO");
            if (stop) {
                loop.stop();
                return .disarm;
            }
        },
    }
    return .rearm;
}

fn periodicTimerCallback(
    ud: ?*TermSweeper,
    l: *xev.Loop,
    c: *xev.Completion,
    r: xev.Timer.RunError!void,
) xev.CallbackAction {
    _ = r catch @panic("timer error");

    var app = ud orelse return .disarm;
    app.draw() catch @panic("couldn't draw");

    const timer = try xev.Timer.init();
    timer.run(l, c, 500, TermSweeper, ud, periodicTimerCallback);

    return .disarm;
}
