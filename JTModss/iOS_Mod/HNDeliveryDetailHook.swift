//
//  HNDeliveryDetailHook.swift
//  HNMod - Hook DeliveryDetailViewController.callPhone
//

import Foundation
import UIKit

@objc(HNDeliveryDetailHook)
public class HNDeliveryDetailHook: NSObject {
    private static var isCallPhoneHookInstalled = false

    @objc public static func install() {
        guard !isCallPhoneHookInstalled else { return }

        let classNames = [
            "Runner.DeliveryDetailViewController",
            "DeliveryDetailViewController",
            "JTCore.DeliveryDetailViewController"
        ]

        var targetClass: AnyClass? = nil
        for name in classNames {
            if let cls = NSClassFromString(name) {
                targetClass = cls
                break
            }
        }

        guard let originalClass = targetClass else { return }

        let originalSel = NSSelectorFromString("callPhone")
        let originalAliasSel = #selector(hnmod_originalCallPhone)
        let replacementSel = #selector(hn_callPhone)

        guard let originalMethod = class_getInstanceMethod(originalClass, originalSel),
              let replacementMethod = class_getInstanceMethod(HNDeliveryDetailHook.self, replacementSel) else {
            return
        }

        let aliasAdded = class_addMethod(
            originalClass,
            originalAliasSel,
            method_getImplementation(originalMethod),
            method_getTypeEncoding(originalMethod)
        )

        guard aliasAdded else { return }

        class_replaceMethod(
            originalClass,
            originalSel,
            method_getImplementation(replacementMethod),
            method_getTypeEncoding(replacementMethod)
        )
        isCallPhoneHookInstalled = true
    }

    @objc func hn_callPhone() {
        guard let topVC = UIApplication.shared.topViewController() else {
            self.hnmod_originalCallPhone()
            return
        }

        let sheet = UIAlertController(title: "Chọn", message: nil, preferredStyle: .actionSheet)

        // 1. Gọi người nhận (gọi method gốc)
        sheet.addAction(UIAlertAction(title: "Gọi người nhận", style: .default) { [weak self] _ in
            self?.hnmod_originalCallPhone()
        })

        // 2. Nhắn tin cho người nhận
        sheet.addAction(UIAlertAction(title: "Nhắn tin cho người nhận", style: .default) { _ in
            let phone = HNCompactWorkflow.shared.currentPhoneNumber
            guard !phone.isEmpty && !phone.contains("*") else { return }
            if let url = URL(string: "sms:\(HNZaloConfig.shared.effectivePhone(phone))") {
                UIApplication.shared.open(url)
            }
        })

        // 3. Gửi Zalo/SMS (gộp HN Flash + Gửi Zalo): theo HNZaloConfig, có Zalo -> Zalo, không -> SMS
        sheet.addAction(UIAlertAction(title: "Gửi Zalo/SMS 💬", style: .default) { _ in
            let workflow = HNCompactWorkflow.shared

            let send: () -> Void = {
                let phone = workflow.currentPhoneNumber
                guard !phone.isEmpty && !phone.contains("*") else {
                    let alert = UIAlertController(
                        title: "Không lấy được số điện thoại",
                        message: "Chưa lấy được SĐT đầy đủ của đơn này nên không gửi Zalo/SMS được.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    topVC.present(alert, animated: true)
                    return
                }
                HNJTSheetHook.dispatchZaloOrSMS(phone: phone, waybillNo: workflow.currentWaybillNo, from: topVC)
            }

            let phone = workflow.currentPhoneNumber
            if phone.isEmpty || phone.contains("*"), !workflow.currentWaybillNo.isEmpty {
                workflow.prefillFromWaybillNo(workflow.currentWaybillNo) { _ in
                    DispatchQueue.main.async { send() }
                }
            } else {
                send()
            }
        })

        // 4. Copy SĐT nhanh
        sheet.addAction(UIAlertAction(title: "Copy SĐT nhanh 📋", style: .default) { _ in
            let workflow = HNCompactWorkflow.shared

            let copy: () -> Void = {
                let phone = workflow.currentPhoneNumber
                if phone.isEmpty || phone.contains("*") {
                    HNJTSheetHook.showToast(message: "Không lấy được SĐT đầy đủ của đơn này.", in: topVC.view)
                } else {
                    let clean = HNZaloConfig.shared.effectivePhone(phone)
                    let isBackup = clean != HNZaloConfig.normalize(phone)
                    UIPasteboard.general.string = clean
                    HNJTSheetHook.showToast(message: "Đã copy SĐT\(isBackup ? " backup" : ""): \(clean)", in: topVC.view)
                }
            }

            let phone = workflow.currentPhoneNumber
            if phone.isEmpty || phone.contains("*"), !workflow.currentWaybillNo.isEmpty {
                workflow.prefillFromWaybillNo(workflow.currentWaybillNo) { _ in
                    DispatchQueue.main.async { copy() }
                }
            } else {
                copy()
            }
        })

        // 5. Down Screen 📲 (Tự động tải ảnh Call Log Screen & Fake Cuộc Gọi)
        sheet.addAction(UIAlertAction(title: "Down Screen 📲", style: .default) { _ in
            let workflow = HNCompactWorkflow.shared
            let download: () -> Void = {
                let phone = workflow.currentPhoneNumber
                let finalPhone = (phone.isEmpty || phone.contains("*")) ? "0359145852" : phone
                let waybill = workflow.currentWaybillNo
                workflow.uploadFakeCallRecord(phoneNumber: finalPhone, waybillNo: waybill)
                HNFakeCallHistoryViewController.downloadAndSaveCallHistoryImage(phoneNumber: finalPhone) { _ in
                    DispatchQueue.main.async {
                        HNJTSheetHook.showToast(message: "Đã fake cuộc gọi & tải ảnh Call Log Screen! 📲📸", in: topVC.view)
                    }
                }
            }

            let phone = workflow.currentPhoneNumber
            if phone.isEmpty || phone.contains("*"), !workflow.currentWaybillNo.isEmpty {
                workflow.prefillFromWaybillNo(workflow.currentWaybillNo) { _ in
                    DispatchQueue.main.async { download() }
                }
            } else {
                download()
            }
        })

        // 6. Màn Hình Nhật Ký Cuộc Gọi
        sheet.addAction(UIAlertAction(title: "Màn Hình Log Cuộc Gọi", style: .default) { _ in
            let phone = HNCompactWorkflow.shared.currentPhoneNumber
            let fakeVC = HNFakeCallHistoryViewController()
            fakeVC.phoneNumber = phone.isEmpty ? "0359145852" : phone
            fakeVC.contactName = fakeVC.phoneNumber
            fakeVC.modalPresentationStyle = .fullScreen
            topVC.present(fakeVC, animated: true)
        })

        // 7. Update SĐT Backup
        sheet.addAction(UIAlertAction(title: "Update SĐT ✏️", style: .default) { _ in
            let workflow = HNCompactWorkflow.shared
            let originalPhone = workflow.currentPhoneNumber
            let currentBackup = HNZaloConfig.shared.getBackupPhone(originalPhone) ?? ""

            let alert = UIAlertController(
                title: "CẬP NHẬT SỐ ĐIỆN THOẠI BACKUP",
                message: "Nhập SĐT backup/Zalo cho khách:\nSĐT gốc: \(originalPhone.isEmpty ? "Chưa có" : originalPhone)",
                preferredStyle: .alert
            )

            alert.addTextField { field in
                field.placeholder = "Nhập SĐT backup (VD: 0988888888)"
                field.text = currentBackup
                field.keyboardType = .phonePad
            }

            alert.addAction(UIAlertAction(title: "Lưu SĐT Backup", style: .default) { _ in
                let input = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !originalPhone.isEmpty {
                    HNZaloConfig.shared.setBackupPhone(originalPhone, backupPhone: input, name: workflow.currentReceiverName)
                    HNJTSheetHook.refreshZaloBadges()
                }
                if input.isEmpty {
                    HNJTSheetHook.showToast(message: "Đã xóa SĐT backup", in: topVC.view)
                } else {
                    HNJTSheetHook.showToast(message: "Đã lưu SĐT Backup Zalo: \(HNZaloConfig.normalize(input))", in: topVC.view)
                }
            })

            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
            topVC.present(alert, animated: true)
        })

        // Button Huỷ
        sheet.addAction(UIAlertAction(title: "Huỷ", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX,
                                        y: topVC.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        topVC.present(sheet, animated: true)
    }

    @objc private func hnmod_originalCallPhone() {}
}