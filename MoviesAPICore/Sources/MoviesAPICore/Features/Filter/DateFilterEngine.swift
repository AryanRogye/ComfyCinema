//
//  DateFilterEngine.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 11/18/26.
//

import Foundation

struct DateFilterResult {
    let interval: DateInterval
    let remainingQuery: String   // query with the date phrase removed
}

enum DateFilterEngine {

    private struct Rule {
        let phrase: String
        let interval: (Date, Calendar) -> DateInterval?
    }

    private static let rules: [Rule] = [

        /// Yesterday
        Rule(phrase: "yesterday") { now, cal in
            cal.date(byAdding: .day, value: -1, to: now).flatMap { cal.dateInterval(of: .day, for: $0) }
        },

        /// Today
        Rule(phrase: "today") { now, cal in
            cal.dateInterval(of: .day, for: now)
        },

        /// Last Week
        Rule(phrase: "last week") { now, cal in
            cal.date(byAdding: .weekOfYear, value: -1, to: now).flatMap { cal.dateInterval(of: .weekOfYear, for: $0) }
        },

        /// This Week
        Rule(phrase: "this week") { now, cal in
            cal.dateInterval(of: .weekOfYear, for: now)
        },

        /// Last Month
        Rule(phrase: "last month") { now, cal in
            cal.date(byAdding: .month, value: -1, to: now).flatMap { cal.dateInterval(of: .month, for: $0) }
        },

        /// This Month
        Rule(phrase: "this month") { now, cal in
            cal.dateInterval(of: .month, for: now)
        },
    ]

    public static func dateRange(
        for query: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DateFilterResult? {
        if let result = parseTimeAgo(
            query,
            now: now,
            calendar: calendar
        ) {
            return result
        }

        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)


        for rule in rules {
            if let range = query.range(of: rule.phrase, options: .caseInsensitive) {
                guard let interval = rule.interval(now, calendar) else { return nil }
                var rest = query
                rest.removeSubrange(range)
                return DateFilterResult(interval: interval, remainingQuery: clean(rest))
            }

            let n = rule.phrase.split(separator: " ").count
            guard words.count >= n else { continue }

            let tail = words.suffix(n)
            let typed = tail.joined(separator: " ").lowercased()

            if (tail.last?.count ?? 0) >= 3, rule.phrase.hasPrefix(typed) {
                guard let interval = rule.interval(now, calendar) else { return nil }
                let rest = words.dropLast(n).joined(separator: " ")
                return DateFilterResult(interval: interval, remainingQuery: clean(rest))
            }
        }
        return nil
    }

    private static func parseTimeAgo(
        _ query: String,
        now: Date,
        calendar: Calendar
    ) -> DateFilterResult? {

        let numberWords = [
            "one", "two", "three", "four", "five",
            "six", "seven", "eight", "nine", "ten",
            "eleven", "twelve", "thirteen", "fourteen",
            "fifteen", "sixteen", "seventeen", "eighteen",
            "nineteen", "twenty", "thirty", "forty",
            "fifty", "sixty", "seventy", "eighty", "ninety"
        ]

        let wordPattern = numberWords.joined(separator: "|")

        let pattern = #"\b(\d+|(?:"# + wordPattern +
        #")(?:[- ](?:"# + wordPattern +
        #"))?)\s+(seconds?|secs?|minutes?|mins?|hours?|hrs?|days?|weeks?|months?|years?)\s+ago\b"#

        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(query.startIndex..., in: query)

        guard let match = regex.firstMatch(
            in: query,
            range: range
        ),
              let numberRange = Range(match.range(at: 1), in: query),
              let unitRange = Range(match.range(at: 2), in: query),
              let fullRange = Range(match.range, in: query),
              let amount = parseNumber(String(query[numberRange])),
              amount > 0
                else {
            return nil
        }

        let unit = query[unitRange].lowercased()

        let component: Calendar.Component

        switch unit {
        case "second", "seconds", "sec", "secs":
            component = .second
        case "minute", "minutes", "min", "mins":
            component = .minute
        case "hour", "hours", "hr", "hrs":
            component = .hour
        case "day", "days":
            component = .day
        case "week", "weeks":
            component = .weekOfYear
        case "month", "months":
            component = .month
        case "year", "years":
            component = .year
        default:
            return nil
        }

        guard let target = calendar.date(
            byAdding: component,
            value: -amount,
            to: now
        ) else {
            return nil
        }

        guard let interval = calendar.dateInterval(
            of: component,
            for: target
        ) else {
            return nil
        }

        var remaining = query
        remaining.removeSubrange(fullRange)

        return DateFilterResult(
            interval: interval,
            remainingQuery: clean(remaining)
        )
    }


    private static func parseNumber(_ text: String) -> Int? {
        if let number = Int(text) {
            return number > 0 ? number : nil
        }

        let values: [String: Int] = [
            "one": 1, "two": 2, "three": 3,
            "four": 4, "five": 5, "six": 6,
            "seven": 7, "eight": 8, "nine": 9,
            "ten": 10, "eleven": 11, "twelve": 12,
            "thirteen": 13, "fourteen": 14,
            "fifteen": 15, "sixteen": 16,
            "seventeen": 17, "eighteen": 18,
            "nineteen": 19, "twenty": 20,
            "thirty": 30, "forty": 40,
            "fifty": 50, "sixty": 60,
            "seventy": 70, "eighty": 80,
            "ninety": 90
        ]

        let words = text.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")

        let numbers = words.compactMap { values[String($0)] }

        guard numbers.count == words.count else {
            return nil
        }

        if numbers.count == 1 {
            return numbers[0]
        }

        guard numbers.count == 2,
              (20...90).contains(numbers[0]),
              numbers[0].isMultiple(of: 10),
              (1...9).contains(numbers[1])
        else {
            return nil
        }

        return numbers[0] + numbers[1]
    }


    private static func clean(_ s: String) -> String {
        s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
