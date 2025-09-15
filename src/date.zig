const std = @import("std");
const string = []const u8;
const date = @This();

pub const Date = struct {
    year: u16,
    month: u8,
    day: u8,

    pub fn init(year: u16, month: u8, day: u8) Date {
        return Date{
            .year = year,
            .month = month,
            .day = day,
        };
    }

    pub fn weekday(self: Date) Weekday {
        var i = self.daysSinceEpoch() % 7;
        var result = Weekday.Thu; // weekday of epoch_unix
        while (i > 0) : (i -= 1) {
            result = result.next();
        }
        return result;
    }

    test "weekday" {
        try std.testing.expectEqual(date.Weekday.Mon, Date.init(2025, 9, 8).weekday());
    }

    pub fn addYears(self: Date, count: u16) Date {
        if (count == 0) return self;
        var result = self;
        result.year += count;

        return result.roundDays();
    }

    pub fn addMonths(self: Date, count: u16) Date {
        if (count == 0) return self;
        var result = self;
        const years = std.math.divFloor(u16, count, 12) catch unreachable;
        const months = std.math.rem(u16, count, 12) catch unreachable;

        result.year += years;
        result.month += @intCast(months);

        return result.roundDays();
    }

    test "addMonths" {
        const d = Date.init(2025, 1, 31);

        try std.testing.expectEqual(Date.init(2025, 2, 28), d.addMonths(1));
        try std.testing.expectEqual(Date.init(2025, 3, 31), d.addMonths(2));
        try std.testing.expectEqual(Date.init(2026, 1, 31), d.addMonths(12));
    }

    pub fn addDays(self: Date, count: u64) Date {
        if (count == 0) return self;

        // Pretend the result's day is 1 and then count back to where
        // it was, so that we can skip through months more easily
        var result = self;
        var days_remaining = count + self.day;

        while (true) {
            const month_len = result.daysThisMonth();
            if (days_remaining >= month_len) {
                result.month += 1;
                days_remaining -= month_len;

                if (result.month == 13) {
                    result.year += 1;
                    result.month = 1;
                }
                continue;
            }
            break;
        }

        result.day = @intCast(days_remaining);

        return result;
    }

    test "addDays" {
        const d = Date.init(2025, 1, 1);
        try std.testing.expectEqual(Date.init(2025, 1, 2), d.addDays(1));
        try std.testing.expectEqual(Date.init(2025, 2, 1), d.addDays(31));
        try std.testing.expectEqual(Date.init(2026, 1, 1), d.addDays(365));

        const d2 = Date.init(2024, 12, 31);
        try std.testing.expectEqual(Date.init(2025, 1, 1), d2.addDays(1));

        const d3 = Date.init(2024, 11, 15);
        try std.testing.expectEqual(Date.init(2025, 2, 10), d3.addDays(87));
    }

    pub fn subtractDays(self: Date, count: u64) Date {
        if (count == 0) return self;
        var result = self;
        // Pretend we're working from the last day of the month,
        // so we can skip back through the months more easily
        var days_remaining = count + (result.daysThisMonth() - self.day);

        while (true) {
            const month_len = result.daysThisMonth();
            if (days_remaining >= month_len) {
                result.month -= 1;
                days_remaining -= month_len;
                if (result.month == 0) {
                    result.year -= 1;
                    result.month = 12;
                }
                continue;
            }
            break;
        }

        result.day = @intCast(result.daysThisMonth() - days_remaining);

        return result;
    }

    test "subtractDays" {
        const d = Date.init(2025, 12, 31);
        try std.testing.expectEqual(Date.init(2025, 12, 30), d.subtractDays(1));
        try std.testing.expectEqual(Date.init(2025, 11, 30), d.subtractDays(31));
        try std.testing.expectEqual(Date.init(2024, 12, 31), d.subtractDays(365));

        const d2 = Date.init(2025, 1, 1);
        try std.testing.expectEqual(Date.init(2024, 12, 31), d2.subtractDays(1));

        const d3 = Date.init(2025, 2, 10);
        try std.testing.expectEqual(Date.init(2024, 11, 15), d3.subtractDays(87));
    }

    pub fn isLeapYear(self: Date) bool {
        return date.isLeapYear(self.year);
    }

    pub fn daysThisYear(self: Date) u16 {
        return date.daysInYear(self.year);
    }

    pub fn daysThisMonth(self: Date) u8 {
        return date.daysInMonth(self.year, self.month);
    }

    fn roundDays(self: Date) Date {
        const days_this_month = self.daysThisMonth();
        if (self.day > days_this_month) {
            return Date.init(self.year, self.month, days_this_month);
        }
        return self;
    }

    fn daysSinceEpoch(self: Date) u64 {
        var res: u64 = 0;
        for (epoch_unix.year..self.year) |i| res += daysInYear(@intCast(i));
        for (1..self.month) |i| res += daysInMonth(self.year, @intCast(i));
        res += self.day - 1;
        return res;
    }

    test "daysSinceEpoch" {
        try std.testing.expectEqual(0, Date.init(1970, 1, 1).daysSinceEpoch());
        try std.testing.expectEqual(1, Date.init(1970, 1, 2).daysSinceEpoch());
        try std.testing.expectEqual(31, Date.init(1970, 2, 1).daysSinceEpoch());
        try std.testing.expectEqual(365, Date.init(1971, 1, 1).daysSinceEpoch());
    }

    const epoch_unix = Date{
        .day = 1,
        .month = 1,
        .year = 1970,
    };
};

test "addYears" {
    const d = Date.init(2020, 2, 29);

    try std.testing.expectEqual(2020, d.year);
    try std.testing.expectEqual(2021, d.addYears(1).year);
    try std.testing.expectEqual(2031, d.addYears(11).year);

    try std.testing.expectEqual(28, d.addYears(3).day);
    try std.testing.expectEqual(29, d.addYears(4).day);
}

pub const Weekday = enum {
    Sun,
    Mon,
    Tue,
    Wed,
    Thu,
    Fri,
    Sat,

    pub fn next(self: Weekday) Weekday {
        return switch (self) {
            .Sun => .Mon,
            .Mon => .Tue,
            .Tue => .Wed,
            .Wed => .Thu,
            .Thu => .Fri,
            .Fri => .Sat,
            .Sat => .Sun,
        };
    }
};

fn isLeapYear(year: u16) bool {
    if (year % 400 == 0) return true;
    if (year % 100 == 0) return false;
    if (year % 4 == 0) return true;
    return false;
}

test "isLeapYear" {
    try std.testing.expect(date.isLeapYear(1996));
    try std.testing.expect(date.isLeapYear(2000));
    try std.testing.expect(date.isLeapYear(2004));

    try std.testing.expect(!date.isLeapYear(1999));
    try std.testing.expect(!date.isLeapYear(2001));

    try std.testing.expect(!date.isLeapYear(1900));
}

fn daysInYear(year: u16) u16 {
    return if (date.isLeapYear(year)) 366 else 365;
}

test "daysInYear" {
    try std.testing.expectEqual(365, daysInYear(1995));
    try std.testing.expectEqual(366, daysInYear(1996));
}

fn daysInMonth(year: u16, month: u8) u8 {
    const norm = [12]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    const leap = [12]u8{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    const month_days = if (isLeapYear(year)) leap else norm;
    return month_days[month - 1];
}

test "daysInMonth" {
    try std.testing.expectEqual(daysInMonth(2025, 1), 31);
    try std.testing.expectEqual(daysInMonth(2025, 2), 28);
    try std.testing.expectEqual(daysInMonth(2024, 2), 29);
}
