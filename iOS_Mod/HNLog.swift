//
//  HNLog.swift
//  Runner - Centralized Logger (No-op Stub)
//

import Foundation

@objc(HNLog)
public class HNLog: NSObject {
    @objc public static let logFilePath: String = ""

    @objc public static func write(_ message: String) {
        // No-op
    }

    @objc public static func read() -> String {
        return ""
    }

    @objc public static func clear() {
        // No-op
    }
}
