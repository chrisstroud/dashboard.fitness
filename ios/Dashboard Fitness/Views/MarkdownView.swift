import SwiftUI

struct MarkdownView: View {
    let content: String

    private var blocks: [MarkdownBlock] {
        parseMarkdown(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            headingView(level: level, text: text)
        case .paragraph(let text):
            Text(inlineMarkdown(text))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        case .listItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(inlineMarkdown(text))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 4)
        case .table(let rows):
            tableView(rows: rows)
        case .codeBlock(let code):
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        case .divider:
            Divider()
        case .empty:
            EmptyView()
        }
    }

    @ViewBuilder
    private func headingView(level: Int, text: String) -> some View {
        switch level {
        case 1:
            Text(inlineMarkdown(text))
                .font(.title.bold())
                .padding(.top, 4)
        case 2:
            Text(inlineMarkdown(text))
                .font(.title2.bold())
                .padding(.top, 4)
        case 3:
            Text(inlineMarkdown(text))
                .font(.title3.bold())
                .padding(.top, 2)
        default:
            Text(inlineMarkdown(text))
                .font(.headline)
        }
    }

    @ViewBuilder
    private func tableView(rows: [[String]]) -> some View {
        if let header = rows.first {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 0) {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                        Text(inlineMarkdown(cell.trimmingCharacters(in: .whitespaces)))
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                    }
                }
                .background(Color(.tertiarySystemBackground))

                Divider()

                // Body rows (skip separator row)
                let dataRows = rows.dropFirst().filter { row in
                    !row.allSatisfy { $0.trimmingCharacters(in: .whitespaces).allSatisfy { $0 == "-" || $0 == ":" } }
                }
                ForEach(Array(dataRows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(inlineMarkdown(cell.trimmingCharacters(in: .whitespaces)))
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 8)
                        }
                    }
                    Divider()
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

// MARK: - Parser

private enum MarkdownBlock {
    case heading(Int, String)
    case paragraph(String)
    case listItem(String)
    case table([[String]])
    case codeBlock(String)
    case divider
    case empty
}

private func parseMarkdown(_ text: String) -> [MarkdownBlock] {
    let lines = text.components(separatedBy: "\n")
    var blocks: [MarkdownBlock] = []
    var i = 0

    while i < lines.count {
        let line = lines[i]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Empty line
        if trimmed.isEmpty {
            i += 1
            continue
        }

        // Divider
        if trimmed.allSatisfy({ $0 == "-" }) && trimmed.count >= 3 {
            blocks.append(.divider)
            i += 1
            continue
        }

        // Heading
        if let match = trimmed.firstMatch(of: /^(#{1,4})\s+(.+)/) {
            let level = match.1.count
            let text = String(match.2)
            blocks.append(.heading(level, text))
            i += 1
            continue
        }

        // Code block
        if trimmed.hasPrefix("```") {
            var codeLines: [String] = []
            i += 1
            while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                codeLines.append(lines[i])
                i += 1
            }
            blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
            i += 1
            continue
        }

        // Table (starts with |)
        if trimmed.hasPrefix("|") {
            var tableRows: [[String]] = []
            while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                let row = lines[i]
                    .trimmingCharacters(in: .whitespaces)
                    .split(separator: "|", omittingEmptySubsequences: false)
                    .map(String.init)
                    .filter { !$0.isEmpty }
                tableRows.append(row)
                i += 1
            }
            blocks.append(.table(tableRows))
            continue
        }

        // List item
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let text = String(trimmed.dropFirst(2))
            blocks.append(.listItem(text))
            i += 1
            continue
        }

        // Numbered list
        if let match = trimmed.firstMatch(of: /^\d+\.\s+(.+)/) {
            blocks.append(.listItem(String(match.1)))
            i += 1
            continue
        }

        // Paragraph (collect consecutive non-empty lines)
        var paraLines: [String] = [trimmed]
        i += 1
        while i < lines.count {
            let next = lines[i].trimmingCharacters(in: .whitespaces)
            if next.isEmpty || next.hasPrefix("#") || next.hasPrefix("-") || next.hasPrefix("|") || next.hasPrefix("```") {
                break
            }
            paraLines.append(next)
            i += 1
        }
        blocks.append(.paragraph(paraLines.joined(separator: " ")))
    }

    return blocks
}

#Preview {
    ScrollView {
        MarkdownView(content: """
        # Morning Supplements

        | Supplement | Dose | Why |
        |---|---|---|
        | Fish Oil (EPA/DHA) | 3-5g | Anti-inflammatory, cardiovascular |
        | Vitamin D3 + K2 | 5,000 IU / 200mcg | Target 40-60 ng/mL |

        ## Notes

        - Take with food for absorption
        - Refrigerate fish oil
        - **Bold text** and `inline code`
        """)
        .padding()
    }
}
