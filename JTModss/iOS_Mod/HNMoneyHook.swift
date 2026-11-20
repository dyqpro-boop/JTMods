//
//  HNMoneyHook.swift
//  Money placeholder formatting
//

import Foundation

enum HNMoneyHook {
    static func install() {
        NSString.swizzleReplacingOccurrences()
    }
}

private extension NSString {
    static var isReplacingSwizzled = false

    @objc static func swizzleReplacingOccurrences() {
        guard !isReplacingSwizzled else { return }
        isReplacingSwizzled = true

        let cls = NSString.self
        let originalSelector = #selector(NSString.replacingOccurrences(of:with:))
        let swizzledSelector = #selector(NSString.hn_replacingOccurrences(of:with:))

        guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
              let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func hn_replacingOccurrences(of target: String, with replacement: String) -> String {
        if target == "<money>" || target == "{money}" {
            let shortMoney = HNBankConfig.formatAmountString(replacement)
            return hn_replacingOccurrences(of: target, with: shortMoney)
        }
        return hn_replacingOccurrences(of: target, with: replacement)
    }
}