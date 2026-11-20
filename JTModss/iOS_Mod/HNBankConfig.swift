//
//  HNBankConfig.swift
//  Runner - Mod for iOS
//

import Foundation
import UIKit

@objc(HNBankConfig)
public class HNBankConfig: NSObject {

    private static let kAccountNumberKey = "hn_bank_account_number"
    private static let kAccountNameKey   = "hn_bank_account_name"
    private static let kBankNameKey      = "hn_bank_name"

    private static let defaultAccountNumber = "0962296321"
    private static let defaultAccountName = "NGUYEN VAN HAU"
    private static let defaultBankName = "BIDV"

    // MARK: - Properties

    @objc public static var accountNumber: String {
        get { return UserDefaults.standard.string(forKey: kAccountNumberKey) ?? defaultAccountNumber }
        set { UserDefaults.standard.set(newValue, forKey: kAccountNumberKey) }
    }

    @objc public static var accountName: String {
        get { return UserDefaults.standard.string(forKey: kAccountNameKey) ?? defaultAccountName }
        set { UserDefaults.standard.set(newValue, forKey: kAccountNameKey) }
    }

    @objc public static var bankName: String {
        get { return UserDefaults.standard.string(forKey: kBankNameKey) ?? defaultBankName }
        set { UserDefaults.standard.set(newValue, forKey: kBankNameKey) }
    }

    @objc public static var isConfigured: Bool {
        return !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func presentConfiguration(from presenter: UIViewController) {
        let alert = UIAlertController(title: "CẤU HÌNH STK", message: nil, preferredStyle: .alert)

        let titleFont = UIFont(name: "HarmonyOS_Sans_Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        let titleAttr = NSAttributedString(string: "CẤU HÌNH STK", attributes: [.font: titleFont])
        if alert.responds(to: NSSelectorFromString("setAttributedTitle:")) {
            alert.setValue(titleAttr, forKey: "attributedTitle")
        }

        alert.addTextField { field in
            field.placeholder = "Số tài khoản"
            field.text = accountNumber
            field.keyboardType = .numberPad
            field.font = UIFont(name: "HarmonyOS_Sans_Medium", size: 14) ?? UIFont.systemFont(ofSize: 14)
        }

        alert.addTextField { field in
            field.placeholder = "Tên tài khoản (ví dụ: NGUYEN VAN A)"
            field.text = accountName
            field.autocapitalizationType = .allCharacters
            field.font = UIFont(name: "HarmonyOS_Sans_Medium", size: 14) ?? UIFont.systemFont(ofSize: 14)
        }

        alert.addTextField { field in
            field.placeholder = "Tên ngân hàng (ví dụ: BIDV / VCB / MB / Techcombank)"
            field.text = bankName
            field.font = UIFont(name: "HarmonyOS_Sans_Medium", size: 14) ?? UIFont.systemFont(ofSize: 14)
        }

        alert.addAction(UIAlertAction(title: "Lưu Cấu Hình", style: .default) { _ in
            if let accountField = alert.textFields?[0],
               let nameField = alert.textFields?[1],
               let bankField = alert.textFields?[2] {
                accountNumber = accountField.text ?? ""
                accountName = nameField.text ?? ""
                bankName = bankField.text ?? ""
            }
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        presenter.present(alert, animated: true)
    }

    // MARK: - Amount Formatting

    /// Format COD amount into short format (e.g., 199399 -> "199K", 199400 -> "200K")
    @objc public static func formatAmount(_ amount: NSNumber?) -> String {
        guard let amount = amount else { return "0K" }
        let val = Int(round(amount.doubleValue))
        if val <= 0 { return "0K" }

        // Nếu nhỏ hơn 1000 thì coi như đã ở đơn vị K (ví dụ: 150 -> 150K)
        if val < 1000 {
            return "\(val)K"
        }

        let rem = val % 1000
        var thousands = val / 1000

        // Từ 400 đồng trở lên thì làm tròn lên +1K, dưới 400 đồng làm tròn xuống
        if rem >= 400 {
            thousands += 1
        }

        return "\(thousands)K"
    }

    /// Build the quick STK SMS using the order amount and saved bank details.
    @objc public static func buildSmsMessage(amountText: String) -> String {
        let cleanBank = bankName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAccount = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAmount = amountInThousands(amountText)

        let account = cleanAccount.isEmpty ? defaultAccountNumber : cleanAccount
        let name = cleanName.isEmpty ? defaultAccountName : cleanName
        let bank = cleanBank.isEmpty ? defaultBankName : cleanBank

        return "Tien: \(cleanAmount)K\nSTK: \(account) - \(name) - \(bank)"
    }

    /// Build template string for API replacement in getTemplate response
    @objc public static func buildSingleTemplate() -> String {
        let cleanBank = bankName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAccount = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)

        let account = cleanAccount.isEmpty ? defaultAccountNumber : cleanAccount
        let name = cleanName.isEmpty ? defaultAccountName : cleanName
        let bank = cleanBank.isEmpty ? defaultBankName : cleanBank

        return " Tien: <money>K \n STK: \(account) - \(name) - \(bank)"
    }

    /// Format raw string money (e.g. "150,000" or "199,399" or "190.000") into short thousands string (e.g. "150" or "199")
    @objc public static func formatAmountString(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "0" }

        // Clean currency chars
        let cleanStr = trimmed.replacingOccurrences(of: "VND", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "VNĐ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "K", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "đ", with: "", options: .caseInsensitive)

        let normalizedStr = cleanStr.replacingOccurrences(of: ",", with: "")
                                   .replacingOccurrences(of: ".", with: "")
        if let doubleVal = Double(normalizedStr), doubleVal > 0 {
            let formatted = formatAmount(NSNumber(value: doubleVal))
            return String(formatted.dropLast())
        }

        let digits = trimmed.filter(\.isNumber)
        guard let amount = Int(digits), amount > 0 else { return trimmed }

        let formatted = formatAmount(NSNumber(value: amount))
        return String(formatted.dropLast())
    }

    private static func amountInThousands(_ amountText: String) -> String {
        return formatAmountString(amountText)
    }
}
