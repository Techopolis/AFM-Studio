import Foundation

struct ParsedModelOutput: Equatable, Sendable {
    let rawText: String
    let displayText: String
    let finalText: String?
    let thinkingText: String?
    let hasStructuredChannels: Bool
}

enum ModelOutputParser {
    private struct ChannelSegment: Equatable {
        var channel: String
        var message: String
    }

    private static let channelMarker = "<|channel|>"
    private static let messageMarker = "<|message|>"
    private static let boundaryMarkers = ["<|end|>", "<|start|>", "<|channel|>"]
    private static let knownMarkers = ["<|start|>", "<|end|>", "<|channel|>", "<|message|>"]
    private static let thinkingChannels: Set<String> = [
        "analysis",
        "reasoning",
        "scratchpad",
        "thinking",
        "thought"
    ]

    static func parse(_ rawText: String) -> ParsedModelOutput {
        let segments = channelSegments(in: rawText)
        guard segments.isEmpty == false else {
            let displayText = strippedKnownMarkers(from: rawText).trimmedModelOutput
            return ParsedModelOutput(
                rawText: rawText,
                displayText: displayText,
                finalText: displayText,
                thinkingText: nil,
                hasStructuredChannels: false
            )
        }

        let finalText = segments
            .last { $0.channel == "final" }?
            .message
            .nilIfBlank
        let thinkingText = segments
            .filter { thinkingChannels.contains($0.channel) }
            .map(\.message)
            .filter { $0.isEmpty == false }
            .joined(separator: "\n\n")
            .nilIfBlank

        let displayText: String
        if let finalText {
            displayText = finalText
        } else if thinkingText != nil {
            displayText = ""
        } else {
            displayText = segments
                .last?
                .message
                .nilIfBlank ?? strippedKnownMarkers(from: rawText).trimmedModelOutput
        }

        return ParsedModelOutput(
            rawText: rawText,
            displayText: displayText,
            finalText: finalText,
            thinkingText: thinkingText,
            hasStructuredChannels: true
        )
    }

    private static func channelSegments(in rawText: String) -> [ChannelSegment] {
        var segments: [ChannelSegment] = []
        var searchStart = rawText.startIndex

        while let channelRange = rawText.range(
            of: channelMarker,
            range: searchStart..<rawText.endIndex
        ) {
            let channelNameStart = channelRange.upperBound
            guard let messageRange = rawText.range(
                of: messageMarker,
                range: channelNameStart..<rawText.endIndex
            ) else {
                break
            }

            let channelName = normalizeChannelName(String(rawText[channelNameStart..<messageRange.lowerBound]))
            let messageStart = messageRange.upperBound
            let messageEnd = nextBoundary(in: rawText, after: messageStart) ?? rawText.endIndex
            let message = String(rawText[messageStart..<messageEnd]).trimmedModelOutput

            if channelName.isEmpty == false {
                segments.append(ChannelSegment(channel: channelName, message: message))
            }

            searchStart = messageEnd
        }

        return segments
    }

    private static func normalizeChannelName(_ rawChannelName: String) -> String {
        knownMarkers
            .reduce(rawChannelName) { partial, marker in
                partial.replacingOccurrences(of: marker, with: "")
            }
            .trimmedModelOutput
            .lowercased()
    }

    private static func nextBoundary(in rawText: String, after startIndex: String.Index) -> String.Index? {
        boundaryMarkers
            .compactMap { marker in
                rawText.range(of: marker, range: startIndex..<rawText.endIndex)?.lowerBound
            }
            .min()
    }

    private static func strippedKnownMarkers(from rawText: String) -> String {
        knownMarkers.reduce(rawText) { partial, marker in
            partial.replacingOccurrences(of: marker, with: "")
        }
    }
}

private extension String {
    var trimmedModelOutput: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfBlank: String? {
        let trimmed = trimmedModelOutput
        return trimmed.isEmpty ? nil : trimmed
    }
}
