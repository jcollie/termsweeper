const std = @import("std");
const builtin = @import("builtin");

const vaxis = @import("vaxis");
const xev = @import("xev");

const Board = @import("Board.zig");
const Event = @import("event.zig").Event;
const Point = @import("Point.zig");
const TermSweeper = @import("TermSweeper.zig");
const titles = @import("titles.zig");
const TTYWatcher = @import("ttywatcher.zig").TTYWatcher;

pub const panic = vaxis.panic_handler;
pub const std_options: std.Options = .{
    .log_scope_levels = &.{
        .{ .scope = .vaxis, .level = .warn },
        .{ .scope = .vaxis_parser, .level = .warn },
        .{ .scope = .ttywatcher, .level = .warn },
    },
};

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const alloc, const is_debug = allocator: {
        break :allocator switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var tty = try vaxis.Tty.init();
    defer tty.deinit();

    var vx = try vaxis.init(alloc, .{});
    defer vx.deinit(alloc, tty.anyWriter());

    var pool = xev.ThreadPool.init(.{});
    var loop = try xev.Loop.init(.{
        .thread_pool = &pool,
    });
    defer loop.deinit();

    var app: TermSweeper = undefined;
    try app.init(alloc, &tty, &vx);
    defer app.deinit();

    var vx_loop: TTYWatcher(TermSweeper) = undefined;
    try vx_loop.init(&tty, &vx, &loop, &app, eventCallback);

    try vx.enterAltScreen(tty.anyWriter());
    try vx.queryTerminalSend(tty.anyWriter());
    try vx.setMouseMode(tty.anyWriter(), true);

    const ws = try vaxis.Tty.getWinsize(tty.fd);
    try vx.resize(alloc, tty.anyWriter(), ws);
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
    watcher: *TTYWatcher(TermSweeper),
    event: Event,
) xev.CallbackAction {
    const app = ud orelse unreachable;
    switch (event) {
        .winsize => |ws| {
            watcher.vx.resize(app.alloc, watcher.tty.anyWriter(), ws) catch @panic("TODO");
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
