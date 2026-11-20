//
//  HNQuizHook.swift
//  Runner - Intercept & Auto-Mark Quiz Questions in J&T Startup Test
//

import UIKit

@objc(HNQuizHook)
public class HNQuizHook: NSObject {

    @objc public static let shared = HNQuizHook()

    /// Last processed quiz answers summary
    @objc public var lastAnswersSummary: String = ""

    private override init() {
        super.init()
    }

    /// App gửi lại nguyên danh sách câu hỏi khi nộp bài -> bỏ "(✓)" đã gắn để dữ liệu lên server giống bản gốc.
    /// Chỉ thay chuỗi trong body (giữ nguyên mọi byte khác). Trả về nil nếu không có gì cần đổi.
    static func sanitizeOutgoingBody(_ data: Data) -> Data? {
        guard var text = String(data: data, encoding: .utf8) else { return nil }
        let original = text
        for mark in [" (✓)", "(✓)", " (\\u2713)", "(\\u2713)"] {
            text = text.replacingOccurrences(of: mark, with: "")
        }
        guard text != original else { return nil }
        return text.data(using: .utf8)
    }

    /// Process the response JSON data for quiz / test APIs
    /// Appends [ĐÁP ÁN: ...] to examTitle/question title and (✓) to choice contents and options.
    @objc public static func processQuizResponse(_ data: Data) -> Data {
        guard var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return data
        }

        var dataMap = (json["data"] as? [String: Any]) ?? json
        var subjectList = (dataMap["subjectList"] as? [[String: Any]])
            ?? (dataMap["questions"] as? [[String: Any]])
            ?? (dataMap["subject"] as? [[String: Any]])
            ?? (dataMap["questionList"] as? [[String: Any]])
            ?? (dataMap["list"] as? [[String: Any]])
            ?? (dataMap["rows"] as? [[String: Any]])
            ?? []

        if subjectList.isEmpty, let arrayData = json["data"] as? [[String: Any]] {
            subjectList = arrayData
        }

        guard !subjectList.isEmpty else {
            return data
        }

        var summaryLines: [String] = []
        var unmatchedCount = 0

        for i in 0..<subjectList.count {
            var question = subjectList[i]

            // Extract answer codes
            var answerCodes: [String] = []
            let answerKeys = [
                "answer", "rightAnswer", "answerCode", "correctAnswer", "correct", "ans",
                "answerOptions", "answerOption", "rightOption", "correctOption", "answerCodes"
            ]
            let rawAnswers: [Any] = answerKeys
                .compactMap { question[$0] }
                .filter { !($0 is NSNull) }

            for ans in rawAnswers {
                if let str = ans as? String {
                    let parts = str.components(separatedBy: CharacterSet(charactersIn: ",;| "))
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    answerCodes.append(contentsOf: parts)
                } else if let arr = ans as? [Any] {
                    for item in arr {
                        let itemStr = String(describing: item).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !itemStr.isEmpty { answerCodes.append(itemStr) }
                    }
                } else {
                    let itemStr = String(describing: ans).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !itemStr.isEmpty { answerCodes.append(itemStr) }
                }
            }

            // Extract choices array
            var choosesKey = "chooses"
            var chooses = (question["chooses"] as? [[String: Any]])
            if chooses == nil {
                if let c = question["chooseList"] as? [[String: Any]] { chooses = c; choosesKey = "chooseList" }
                else if let c = question["options"] as? [[String: Any]] { chooses = c; choosesKey = "options" }
                else if let c = question["choices"] as? [[String: Any]] { chooses = c; choosesKey = "choices" }
                else if let c = question["items"] as? [[String: Any]] { chooses = c; choosesKey = "items" }
            }

            var choosesList = chooses ?? []
            var matchedOptions: [String] = []
            var matchedContents: [String] = []

            func cleaned(_ value: String) -> String {
                return value.replacingOccurrences(of: " (✓)", with: "")
                    .replacingOccurrences(of: "(✓)", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Lấy mã / chữ cái / nội dung của từng lựa chọn
            var codes: [String] = []
            var options: [String] = []
            var contents: [String] = []
            for choice in choosesList {
                let code = (choice["chooseCode"] as? String)
                    ?? (choice["code"] as? String)
                    ?? (choice["id"] as? String)
                    ?? String(describing: choice["chooseCode"] ?? choice["code"] ?? choice["id"] ?? "")
                let rawOption = (choice["chooseOption"] as? String)
                    ?? (choice["option"] as? String)
                    ?? (choice["key"] as? String)
                    ?? ""
                let rawContent = (choice["chooseContent"] as? String)
                    ?? (choice["content"] as? String)
                    ?? (choice["title"] as? String)
                    ?? (choice["text"] as? String)
                    ?? ""
                codes.append(code.trimmingCharacters(in: .whitespacesAndNewlines))
                options.append(cleaned(rawOption))
                contents.append(cleaned(rawContent))
            }

            // Lượt 1: khớp theo mã đáp án hoặc chữ cái (A/B/C/D)
            var matchedIndexes = Set<Int>()
            for j in 0..<choosesList.count {
                let byCode = !codes[j].isEmpty && answerCodes.contains { $0.caseInsensitiveCompare(codes[j]) == .orderedSame }
                let byOption = !options[j].isEmpty && answerCodes.contains { $0.caseInsensitiveCompare(options[j]) == .orderedSame }
                if byCode || byOption { matchedIndexes.insert(j) }
            }
            // Lượt 2 (dự phòng): đáp án là số thứ tự 1-based
            if matchedIndexes.isEmpty {
                for j in 0..<choosesList.count where answerCodes.contains(String(j + 1)) {
                    matchedIndexes.insert(j)
                }
            }
            if matchedIndexes.isEmpty {
                unmatchedCount += 1
                HNLog.write("HNQuiz: câu \(i + 1) KHÔNG khớp đáp án. answerCodes=\(answerCodes) chooseCodes=\(codes) options=\(options) keys=\(question.keys.sorted())")
            }

            for j in 0..<choosesList.count {
                var choice = choosesList[j]
                let cleanContent = contents[j]
                let cleanOption = options[j]

                if matchedIndexes.contains(j) {
                    if !cleanOption.isEmpty { matchedOptions.append(cleanOption) }
                    if !cleanContent.isEmpty { matchedContents.append(cleanContent) }

                    // Chỉ gắn (✓) ở cuối nội dung; chữ cái đáp án giữ nguyên (không gắn ✓)
                    let formattedContent = "\(cleanContent) (✓)"

                    choice["chooseContent"] = formattedContent
                    if choice["content"] != nil { choice["content"] = formattedContent }
                    if choice["text"] != nil { choice["text"] = formattedContent }
                    if choice["title"] != nil { choice["title"] = formattedContent }

                    choice["chooseOption"] = cleanOption
                    if choice["option"] != nil { choice["option"] = cleanOption }

                } else {
                    // Keep wrong choice content clean
                    choice["chooseContent"] = cleanContent
                    if choice["content"] != nil { choice["content"] = cleanContent }
                    if choice["text"] != nil { choice["text"] = cleanContent }

                    choice["chooseOption"] = cleanOption
                    if choice["option"] != nil { choice["option"] = cleanOption }

                }

                choosesList[j] = choice
            }

            question[choosesKey] = choosesList

            let optionsStr = matchedOptions.isEmpty ? (answerCodes.isEmpty ? "?" : answerCodes.joined(separator: ", ")) : matchedOptions.joined(separator: ", ")
            let contentsStr = matchedContents.joined(separator: "; ")

            subjectList[i] = question

            let line = "Câu \(i + 1): [\(optionsStr)] - \(contentsStr)"
            summaryLines.append(line)
        }

        if json["data"] is [[String: Any]] {
            json["data"] = subjectList
        } else {
            dataMap["subjectList"] = subjectList
            dataMap["questions"] = subjectList
            json["data"] = dataMap
        }

        let summaryText = summaryLines.joined(separator: "\n")
        shared.lastAnswersSummary = summaryText
        HNLog.write("HNQuiz: xử lý \(subjectList.count) câu, khớp đáp án \(subjectList.count - unmatchedCount)")

        if let new = try? JSONSerialization.data(withJSONObject: json, options: []) {
            return new
        }

        return data
    }
}