//
//  HNMessageHook.swift
//  SMS composer message customization
//

import MessageUI
import UIKit

enum HNMessageHook {
    static func install() {
        MFMessageComposeViewController.swizzleCompose()
    }
}

private extension MFMessageComposeViewController {
    static var isComposeSwizzled = false

    @objc static func swizzleCompose() {
        guard !isComposeSwizzled else { return }
        isComposeSwizzled = true

        let cls = MFMessageComposeViewController.self
        let originalSelector = #selector(MFMessageComposeViewController.viewWillAppear(_:))
        let swizzledSelector = #selector(MFMessageComposeViewController.hn_viewWillAppear(_:))

        guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
              let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func hn_viewWillAppear(_ animated: Bool) {
        hn_viewWillAppear(animated)

        let workflow = HNCompactWorkflow.shared
        let amount = workflow.currentCodAmount
        let phone = workflow.currentPhoneNumber

        if !phone.isEmpty && !phone.contains("*") {
            let cleanPhone = phone.replacingOccurrences(of: " ", with: "")
            recipients = [cleanPhone]
        }

        if !amount.isEmpty && amount != "0" {
            body = HNBankConfig.buildSmsMessage(amountText: HNVietQRBuilder.roundedAmountText(amount))
            workflow.autoOcrPending = true
            if messageComposeDelegate == nil {
                messageComposeDelegate = workflow
            }
        }
    }
}