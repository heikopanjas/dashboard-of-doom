import Foundation

extension String {
    static func truncate(_ string: String?, maxLength: Int = 30) -> String? {
        guard let string = string else {
            return nil
        }
        guard string.count > maxLength else {
            return string
        }
        let index = string.index(string.startIndex, offsetBy: maxLength)
        return String(string[..<index]) + "...."
    }
}

