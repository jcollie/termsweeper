const Board = @This();

const std = @import("std");

const vaxis = @import("vaxis");

const Point = @import("Point.zig");
const Cell = @import("Cell.zig");

pub const Status = enum {
    playing,
    won,
    lost,
};

exploded: ?Point = null,
height: u16,
width: u16,
cells: []Cell,

pub fn init(self: *Board, alloc: std.mem.Allocator, width: u16, height: u16, difficulty: f64) !void {
    self.* = .{
        .exploded = null,
        .width = width,
        .height = height,
        .cells = try alloc.alloc(Cell, width * height),
    };

    var random = std.Random.DefaultPrng.init(seed: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :seed seed;
    });

    var rand = random.random();

    for (0..width) |c| {
        for (0..height) |r| {
            self.cell(c, r).* = .{
                .contents = if (rand.float(f64) < difficulty) .bomb else .empty,
                .state = .hidden,
                .neighbors = 0,
            };
        }
    }

    for (0..width) |col_| {
        for (0..height) |row_| {
            const col: u16 = @intCast(col_);
            const row: u16 = @intCast(row_);
            const c = self.cell(col, row);
            var it = self.neighbors(col, row);
            while (it.next()) |p| {
                const cn = self.cell(p.col, p.row);
                if (cn.contents == .bomb) c.neighbors += 1;
            }
        }
    }
}

pub fn deinit(self: *Board, alloc: std.mem.Allocator) void {
    alloc.free(self.cells);
}

fn index(self: *Board, col: usize, row: usize) usize {
    std.debug.assert(row < self.height);
    std.debug.assert(col < self.width);
    return col * self.height + row;
}

pub fn cell(self: *Board, col: usize, row: usize) *Cell {
    return &self.cells[self.index(col, row)];
}

pub fn segment(self: *Board, point: Point) vaxis.Segment {
    return self.cell(point.col, point.row).segment(self.exploded != null);
}

pub fn click(self: *Board, alloc: std.mem.Allocator, point: Point, style: enum { left, right }) !void {
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
                            try self.floodFill(alloc, point);
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

pub const Neighbors = struct {
    col: u16,
    row: u16,
    width: u16,
    height: u16,
    index: u4,

    pub fn next(self: *Neighbors) ?Point {
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

pub fn neighbors(self: *Board, col: u16, row: u16) Neighbors {
    return .{
        .col = col,
        .row = row,
        .width = self.width,
        .height = self.height,
        .index = 0,
    };
}

fn clearVisited(self: *Board) void {
    for (self.cells) |*c| c.visited = false;
}

fn floodFill(self: *Board, alloc: std.mem.Allocator, point: Point) !void {
    self.clearVisited();

    var stack = std.ArrayList(Point).init(alloc);
    defer stack.deinit();

    {
        const c = self.cell(point.col, point.row);
        c.state = .revealed;

        var it = self.neighbors(point.col, point.row);
        while (it.next()) |p| {
            try stack.append(p);
        }
    }

    while (stack.pop()) |p0| {
        const c = self.cell(p0.col, p0.row);
        if (c.visited) continue;
        c.visited = true;
        if (c.contents == .empty and c.state == .hidden) {
            c.state = .revealed;
            if (c.neighbors == 0) {
                var it = self.neighbors(p0.col, p0.row);
                while (it.next()) |pn| try stack.append(pn);
            }
        }
    }

    self.clearVisited();
}

pub fn bombs(self: *Board) usize {
    var count: usize = 0;
    for (self.cells) |c| {
        if (c.contents == .bomb) count += 1;
    }
    return count;
}

pub fn flagged(self: *Board) usize {
    var count: usize = 0;
    for (self.cells) |c| {
        if (c.state == .flagged) count += 1;
    }
    return count;
}

pub fn missed(self: *Board) usize {
    var count: usize = 0;
    for (self.cells) |c| {
        if (c.contents == .bomb and c.state != .flagged) count += 1;
    }
    return count;
}

pub fn status(self: *Board) Status {
    if (self.exploded != null) return .lost;
    var count: usize = 0;
    for (self.cells) |c| {
        if (c.contents == .bomb and c.state != .flagged) count += 1;
    }
    if (count == 0) return .won;
    return .playing;
}
