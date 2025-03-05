const std = @import("std");

pub const ValueType = enum {
    //zls
    VAL_BOOL,
    VAL_NIL,
    VAL_NUMBER,
};

const ValueTag = union(enum) {
    boolean: bool,
    number: f64,
};

pub const Value = struct {
    type: ValueType,
    value: ValueTag,
};

//TODO: REFACTOR THIS

pub fn bool_value(value: bool) Value {
    return .{
        .type = .VAL_BOOL,
        .value = .{ .boolean = value },
    };
}
pub fn nill_value() Value {
    return .{
        .type = .VAL_NIL,
        .value = .{ .number = 0 },
    };
}
pub fn number_value(number: f64) Value {
    return .{
        .type = .VAL_NUMBER,
        .value = .{ .number = number },
    };
}

pub fn as_bool(value: Value) bool {
    return value.value.boolean;
}
pub fn as_number(value: Value) f64 {
    return value.value.number;
}

pub fn is_number(value: Value) bool {
    if (value.type == .VAL_NUMBER) {
        return true;
    }
    return false;
}
pub fn is_bool(value: Value) bool {
    if (value.type == .VAL_BOOL) {
        return true;
    }
    return false;
}
pub fn is_nil(value: Value) bool {
    if (value.type == .VAL_NIL) {
        return true;
    }
    return false;
}

pub const ValueArray = struct {
    values: std.ArrayList(Value),
    pub fn init(allocator: std.mem.Allocator) ValueArray {
        return ValueArray{
            .values = std.ArrayList(Value).init(allocator),
        };
    }
    pub fn writeValue(self: *ValueArray, value: Value) !void {
        try self.values.append(value);
    }
    pub fn deinit(self: *ValueArray) void {
        self.values.deinit();
    }
};

pub fn valuesEqual(a: Value, b: Value) bool {
    if (a.type != b.type) return false;

    switch (a.type) {
        .VAL_BOOL => return as_bool(a) == as_bool(b),
        .VAL_NIL => return true,
        .VAL_NUMBER => return as_number(a) == as_number(b),
    }
}

pub fn printValue(value: Value, stdout: anytype) !void {
    switch (value.type) {
        .VAL_BOOL => try stdout.print("{}", .{value.value.boolean}),
        .VAL_NUMBER => try stdout.print("{d}", .{value.value.number}),
        .VAL_NIL => try stdout.print("nil", .{}),
    }
}
