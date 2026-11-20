//
//  HNAlertHook.swift
//  Call-related alert actions
//

import UIKit

enum HNAlertHook {
    static func install() {
        UIAlertController.swizzleAlertHooks()
    }
}

private extension UIAlertController {
    static var isAlertSwizzled = false
    static var isInjecting = false

    @objc static func swizzleAlertHooks() {
        guard !isAlertSwizzled else { return }
        isAlertSwizzled = true

        let cls = UIAlertController.self
        let originalAdd = class_getInstanceMethod(cls, #selector(UIAlertController.addAction(_:)))
        let swizzledAdd = class_getInstanceMethod(cls, #selector(UIAlertController.hn_addAction(_:)))
        if let originalAdd = originalAdd, let swizzledAdd = swizzledAdd {
            method_exchangeImplementations(originalAdd, swizzledAdd)
        }

        let originalAppear = class_getInstanceMethod(cls, #selector(UIAlertController.viewDidAppear(_:)))
        let swizzledAppear = class_getInstanceMethod(cls, #selector(UIAlertController.hn_alertControllerDidAppear(_:)))
        if let originalAppear = originalAppear, let swizzledAppear = swizzledAppear {
            method_exchangeImplementations(originalAppear, swizzledAppear)
        }
    }

    @objc func hn_alertControllerDidAppear(_ animated: Bool) {
        hn_alertControllerDidAppear(animated)

        if title == "HN MOD" || title == "CẤU HÌNH STK" { return }

        injectCallActionsIfNeeded()
    }

    static func isCallRelatedTitle(_ title: String) -> Bool {
        let normalized = title.lowercased()
        return normalized.contains("gọi")
            || normalized.contains("nhắn tin")
            || normalized.contains("call")
            || normalized.contains("sms")
            || normalized.contains("message")
    }

    @objc func hn_addAction(_ action: UIAlertAction) {
        hn_addAction(action)
        guard !Self.isInjecting else { return }

        let title = action.title ?? ""
        if title == "Gửi STK" || title.contains("Nhật Ký Cuộc Gọi") { return }

        let popupTitle = (self.title ?? "").lowercased()
        let isCallRelated = Self.isCallRelatedTitle(title)
            || popupTitle == "chọn"
            || popupTitle.contains("gọi")
            || popupTitle.contains("đợi phát")
            || popupTitle.contains("call")

        if isCallRelated { injectCallActionsIfNeeded() }
    }

}

extension UIAlertController {
    func injectCallActionsIfNeeded() {
        guard !Self.isInjecting else { return }
        if title == "HN MOD" || title == "CẤU HÌNH STK" { return }

        let popupTitle = (title ?? "").lowercased()
        let isCallPopup = popupTitle == "chọn"
            || popupTitle.contains("gọi")
            || popupTitle.contains("đợi phát")
            || popupTitle.contains("call")
            || actions.contains(where: { Self.isCallRelatedTitle($0.title ?? "") })
        guard isCallPopup else { return }
        if actions.contains(where: { $0.title == "Gửi STK" }) { return }

        Self.isInjecting = true
        defer { Self.isInjecting = false }

        let stkAction = UIAlertAction(title: "Gửi STK", style: .default) { [weak self] _ in
            guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
                  let topVC = window.rootViewController else { return }
            let workflow = HNCompactWorkflow.shared

            if let alertVC = self,
               let targetCell = HNJTSheetHook.findTargetCellOrCardView(for: alertVC, in: topVC) {
                let (_, cellMaskedPhone, cellAmount, cellWaybill) = HNJTSheetHook.extractCellOrderDetails(from: targetCell)
                if !cellAmount.isEmpty && cellAmount != "0" {
                    workflow.currentCodAmount = cellAmount
                }
                workflow.resolveFullReceiverPhone(waybillNo: cellWaybill) { fullPhone in
                    DispatchQueue.main.async {
                        let finalPhone = (fullPhone != nil && !fullPhone!.contains("*")) ? fullPhone! : workflow.currentPhoneNumber
                        workflow.sendSTKQuick(
                            phoneNumber: finalPhone,
                            codAmountText: workflow.currentCodAmount,
                            barCodeListStr: cellWaybill,
                            from: topVC
                        )
                    }
                }
            } else {
                let currentPhone = workflow.currentPhoneNumber
                workflow.sendSTKQuick(
                    phoneNumber: currentPhone,
                    codAmountText: workflow.currentCodAmount,
                    barCodeListStr: workflow.currentBarCodeListStr,
                    from: topVC
                )
            }
        }
        hn_addAction(stkAction)

        guard !actions.contains(where: { $0.title?.contains("Down Screen") == true }) else { return }
        let downScreenAction = UIAlertAction(title: "Down Screen 📲", style: .default) { _ in
            guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
                  let topVC = window.rootViewController else { return }
            let workflow = HNCompactWorkflow.shared
            let currentPhone = workflow.currentPhoneNumber
            let finalPhone = (currentPhone.isEmpty || currentPhone.contains("*")) ? "0359145852" : currentPhone
            let waybill = workflow.currentWaybillNo
            workflow.uploadFakeCallRecord(phoneNumber: finalPhone, waybillNo: waybill)
            HNFakeCallHistoryViewController.downloadAndSaveCallHistoryImage(phoneNumber: finalPhone) { _ in
                DispatchQueue.main.async {
                    HNJTSheetHook.showToast(message: "Đã fake cuộc gọi & tải ảnh Call Log Screen! 📲📸", in: topVC.view)
                }
            }
        }
        hn_addAction(downScreenAction)

        guard !actions.contains(where: { $0.title?.contains("Nhật Ký Cuộc Gọi") == true }) else { return }
        let fakeCallAction = UIAlertAction(title: "Màn Hình Nhật Ký Cuộc Gọi (Chụp Ảnh)", style: .default) { _ in
            guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
                  let topVC = window.rootViewController else { return }
            let fakeVC = HNFakeCallHistoryViewController()
            let currentPhone = HNCompactWorkflow.shared.currentPhoneNumber
            fakeVC.phoneNumber = currentPhone.isEmpty ? "0359145852" : currentPhone
            fakeVC.contactName = fakeVC.phoneNumber
            fakeVC.modalPresentationStyle = .fullScreen
            topVC.present(fakeVC, animated: true)
        }
        hn_addAction(fakeCallAction)
    }
}