const vaxis = @import("vaxis");

pub const Event = union(enum) {
    key_press: vaxis.Key,
    mouse: vaxis.Mouse,
    color_scheme: vaxis.Color.Scheme,
    winsize: vaxis.Winsize,
};
