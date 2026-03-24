const std = @import("std");
const date = @import("date.zig");

pub fn main() !void {
    const input_filename = "weekly.plan.3.fodg";
    const year = 2026;

    const config: std.heap.GeneralPurposeAllocatorConfig = .{
        .thread_safe = false,
    };
    var gpa = std.heap.GeneralPurposeAllocator(config){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const cwd = std.fs.cwd();
    const max_file_size = 1024 * 1024 * 1024; // 1 GiB
    const input_buffer = try cwd.readFileAlloc(allocator, input_filename, max_file_size);
    defer allocator.free(input_buffer);

    const out_dir_name = "out_files";
    cwd.makeDir(out_dir_name) catch |err| {
        std.debug.assert(err == std.posix.MakeDirError.PathAlreadyExists);
    };
    const out_dir = try cwd.openDir(out_dir_name, .{});

    const output_buffer = try allocator.alloc(u8, input_buffer.len);
    defer allocator.free(output_buffer);

    const first_sunday = FirstSundayOfYear(year);

    var current_date = first_sunday;
    for (1..54) |i| {
        var sub_set = try AllocSubstitutions(allocator, current_date, @intCast(i));
        defer sub_set.deinit();

        const output = PerformSubstitutions(input_buffer, output_buffer, sub_set.substitutions);

        const out_filename = try std.fmt.allocPrint(allocator, "out_{d:0>2}.fodg", .{i});
        defer allocator.free(out_filename);

        const out_file = try out_dir.createFile(out_filename, .{});
        defer out_file.close();

        _ = try out_file.write(output);

        current_date = current_date.addDays(7);
    }
}

const Substitution = struct {
    allocator: ?std.mem.Allocator,
    from: []const u8,
    to: []const u8,
    to_buffer: []const u8,

    /// Takes ownership of `to_buffer`.
    pub fn initOwned(allocator: std.mem.Allocator, from: []const u8, to_buffer: []const u8, to_length: usize) Substitution {
        const substitution = Substitution{
            .allocator = allocator,
            .from = from,
            .to = to_buffer[0..to_length],
            .to_buffer = to_buffer,
        };

        return substitution;
    }

    pub fn initBorrowed(from: []const u8, to: []const u8) Substitution {
        const substitution = Substitution{
            .allocator = null,
            .from = from,
            .to = to,
            .to_buffer = to,
        };

        return substitution;
    }

    pub fn deinit(self: *Substitution) void {
        if (self.allocator) |*a| {
            a.free(self.to_buffer);
        }
    }
};

const SubstitutionSet = struct {
    allocator: std.mem.Allocator,
    substitutions: []Substitution,

    pub fn deinit(self: *SubstitutionSet) void {
        for (self.substitutions) |*s| {
            s.deinit();
        }

        self.allocator.free(self.substitutions);
    }
};

fn AllocSubstitutions(allocator: std.mem.Allocator, first_sunday: date.Date, week_number: u8) !SubstitutionSet {
    var subs = try allocator.alloc(Substitution, 8);

    const months = MonthsForWeekBeginningWith(first_sunday);
    const week_year = first_sunday.addDays(4).year; // The week is considered to be in whichever year Thursday falls on
    const year_week_month_buffer = try allocator.alloc(u8, 128);

    const initial_slice = try std.fmt.bufPrint(year_week_month_buffer, "{d}-W{d} [ {s} ", .{ week_year, week_number, @tagName(months.first_month) });
    var year_week_month_buffer_len = initial_slice.len;
    if (months.second_month) |second_month| {
        const second_slice = try std.fmt.bufPrint(year_week_month_buffer[year_week_month_buffer_len..], "| {s} ]", .{@tagName(second_month)});
        year_week_month_buffer_len += second_slice.len;
    } else {
        const second_slice = try std.fmt.bufPrint(year_week_month_buffer[year_week_month_buffer_len..], "]", .{});
        year_week_month_buffer_len += second_slice.len;
    }
    const year_week_month = "^^YearWeekMonthWithEnoughPaddingToCoverReallyLongMonthNames";
    std.debug.assert(year_week_month.len > year_week_month_buffer_len);
    subs[0] = Substitution.initOwned(allocator, year_week_month, year_week_month_buffer, year_week_month_buffer_len);

    var current_day = first_sunday;
    const tags = [_][]const u8{ "^^Sunday", "^^Monday", "^^Tuesday", "^^Wednesday", "^^Thursday", "^^Friday", "^^Saturday" };
    for (tags, 1..8) |t, i| {
        const buffer = try std.fmt.allocPrint(allocator, "{d}", .{current_day.day});
        std.debug.assert(t.len > buffer.len);
        subs[i] = Substitution.initOwned(allocator, t, buffer, buffer.len);
        current_day = current_day.addDays(1);
    }

    return SubstitutionSet{ .allocator = allocator, .substitutions = subs };
}

test "AllocSubstitutions" {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var sub_set = try AllocSubstitutions(allocator, FirstSundayOfYear(2025), 1);
    defer sub_set.deinit();

    try std.testing.expectEqualStrings("2025-W1 [ December | January ]", sub_set.substitutions[0].to);
    try std.testing.expectEqualStrings("29", sub_set.substitutions[1].to);
    try std.testing.expectEqualStrings("30", sub_set.substitutions[2].to);
    try std.testing.expectEqualStrings("31", sub_set.substitutions[3].to);
    try std.testing.expectEqualStrings("1", sub_set.substitutions[4].to);
    try std.testing.expectEqualStrings("2", sub_set.substitutions[5].to);
    try std.testing.expectEqualStrings("3", sub_set.substitutions[6].to);
    try std.testing.expectEqualStrings("4", sub_set.substitutions[7].to);

    // Special case where the first Sunday is the 4th
    var sub_set2 = try AllocSubstitutions(allocator, FirstSundayOfYear(2026), 1);
    defer sub_set2.deinit();

    try std.testing.expectEqualStrings("2026-W1 [ December | January ]", sub_set2.substitutions[0].to);
    try std.testing.expectEqualStrings("28", sub_set2.substitutions[1].to);
    try std.testing.expectEqualStrings("29", sub_set2.substitutions[2].to);
    try std.testing.expectEqualStrings("30", sub_set2.substitutions[3].to);
    try std.testing.expectEqualStrings("31", sub_set2.substitutions[4].to);
    try std.testing.expectEqualStrings("1", sub_set2.substitutions[5].to);
    try std.testing.expectEqualStrings("2", sub_set2.substitutions[6].to);
    try std.testing.expectEqualStrings("3", sub_set2.substitutions[7].to);

    var sub_set3 = try AllocSubstitutions(allocator, date.Date{ .year = 2026, .month = 3, .day = 29 }, 14);
    defer sub_set3.deinit();

    try std.testing.expectEqualStrings("2026-W14 [ March | April ]", sub_set3.substitutions[0].to);
    try std.testing.expectEqualStrings("29", sub_set3.substitutions[1].to);
    try std.testing.expectEqualStrings("30", sub_set3.substitutions[2].to);
    try std.testing.expectEqualStrings("31", sub_set3.substitutions[3].to);
    try std.testing.expectEqualStrings("1", sub_set3.substitutions[4].to);
    try std.testing.expectEqualStrings("2", sub_set3.substitutions[5].to);
    try std.testing.expectEqualStrings("3", sub_set3.substitutions[6].to);
    try std.testing.expectEqualStrings("4", sub_set3.substitutions[7].to);
}

/// returns the valid slice of `output_buffer`.
fn PerformSubstitutions(input_buffer: []const u8, output_buffer: []u8, substitutions: []const Substitution) []u8 {
    @memcpy(output_buffer, input_buffer);
    var output_length = output_buffer.len;
    for (substitutions) |s| {
        const replacements = std.mem.replace(u8, output_buffer, s.from, s.to, output_buffer);
        output_length -= (s.from.len - s.to.len) * replacements;
    }
    return output_buffer[0..output_length];
}

test "PerformSubstitutions" {
    var gpa = std.heap.DebugAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var substitutions: [2]Substitution = undefined;
    substitutions[0] = Substitution.initBorrowed("^^Sunday", "0");
    defer substitutions[0].deinit(); // Unnecessary but harmless
    substitutions[1] = Substitution.initBorrowed("^^Monday", "1");

    const input_buffer = "abc^^Sundaydef^^Mondayghi";
    const output_buffer = try allocator.alloc(u8, input_buffer.len);
    defer allocator.free(output_buffer);

    const output = PerformSubstitutions(input_buffer, output_buffer, &substitutions);

    try std.testing.expectEqualStrings("abc0def1ghi", output);
}

fn FirstSundayOfYear(year: u16) date.Date {
    // The first week of the year always contains January 4
    const first_jan_4 = date.Date.init(year, 1, 4);
    const first_jan_4_weekday = first_jan_4.weekday();

    if (first_jan_4_weekday == date.Weekday.Sun) {
        return first_jan_4.subtractDays(7);
    } else {
        return first_jan_4.subtractDays(@intFromEnum(first_jan_4_weekday));
    }
}

test "FirstSundayOfYear" {
    try std.testing.expectEqual(date.Date.init(2023, 1, 1), FirstSundayOfYear(2023));
    try std.testing.expectEqual(date.Date.init(2023, 12, 31), FirstSundayOfYear(2024));
    try std.testing.expectEqual(date.Date.init(2024, 12, 29), FirstSundayOfYear(2025));
    try std.testing.expectEqual(date.Date.init(2025, 12, 28), FirstSundayOfYear(2026));
}

const MonthPair = struct { first_month: date.Month, second_month: ?date.Month = null };

fn MonthsForWeekBeginningWith(sunday: date.Date) MonthPair {
    const saturday = sunday.addDays(6);
    const first_month = sunday.month;
    const second_month = saturday.month;
    if (first_month == second_month) {
        return MonthPair{ .first_month = @enumFromInt(first_month) };
    } else {
        return MonthPair{ .first_month = @enumFromInt(first_month), .second_month = @enumFromInt(second_month) };
    }
}

test "MonthsForWeekBeginningWith" {
    const single_month = MonthsForWeekBeginningWith(date.Date.init(2025, 9, 7));

    try std.testing.expectEqual(date.Month.September, single_month.first_month);
    try std.testing.expectEqual(null, single_month.second_month);

    const double_month = MonthsForWeekBeginningWith(date.Date.init(2025, 8, 31));

    try std.testing.expectEqual(date.Month.August, double_month.first_month);
    try std.testing.expectEqual(date.Month.September, double_month.second_month);
}
