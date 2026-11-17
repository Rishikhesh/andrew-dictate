import Foundation

extension String {
    /// the app's lowercase copy, as macOS writes it: every sentence starts
    /// with a capital. "fn" is a key's name and stays as it is.
    var capitalizedFirst: String {
        guard self != "fn" else {
            return self
        }
        var out = ""
        var capitalizeNext = true
        var previous: Character = " "
        for character in self {
            if capitalizeNext, character.isLetter {
                out += String(character).uppercased()
                capitalizeNext = false
            } else {
                out.append(character)
                if character.isLetter || character.isNumber {
                    capitalizeNext = false
                }
            }
            if character == " ", [".", "?", "!"].contains(previous) {
                capitalizeNext = true
            }
            previous = character
        }
        return Self.properNames(in: out)
    }

    /// names the app writes in lowercase that macOS never would.
    private static let names: [(String, String)] = [
        ("apple intelligence", "Apple Intelligence"),
        ("chatgpt", "ChatGPT"),
        ("openai", "OpenAI"),
        ("openrouter", "OpenRouter"),
        ("gemini", "Gemini"),
        ("google ai studio", "Google AI Studio"),
        ("macos", "macOS"),
        ("icloud", "iCloud"),
        ("finder", "Finder"),
        ("mac", "Mac"),
        ("ai", "AI"),
        ("api", "API"),
        ("json", "JSON"),
        ("english", "English"),
        ("european", "European"),
        ("gb", "GB"),
        ("mb", "MB"),
    ]

    private static func properNames(in text: String) -> String {
        var out = text
        for (lower, proper) in names {
            let pattern = "(?<![\\w.@/])" + NSRegularExpression.escapedPattern(for: lower) + "(?![\\w@/]|\\.\\w)"
            out = out.replacingOccurrences(
                of: pattern, with: proper,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return out
    }
}
