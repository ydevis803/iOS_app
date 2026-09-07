import Foundation

/// Finds a printed expiry date inside text recognized from a label.
///
/// Handles the layouts commonly stamped on packaging: numeric dates with `/`, `.`
/// or `-` separators and two- or four-digit years, ISO `YYYY-MM-DD`, month names
/// in either order (`14 SEP 2026`, `SEP 14, 2026`, `14SEP26`), and month-only
/// stamps (`09/2026`, `SEP 2026`) which resolve to the last day of that month.
/// Day/month order for ambiguous numeric dates follows the locale, falling back
/// to the other order when the first reading is not a real date.
struct ExpiryDateParser {
    private let calendar: Calendar
    private let today: Date
    private let monthFirst: Bool

    /// Dates older than a year are not expiry dates (they are lot codes or
    /// packing dates); anything more than ten years out is a misread.
    private let earliestYearOffset = -1
    private let latestYearOffset = 10

    init(today: Date = Date(), locale: Locale = .current, calendar: Calendar = .current) {
        self.today = today
        self.calendar = calendar
        let template = DateFormatter.dateFormat(fromTemplate: "MMdd", options: 0, locale: locale) ?? "MM/dd"
        let monthIndex = template.firstIndex(of: "M") ?? template.startIndex
        let dayIndex = template.firstIndex(of: "d") ?? template.endIndex
        monthFirst = monthIndex < dayIndex
    }

    /// The plausible expiry date that appears earliest in `text`, or `nil`.
    /// Labels print the best-before date ahead of lot codes, so text order beats
    /// pattern order when several dates are present.
    func date(in text: String) -> Date? {
        let upper = text.uppercased()
        var best: (location: Int, date: Date)?
        for pattern in Self.patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern.regex) else { continue }
            let range = NSRange(upper.startIndex..., in: upper)
            for match in regex.matches(in: upper, range: range) {
                let groups = (1..<match.numberOfRanges).compactMap { index -> String? in
                    guard let r = Range(match.range(at: index), in: upper) else { return nil }
                    return String(upper[r])
                }
                guard let date = pattern.build(groups, self) else { continue }
                if best == nil || match.range.location < best!.location {
                    best = (match.range.location, date)
                }
            }
        }
        return best?.date
    }

    // MARK: - Patterns

    private struct Pattern {
        let regex: String
        let build: ([String], ExpiryDateParser) -> Date?
    }

    private static let patterns: [Pattern] = [
        // 2026-09-14 / 2026.09.14 / 2026/9/14
        Pattern(regex: #"\b(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b"#) { g, p in
            p.makeDate(year: g[0], month: Int(g[1]), day: Int(g[2]))
        },
        // 14 SEP 2026 / 14SEP26 / 14-SEP-26 / 14 September 2026
        Pattern(regex: #"\b(\d{1,2})\s*[-/. ]?\s*([A-Z]{3,9})\.?\s*[-/. ]?\s*(\d{4}|\d{2})\b"#) { g, p in
            p.makeDate(year: g[2], month: p.month(named: g[1]), day: Int(g[0]))
        },
        // SEP 14 2026 / SEP 14, 26 / September 14 2026 — a separator is required
        // between day and year so "FEB 2028" cannot be read as FEB 20 '28.
        Pattern(regex: #"\b([A-Z]{3,9})\.?\s*(\d{1,2})(?:,\s*|\s+)(\d{4}|\d{2})\b"#) { g, p in
            p.makeDate(year: g[2], month: p.month(named: g[0]), day: Int(g[1]))
        },
        // 14/09/2026 / 09-14-26 / 14.09.26 (locale decides the order, then the other order)
        Pattern(regex: #"\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})\b"#) { g, p in
            guard let a = Int(g[0]), let b = Int(g[1]) else { return nil }
            let orders = p.monthFirst ? [(a, b), (b, a)] : [(b, a), (a, b)]
            for (month, day) in orders {
                if let date = p.makeDate(year: g[2], month: month, day: day) { return date }
            }
            return nil
        },
        // 09/2026 → last day of the month (not the tail of a full date)
        Pattern(regex: #"(?<![\d/.-])\b(\d{1,2})[-/.](20\d{2})\b"#) { g, p in
            p.makeEndOfMonth(year: g[1], month: Int(g[0]))
        },
        // SEP 2026 / SEPT-2026 → last day of the month (not the tail of "31 FEB 2027")
        Pattern(regex: #"(?<!\d\s)(?<!\d)(?<!\d-)\b([A-Z]{3,9})\.?\s*[-/ ]?\s*(20\d{2})\b"#) { g, p in
            p.makeEndOfMonth(year: g[1], month: p.month(named: g[0]))
        }
    ]

    // MARK: - Helpers

    private static let monthNames = [
        "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
        "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
    ]

    /// Month number for an abbreviation or full name (`SEP`, `SEPT`, `SEPTEMBER`).
    private func month(named name: String) -> Int? {
        let key = name == "SEPT" ? "SEP" : name
        guard key.count >= 3 else { return nil }
        return Self.monthNames.firstIndex { $0.hasPrefix(key) }.map { $0 + 1 }
    }

    private func parseYear(_ text: String) -> Int? {
        guard let value = Int(text) else { return nil }
        return text.count == 2 ? 2000 + value : value
    }

    private func makeDate(year yearText: String, month: Int?, day: Int?) -> Date? {
        guard let year = parseYear(yearText), let month, let day,
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == day else { return nil } // rejects 31 Feb
        return isPlausible(date) ? date : nil
    }

    private func makeEndOfMonth(year yearText: String, month: Int?) -> Date? {
        guard let year = parseYear(yearText), let month, (1...12).contains(month),
              let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: first),
              let last = calendar.date(byAdding: .day, value: range.count - 1, to: first) else { return nil }
        return isPlausible(last) ? last : nil
    }

    private func isPlausible(_ date: Date) -> Bool {
        guard let earliest = calendar.date(byAdding: .year, value: earliestYearOffset, to: today),
              let latest = calendar.date(byAdding: .year, value: latestYearOffset, to: today) else { return false }
        return date >= calendar.startOfDay(for: earliest) && date <= latest
    }
}
