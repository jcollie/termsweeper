const std = @import("std");

const vaxis = @import("vaxis");
const xev = @import("xev");

const Event = @import("event.zig").Event;

const log = std.log.scoped(.ttywatcher);

pub fn TTYWatcher(comptime Userdata: type) type {
    return struct {
        const Self = @This();

        file: xev.File,
        tty: *vaxis.Tty,

        read_buf: [4096]u8,
        read_buf_start: usize,
        read_cmp: xev.Completion,

        winsize_wakeup: xev.Async,
        winsize_cmp: xev.Completion,

        callback: *const fn (
            ud: ?*Userdata,
            loop: *xev.Loop,
            watcher: *Self,
            event: Event,
        ) xev.CallbackAction,

        ud: ?*Userdata,
        vx: *vaxis.Vaxis,
        parser: vaxis.Parser,

        pub fn init(
            self: *Self,
            tty: *vaxis.Tty,
            vx: *vaxis.Vaxis,
            loop: *xev.Loop,
            userdata: ?*Userdata,
            callback: *const fn (
                ud: ?*Userdata,
                loop: *xev.Loop,
                watcher: *Self,
                event: Event,
            ) xev.CallbackAction,
        ) !void {
            self.* = .{
                .tty = tty,
                .file = xev.File.initFd(tty.fd),
                .read_buf = undefined,
                .read_buf_start = 0,
                .read_cmp = .{},

                .winsize_wakeup = try xev.Async.init(),
                .winsize_cmp = .{},

                .callback = callback,
                .ud = userdata,
                .vx = vx,
                .parser = .{ .grapheme_data = &vx.unicode.width_data.g_data },
            };

            self.file.read(
                loop,
                &self.read_cmp,
                .{ .slice = &self.read_buf },
                Self,
                self,
                Self.ttyReadCallback,
            );
            self.winsize_wakeup.wait(
                loop,
                &self.winsize_cmp,
                Self,
                self,
                winsizeCallback,
            );
            const handler: vaxis.Tty.SignalHandler = .{
                .context = self,
                .callback = Self.signalCallback,
            };
            try vaxis.Tty.notifyWinsize(handler);
        }

        fn signalCallback(ptr: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.winsize_wakeup.notify() catch |err| {
                log.warn("couldn't wake up winsize callback: {}", .{err});
            };
        }

        fn ttyReadCallback(
            ud: ?*Self,
            loop: *xev.Loop,
            c: *xev.Completion,
            _: xev.File,
            buf: xev.ReadBuffer,
            r: xev.ReadError!usize,
        ) xev.CallbackAction {
            const n = r catch |err| {
                log.err("read error: {}", .{err});
                return .disarm;
            };
            const self = ud orelse unreachable;

            // reset read start state
            self.read_buf_start = 0;

            var seq_start: usize = 0;
            parse_loop: while (seq_start < n) {
                const result = self.parser.parse(buf.slice[seq_start..n], null) catch |err| {
                    log.err("couldn't parse input: {}", .{err});
                    return .disarm;
                };
                if (result.n == 0) {
                    // copy the read to the beginning. We don't use memcpy because
                    // this could be overlapping, and it's also rare
                    const initial_start = seq_start;
                    while (seq_start < n) : (seq_start += 1) {
                        self.read_buf[seq_start - initial_start] = self.read_buf[seq_start];
                    }
                    self.read_buf_start = seq_start - initial_start + 1;
                    return .rearm;
                }
                seq_start += n;
                const event_inner = result.event orelse {
                    log.debug("unknown event: {s}", .{self.read_buf[seq_start - n + 1 .. seq_start]});
                    continue :parse_loop;
                };

                // Capture events we want to bubble up
                const event: ?Event = switch (event_inner) {
                    .key_press => |key| .{ .key_press = key },
                    .mouse => |mouse| .{ .mouse = mouse },
                    .color_scheme => |scheme| .{ .color_scheme = scheme },
                    .winsize => |ws| .{ .winsize = ws },

                    // ignored events
                    .key_release,
                    .focus_in,
                    .focus_out,
                    .paste_start,
                    .paste_end,
                    .paste,
                    .color_report,
                    => null,

                    // capability events which we handle below
                    .cap_kitty_keyboard,
                    .cap_kitty_graphics,
                    .cap_rgb,
                    .cap_unicode,
                    .cap_sgr_pixels,
                    .cap_color_scheme_updates,
                    .cap_da1,
                    => null, // handled below
                };

                if (event) |ev| {
                    const action = self.callback(self.ud, loop, self, ev);
                    switch (action) {
                        .disarm => return .disarm,
                        else => continue :parse_loop,
                    }
                }

                switch (event_inner) {
                    // ignored
                    .key_release,
                    .focus_in,
                    .focus_out,
                    .paste_start,
                    .paste_end,
                    .paste,
                    .color_report,
                    => {},

                    .key_press,
                    .mouse,
                    .color_scheme,
                    .winsize,
                    => unreachable, // handled above

                    .cap_kitty_keyboard => {
                        self.vx.caps.kitty_keyboard = true;
                    },
                    .cap_kitty_graphics => {
                        if (!self.vx.caps.kitty_graphics) {
                            self.vx.caps.kitty_graphics = true;
                        }
                    },
                    .cap_rgb => {
                        self.vx.caps.rgb = true;
                    },
                    .cap_unicode => {
                        self.vx.caps.unicode = .unicode;
                        self.vx.screen.width_method = .unicode;
                    },
                    .cap_sgr_pixels => {
                        self.vx.caps.sgr_pixels = true;
                    },
                    .cap_color_scheme_updates => {
                        self.vx.caps.color_scheme_updates = true;
                    },
                    .cap_da1 => {
                        self.vx.enableDetectedFeatures(self.tty.anyWriter()) catch |err| {
                            log.err("couldn't enable features: {}", .{err});
                        };
                    },
                }
            }

            self.file.read(
                loop,
                c,
                .{ .slice = &self.read_buf },
                Self,
                self,
                Self.ttyReadCallback,
            );
            return .disarm;
        }

        fn winsizeCallback(
            ud: ?*Self,
            l: *xev.Loop,
            c: *xev.Completion,
            r: xev.Async.WaitError!void,
        ) xev.CallbackAction {
            _ = r catch |err| {
                log.err("async error: {}", .{err});
                return .disarm;
            };
            const self = ud orelse unreachable; // no userdata
            const winsize = vaxis.Tty.getWinsize(self.tty.fd) catch |err| {
                log.err("couldn't get winsize: {}", .{err});
                return .disarm;
            };
            const ret = self.callback(self.ud, l, self, .{ .winsize = winsize });
            if (ret == .disarm) return .disarm;

            self.winsize_wakeup.wait(
                l,
                c,
                Self,
                self,
                winsizeCallback,
            );
            return .disarm;
        }
    };
}
