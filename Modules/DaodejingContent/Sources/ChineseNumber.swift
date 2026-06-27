import Foundation

/// Converts 1…99 to traditional Chinese numerals (一, 二 … 八十一) for chapter
/// indices in the contents list and reader header.
public enum ChineseNumber {
    private static let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    public static func of(_ value: Int) -> String {
        guard (1 ... 99).contains(value) else { return String(value) }
        if value < 10 { return digits[value] }
        let tens = value / 10
        let ones = value % 10
        let tensPart = tens == 1 ? "十" : digits[tens] + "十"
        return ones == 0 ? tensPart : tensPart + digits[ones]
    }
}
