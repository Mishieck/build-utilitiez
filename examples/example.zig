const std = @import("std");
const build_utilitiez = @import("build_utilitiez");

pub fn main() !void {
    try build_utilitiez.bufferedPrint();
}
