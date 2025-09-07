const std = @import("std");
const time = @import("time.zig");

pub fn main() !void {
    const year = 2025;

    const first_sunday = FirstSundayOfYear(year);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("{d}\n", .{first_sunday.days});

    std.debug.print("{s}", .{"!!!!!\n"});
    var current_sunday = first_sunday;
    for (0..53) |i| {
        std.debug.print("{d}\n", .{i});
        const months = MonthsForWeekBeginningWith(current_sunday);
        try stdout.print("{d}", .{months.first_month});
        if (months.second_month) |second_month| {
            try stdout.print(" | {d}", .{second_month});
        }
        try stdout.print("\n", .{});
        current_sunday = current_sunday.addDays(7);
        try stdout.flush();
    }

    try stdout.flush();
}

fn FirstSundayOfYear(year: u16) time.DateTime {
    var sunday_year = year;
    var sunday_month: u16 = undefined;
    var sunday_day: u16 = undefined;

    // The first week of the year always contains January 4
    const first_jan_4 = time.DateTime.init(year, 0, 3, 0, 0, 0);
    const first_jan_4_weekday = first_jan_4.weekday();

    if (first_jan_4_weekday == time.WeekDay.Sun) {
        sunday_day = 3;
        sunday_month = 0;
    } else if (first_jan_4_weekday == time.WeekDay.Mon) {
        sunday_day = 2;
        sunday_month = 0;
    } else if (first_jan_4_weekday == time.WeekDay.Tue) {
        sunday_day = 1;
        sunday_month = 0;
    } else if (first_jan_4_weekday == time.WeekDay.Wed) {
        sunday_day = 0;
        sunday_month = 0;
    } else if (first_jan_4_weekday == time.WeekDay.Thu) {
        sunday_day = 30;
        sunday_month = 11;
        sunday_year -= 1;
    } else if (first_jan_4_weekday == time.WeekDay.Fri) {
        sunday_day = 29;
        sunday_month = 11;
        sunday_year -= 1;
    } else if (first_jan_4_weekday == time.WeekDay.Sat) {
        sunday_day = 28;
        sunday_month = 11;
        sunday_year -= 1;
    } else {
        unreachable;
    }

    return time.DateTime.init(sunday_year, sunday_month, sunday_day, 0, 0, 0);
}

const MonthPair = struct { first_month: u16, second_month: ?u16 = null };

fn MonthsForWeekBeginningWith(sunday: time.DateTime) MonthPair {
    const saturday = sunday.addDays(6);
    const first_month = sunday.months;
    const second_month = saturday.months;
    if (first_month == second_month) {
        return MonthPair{ .first_month = first_month };
    } else {
        return MonthPair{ .first_month = first_month, .second_month = second_month };
    }
}

test "Single Month" {
    const months = MonthsForWeekBeginningWith(time.DateTime.init(2025, 8, 6, 0, 0, 0));

    try std.testing.expectEqual(@as(u16, 8), months.first_month);
    try std.testing.expectEqual(null, months.second_month);
}

test "Double Month" {
    const months = MonthsForWeekBeginningWith(time.DateTime.init(2025, 7, 30, 0, 0, 0));

    try std.testing.expectEqual(@as(u16, 7), months.first_month);
    try std.testing.expectEqual(@as(u16, 8), months.second_month);
}

test "First Sunday 2025" {
    const months = MonthsForWeekBeginningWith(time.DateTime.init(2024, 11, 28, 0, 0, 0));

    try std.testing.expectEqual(@as(u16, 11), months.first_month);
    try std.testing.expectEqual(@as(u16, 0), months.second_month);
}
