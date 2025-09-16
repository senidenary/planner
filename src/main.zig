const std = @import("std");
const date = @import("date.zig");

pub fn main() !void {
    const year = 2025;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const first_sunday = FirstSundayOfYear(year);

    var current_sunday = first_sunday;
    for (1..54) |i| {
        try stdout.print("{d}: ", .{i});
        const months = MonthsForWeekBeginningWith(current_sunday);
        try stdout.print("{d}", .{months.first_month});
        if (months.second_month) |second_month| {
            try stdout.print(" | {d}", .{second_month});
        }
        try stdout.print("\n", .{});
        current_sunday = current_sunday.addDays(7);
    }

    try stdout.flush();
}

fn FirstSundayOfYear(year: u16) date.Date {
    // The first week of the year always contains January 4
    const first_jan_4 = date.Date.init(year, 1, 4);
    const first_jan_4_weekday = first_jan_4.weekday();

    return first_jan_4.subtractDays(@intFromEnum(first_jan_4_weekday));
}

test "First Sunday 2025" {
    try std.testing.expectEqual(date.Date.init(2023, 1, 1), FirstSundayOfYear(2023));
    try std.testing.expectEqual(date.Date.init(2023, 12, 31), FirstSundayOfYear(2024));
    try std.testing.expectEqual(date.Date.init(2024, 12, 29), FirstSundayOfYear(2025));
    try std.testing.expectEqual(date.Date.init(2026, 1, 4), FirstSundayOfYear(2026));
}

const MonthPair = struct { first_month: u16, second_month: ?u16 = null };

fn MonthsForWeekBeginningWith(sunday: date.Date) MonthPair {
    const saturday = sunday.addDays(6);
    const first_month = sunday.month;
    const second_month = saturday.month;
    if (first_month == second_month) {
        return MonthPair{ .first_month = first_month };
    } else {
        return MonthPair{ .first_month = first_month, .second_month = second_month };
    }
}

test "MonthsForWeekBeginningWith" {
    const single_month = MonthsForWeekBeginningWith(date.Date.init(2025, 9, 7));

    try std.testing.expectEqual(@as(u16, 9), single_month.first_month);
    try std.testing.expectEqual(null, single_month.second_month);

    const double_month = MonthsForWeekBeginningWith(date.Date.init(2025, 8, 31));

    try std.testing.expectEqual(@as(u16, 8), double_month.first_month);
    try std.testing.expectEqual(@as(u16, 9), double_month.second_month);
}
