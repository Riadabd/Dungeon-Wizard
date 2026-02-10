const std = @import("std");
const assert = std.debug.assert;
const utl = @import("util.zig");

pub const Platform = @import("raylib.zig");
const core = @import("core.zig");
const Error = core.Error;
const Key = core.Key;
const draw = @import("draw.zig");
const Colorf = draw.Colorf;
const geom = @import("geometry.zig");
const V2f = @import("V2f.zig");
const v2f = V2f.v2f;
const V2i = @import("V2i.zig");
const v2i = V2i.v2i;

const ImmUI = @This();
const App = @import("App.zig");
const getPlat = App.getPlat;

pub fn initLabel(str: []const u8) Command.LabelString {
    return Command.LabelString.fromSlice(str) catch {
        var ret = Command.LabelString{};
        ret.len = ret.buffer.len;
        @memcpy(&ret.buffer, str[0..ret.len]);
        return ret;
    };
}

pub const Command = union(enum) {
    pub const LabelString = utl.BoundedString(128);
    pub const Panel = struct {
        // init
        center_pos: V2f = .{},
        padding: V2f = .{},
        v_spacing: f32 = 0,
        opt: draw.PolyOpt = .{},
        // running
        curr_pos: V2f = .{},
        pos: V2f = .{},
        dims: V2f = .{},
    };

    rect: struct {
        pos: V2f,
        z: f32 = 0,
        dims: V2f,
        opt: draw.PolyOpt,
        pub fn render(self: *const @This()) Error!void {
            const plat = getPlat();
            plat.rectf(self.pos, self.dims, self.opt);
        }
    },
    sector: struct {
        pos: V2f,
        z: f32 = 0,
        radius: f32,
        start_ang_rads: f32,
        end_ang_rads: f32,
        opt: draw.PolyOpt,
        pub fn render(self: *const @This()) Error!void {
            const plat = getPlat();
            plat.sectorf(self.pos, self.radius, self.start_ang_rads, self.end_ang_rads, self.opt);
        }
    },
    circle: struct {
        pos: V2f,
        z: f32 = 0,
        radius: f32,
        opt: draw.PolyOpt,
        pub fn render(self: *const @This()) Error!void {
            const plat = getPlat();
            plat.circlef(self.pos, self.radius, self.opt);
        }
    },
    triangle: struct {
        points: [3]V2f,
        z: f32 = 0,
        opt: draw.PolyOpt,
        pub fn render(self: *const @This()) Error!void {
            const plat = getPlat();
            plat.trianglef(self.points, self.opt);
        }
    },
    label: struct {
        pos: V2f,
        z: f32 = 0,
        text: LabelString,
        opt: draw.TextOpt,
        pub fn render(self: *const @This()) Error!void {
            const plat = getPlat();
            try plat.textf(self.pos, "{s}", .{self.text.constSlice()}, self.opt);
        }
    },
    texture: struct {
        pos: V2f,
        z: f32 = 0,
        texture: Platform.Texture2D,
        opt: draw.TextureOpt,
        pub fn render(self: *const @This()) Error!void {
            const plat = getPlat();
            plat.texturef(self.pos, self.texture, self.opt);
        }
    },
};

pub const CmdBuf = struct {
    buffer: [512]Command = undefined,
    len: usize = 0,

    fn asList(self: *CmdBuf) std.ArrayList(Command) {
        var list = std.ArrayList(Command).initBuffer(self.buffer[0..]);
        list.items.len = self.len;
        return list;
    }

    pub fn clear(self: *CmdBuf) void {
        self.len = 0;
    }

    pub fn append(self: *CmdBuf, item: Command) error{Overflow}!void {
        var list = self.asList();
        list.appendBounded(item) catch return error.Overflow;
        self.len = list.items.len;
    }

    pub fn appendAssumeCapacity(self: *CmdBuf, item: Command) void {
        var list = self.asList();
        list.appendAssumeCapacity(item);
        self.len = list.items.len;
    }

    pub fn slice(self: *CmdBuf) []Command {
        return self.buffer[0..self.len];
    }

    pub fn constSlice(self: *const CmdBuf) []const Command {
        return self.buffer[0..self.len];
    }
};

pub fn render(cmd_buf: *const CmdBuf) Error!void {
    const SortZ = struct {
        fn lessThanFn(_: void, lhs: Command, rhs: Command) bool {
            return switch (lhs) {
                inline else => |a| switch (rhs) {
                    inline else => |b| a.z < b.z,
                },
            };
        }
    };
    std.sort.block(Command, @constCast(cmd_buf).slice(), {}, SortZ.lessThanFn);
    for (cmd_buf.slice()) |*command| {
        switch (command.*) {
            inline else => |*c| {
                const C = @TypeOf(c.*);
                if (std.meta.hasMethod(C, "render")) {
                    try C.render(c);
                }
            },
        }
    }
}
