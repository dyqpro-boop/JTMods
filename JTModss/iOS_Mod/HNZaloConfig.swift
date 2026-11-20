//
//  HNZaloConfig.swift
//  Runner - Cấu hình khách nào có Zalo (đọc/ghi file JSON)
//
//  File: <Documents của app>/HNZaloContacts.json
//
//  Định dạng (mảng JSON, mỗi khách 1 dòng):
//  [
//    { "SDT": "0912345678", "Zalo": 1, "Ten": "Nguyen Van A" },
//    { "SDT": "0987654321", "Zalo": 0 }
//  ]
//
//  - "SDT"  : số điện thoại (0912..., +84912..., 84912... đều được, tự quy về 0912...)
//  - "Zalo" : 1 / true / "Yes" / "Co"  = có Zalo -> "Gửi Zalo/SMS" sẽ gửi Zalo
//             0 / false / "No" / "Khong" = không có Zalo -> gửi SMS
//  - Thêm trường nào khác tùy ý (Ten, Ghi chu, ...): app giữ nguyên khi ghi lại file.
//  - SĐT chưa có trong file: app hỏi 1 lần "Khách này có Zalo không?" rồi tự ghi vào file.
//

import Foundation

final class HNZaloConfig {

    static let shared = HNZaloConfig()
    static let fileName = "HNZaloContacts.json"

    private let lock = NSLock()
    /// key = SĐT đã chuẩn hóa -> nguyên dòng JSON gốc (giữ cả các trường lạ)
    private var contacts: [String: [String: Any]] = [:]
    private var order: [String] = []
    private var lastModified: Date?
    private var parseFailed = false
    private var lastCheck = Date.distantPast
    private var version = 0

    private static let phoneKeys = ["sdt", "phone", "sodienthoai", "mobile"]
    private static let zaloKeys = ["zalo", "cozalo", "haszalo"]
    private static let nameKeys = ["ten", "name", "hoten", "tenkhach"]
    private static let backupPhoneKeys = ["backup_sdt", "backupsdt", "sdt_backup", "backup_phone", "backupphone", "sdtbackup", "backupsd"]

    var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return dir.appendingPathComponent(HNZaloConfig.fileName)
    }

    private init() {
        lock.lock()
        reloadIfNeeded(force: true)
        lock.unlock()
    }

    // MARK: - Public API

    /// true = có Zalo, false = không có, nil = chưa có trong cấu hình (hoặc giá trị không đọc được).
    func hasZalo(_ phone: String) -> Bool? {
        let key = HNZaloConfig.normalize(phone)
        guard !key.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        reloadIfNeeded()
        guard let row = contacts[key] else { return nil }
        return HNZaloConfig.flag(HNZaloConfig.value(in: row, keys: HNZaloConfig.zaloKeys).value)
    }

    /// Trả về Backup_SDT nếu đã lưu trong file HNZaloContacts.json, ngược lại nil.
    func getBackupPhone(_ phone: String) -> String? {
        let key = HNZaloConfig.normalize(phone)
        guard !key.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        reloadIfNeeded()
        guard let row = contacts[key] else { return nil }
        if let val = HNZaloConfig.value(in: row, keys: HNZaloConfig.backupPhoneKeys).value as? String {
            let clean = HNZaloConfig.normalize(val)
            return clean.isEmpty ? nil : clean
        }
        return nil
    }

    /// Ưu tiên trả về Backup_SDT nếu có, ngược lại trả về SĐT đã chuẩn hóa.
    func effectivePhone(_ phone: String) -> String {
        let clean = HNZaloConfig.normalize(phone)
        if let backup = getBackupPhone(clean), !backup.isEmpty {
            return backup
        }
        return clean
    }

    /// Cập nhật trường "Backup_SDT" cho 1 SĐT khách và lưu file JSON.
    func setBackupPhone(_ phone: String, backupPhone: String, name: String = "") {
        let key = HNZaloConfig.normalize(phone)
        let cleanBackup = HNZaloConfig.normalize(backupPhone)
        guard !key.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        reloadIfNeeded()

        if var row = contacts[key] {
            let backupKey = HNZaloConfig.value(in: row, keys: HNZaloConfig.backupPhoneKeys).key ?? "Backup_SDT"
            if cleanBackup.isEmpty {
                row.removeValue(forKey: backupKey)
            } else {
                row[backupKey] = cleanBackup
            }
            contacts[key] = row
        } else {
            var row: [String: Any] = ["SDT": key, "Zalo": 1]
            if !cleanBackup.isEmpty { row["Backup_SDT"] = cleanBackup }
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanName.isEmpty { row["Ten"] = cleanName }
            contacts[key] = row
            order.append(key)
        }
        version += 1
        saveLocked()
    }

    /// Tăng mỗi khi dữ liệu đổi (sửa file tay hoặc setZalo) -> dùng để biết khi nào cần vẽ lại icon Zalo trên danh sách.
    var currentVersion: Int {
        lock.lock()
        defer { lock.unlock() }
        reloadIfNeeded()
        return version
    }

    /// Dùng cho icon trên thẻ đơn (danh sách chỉ có SĐT bị che ******2023).
    /// 1. Biết SĐT đầy đủ (đã giải mã) -> tra chính xác.
    /// 2. Không biết -> khớp theo tên khách + các số cuối; chỉ khớp được với dòng trong file có trường "Ten".
    func cellHasZalo(name: String, maskedPhone: String, fullPhone: String?) -> Bool {
        if let full = fullPhone, !full.isEmpty, !full.contains("*"), let known = hasZalo(full) {
            return known
        }
        let suffix = maskedPhone.filter { $0.isNumber }
        let cleanName = HNZaloConfig.foldKey(name)
        guard suffix.count >= 3, !cleanName.isEmpty else { return false }

        lock.lock()
        defer { lock.unlock() }
        reloadIfNeeded()
        for (key, row) in contacts where key.hasSuffix(suffix) {
            let rowName = HNZaloConfig.foldKey((HNZaloConfig.value(in: row, keys: HNZaloConfig.nameKeys).value as? String) ?? "")
            guard !rowName.isEmpty, rowName == cleanName else { continue }
            if HNZaloConfig.flag(HNZaloConfig.value(in: row, keys: HNZaloConfig.zaloKeys).value) == true { return true }
        }
        return false
    }

    /// Ghi/cập nhật 1 khách rồi lưu file ngay.
    func setZalo(_ phone: String, _ hasZalo: Bool, name: String = "") {
        let key = HNZaloConfig.normalize(phone)
        guard !key.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        reloadIfNeeded()

        if var row = contacts[key] {
            let zaloKey = HNZaloConfig.value(in: row, keys: HNZaloConfig.zaloKeys).key ?? "Zalo"
            row[zaloKey] = hasZalo ? 1 : 0
            contacts[key] = row
        } else {
            var row: [String: Any] = ["SDT": key, "Zalo": hasZalo ? 1 : 0]
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanName.isEmpty { row["Ten"] = cleanName }
            contacts[key] = row
            order.append(key)
        }
        version += 1
        saveLocked()
    }

    // MARK: - Helpers

    static func normalize(_ phone: String) -> String {
        var digits = phone.filter { $0.isNumber }
        if digits.hasPrefix("84") && digits.count >= 11 {
            digits = "0" + String(digits.dropFirst(2))
        }
        return digits
    }

    private static func foldKey(_ s: String) -> String {
        return s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func value(in row: [String: Any], keys: [String]) -> (key: String?, value: Any?) {
        for (k, v) in row where keys.contains(foldKey(k)) {
            return (k, v)
        }
        return (nil, nil)
    }

    private static func flag(_ value: Any?) -> Bool? {
        if let n = value as? NSNumber { return n.intValue != 0 }
        if let s = value as? String {
            let t = foldKey(s)
            if ["1", "yes", "y", "true", "co", "x", "ok"].contains(t) { return true }
            if ["0", "no", "n", "false", "khong"].contains(t) { return false }
        }
        return nil
    }

    // MARK: - Đọc / ghi file (gọi khi đã giữ lock)

    private func reloadIfNeeded(force: Bool = false) {
        // Không kiểm tra file quá dày (hàm này được gọi mỗi lần vẽ thẻ đơn)
        let now = Date()
        if !force && now.timeIntervalSince(lastCheck) < 1.0 { return }
        lastCheck = now

        let url = fileURL
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let modified = attrs?[.modificationDate] as? Date

        if !force, let modified = modified, let last = lastModified, modified == last { return }

        // Chưa có file -> tạo file rỗng để bạn thấy và sửa được
        if attrs == nil {
            contacts = [:]
            order = []
            try? "[\n]\n".write(to: url, atomically: true, encoding: .utf8)
            lastModified = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
            return
        }

        guard let data = try? Data(contentsOf: url) else { return }
        lastModified = modified

        var rows: [[String: Any]]?
        if data.isEmpty {
            rows = []
        } else {
            let obj = try? JSONSerialization.jsonObject(with: data)
            rows = obj as? [[String: Any]]
            if rows == nil, let dict = obj as? [String: Any] {
                rows = (dict["contacts"] ?? dict["data"] ?? dict["list"]) as? [[String: Any]]
            }
        }

        guard let list = rows else {
            parseFailed = true
            HNLog.write("HNZaloConfig: file \(HNZaloConfig.fileName) sai định dạng JSON, giữ dữ liệu cũ trong bộ nhớ")
            return
        }
        parseFailed = false

        var newContacts: [String: [String: Any]] = [:]
        var newOrder: [String] = []
        for row in list {
            let rawPhone = HNZaloConfig.value(in: row, keys: HNZaloConfig.phoneKeys).value
            let phoneText: String
            if let s = rawPhone as? String { phoneText = s }
            else if let n = rawPhone as? NSNumber { phoneText = n.stringValue }
            else { continue }
            let key = HNZaloConfig.normalize(phoneText)
            guard !key.isEmpty else { continue }
            if newContacts[key] == nil { newOrder.append(key) }
            newContacts[key] = row
        }
        contacts = newContacts
        order = newOrder
        version += 1
        HNLog.write("HNZaloConfig: đã nạp \(newOrder.count) khách từ \(HNZaloConfig.fileName)")
    }

    private func saveLocked() {
        let url = fileURL
        let fm = FileManager.default

        // File đang hỏng: sao lưu .bak trước khi ghi đè để không mất dữ liệu bạn đã gõ
        if parseFailed {
            let bak = url.appendingPathExtension("bak")
            try? fm.removeItem(at: bak)
            try? fm.copyItem(at: url, to: bak)
            parseFailed = false
        }

        let rows = order.compactMap { contacts[$0] }
        guard let data = try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]) else {
            HNLog.write("HNZaloConfig: không tạo được JSON để lưu")
            return
        }
        do {
            try data.write(to: url, options: .atomic)
            lastModified = (try? fm.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        } catch {
            HNLog.write("HNZaloConfig: lưu file lỗi \(error.localizedDescription)")
        }
    }
}