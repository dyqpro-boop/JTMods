//
//  HNSMSOpenHook.swift
//  SMS URL customization and OCR handoff
//

import UIKit

enum HNSMSOpenHook {
    static func install() {
        UIApplication.swizzleOpen()
    }
}

private extension UIApplication {
    static var isOpenSwizzled = false

    @objc static func swizzleOpen() {
        guard !isOpenSwizzled else { return }
        isOpenSwizzled = true

        let cls = UIApplication.self
        let originalSelector = #selector(UIApplication.open(_:options:completionHandler:))
        let swizzledSelector = #selector(UIApplication.hn_open(_:options:completionHandler:))

        guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
              let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func hn_open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any] = [:], completionHandler completion: ((Bool) -> Void)? = nil) {
        if url.scheme == "sms" {
            let rawURL = url.absoluteString
            let phone = rawURL.replacingOccurrences(of: "sms:", with: "").components(separatedBy: "&").first?.components(separatedBy: "?").first ?? ""
            if !phone.isEmpty {
                let workflow = HNCompactWorkflow.shared
                let message = HNBankConfig.buildSmsMessage(amountText: workflow.currentCodAmount)
                let cleanPhone = phone.replacingOccurrences(of: " ", with: "")
                if let encodedBody = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let newSMSURL = URL(string: "sms:\(cleanPhone)&body=\(encodedBody)") {
                    workflow.autoOcrPending = true
                    hn_open(newSMSURL, options: options) { success in
                        completion?(success)
                        if success && workflow.autoOcrPending {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if let topVC = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                                    workflow.triggerOCRPhotoFlow(from: topVC)
                                }
                            }
                        }
                    }
                    return
                }
            }
        }
        hn_open(url, options: options, completionHandler: completion)
    }
}