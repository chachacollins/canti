const value = @import("value.zig");
const vm = @import("vm.zig");
const std = @import("std");
const obj = @This();

type: ObjType,
next: ?*obj,

const ObjType = enum {
    OBJ_STRING,
};

pub inline fn OBJ_TYPE(v: value.Value) ObjType {
    return value.as_obj(v).type;
}

pub inline fn IS_OBJ_TYPE(v: value.Value, comptime type_: ObjType) bool {
    return value.is_obj(v) and value.as_obj(v).type == type_;
}

pub inline fn IS_STRING(v: value.Value) bool {
    return IS_OBJ_TYPE(v, .OBJ_STRING);
}
pub inline fn AS_STRING(v: value.Value) *ObjString {
    std.debug.assert(IS_STRING(v));
    return @alignCast(@fieldParentPtr("obj", v.value.obj));
}
pub inline fn AS_CSTRING(v: value.Value) []const u8 {
    return AS_STRING(v).chars;
}

pub const ObjString = struct {
    obj: obj,
    chars: []const u8,
};

pub fn allocateString(chars: []const u8, allocator: std.mem.Allocator) *ObjString {
    const string = ALLOCATE_OBJ(ObjString, .OBJ_STRING, allocator);
    string.chars = allocator.dupe(u8, chars) catch unreachable;
    return string;
}

pub fn ALLOCATE_OBJ(comptime T: type, comptime obj_type: ObjType, allocator: std.mem.Allocator) *T {
    comptime {
        if (!@hasField(T, "obj")) {
            @compileError(std.fmt.comptimePrint("Type {s} has no field obj", .{@typeName(T)}));
        }
        if (@TypeOf(@field(@as(T, undefined), "obj")) != obj) {
            @compileError(std.fmt.comptimePrint("Type {s} has obj field not of type Object", .{@typeName(T)}));
        }
    }
    const object = allocator.create(T) catch undefined;
    object.obj.type = obj_type;
    object.obj.next = vm.vm.objects;
    vm.vm.objects = &object.obj;
    return object;
}
