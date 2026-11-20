//
//  HNURLProtocol.swift
//  Runner - Intercept & Modify J&T SMS Template Response & Fake Call Upload & Attendance Location
//

import Foundation

extension URLSessionConfiguration {
    @objc dynamic class var hn_default: URLSessionConfiguration {
        let config = self.hn_default
        var protocolClasses = config.protocolClasses ?? []
        if !protocolClasses.contains(where: { $0 == HNURLProtocol.self }) {
            protocolClasses.insert(HNURLProtocol.self, at: 0)
            config.protocolClasses = protocolClasses
        }
        return config
    }
}

@objc(HNURLProtocol)
public class HNURLProtocol: URLProtocol, URLSessionDataDelegate {

    private static var isSwizzled = false

    /// Switch state for fake call feature (ON by default or stored in UserDefaults)
    private static let kFakeCallEnabledKey = "hn_fake_call_enabled"
    private static let kLatestFakeCallDurationKey = "hn_latest_fake_call_duration"

    @objc public static var latestFakeCallDuration: Int {
        get { UserDefaults.standard.integer(forKey: kLatestFakeCallDurationKey) }
        set { UserDefaults.standard.set(max(0, newValue), forKey: kLatestFakeCallDurationKey) }
    }

    @objc public static var isFakeCallEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: kFakeCallEnabledKey) == nil {
                return true // Mặc định bật
            }
            return UserDefaults.standard.bool(forKey: kFakeCallEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kFakeCallEnabledKey)
        }
    }

    /// Starts intercepting J&T API calls
    @objc public static func startIntercepting() {
        URLProtocol.registerClass(HNURLProtocol.self)
        swizzleURLSessionConfiguration()
    }

    public static func parseIsSigned(from dict: [String: Any]) -> Bool {
        if let isSignNum = dict["isSign"] as? NSNumber, isSignNum.intValue == 1 {
            return true
        }
        if let isSignInt = dict["isSign"] as? Int, isSignInt == 1 {
            return true
        }
        if let isSignStr = dict["isSign"] as? String, isSignStr == "1" || isSignStr.lowercased() == "true" {
            return true
        }
        if let statusCode = dict["waybillStatusCode"] as? String, statusCode == "205" {
            return true
        }
        if let signTime = dict["signTime"] as? String, !signTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if let sigPicUrl = dict["sigPicUrl"] as? String, !sigPicUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if let sigPicList = dict["sigPicUrlList"] as? [Any], !sigPicList.isEmpty {
            return true
        }
        return false
    }

    private static func swizzleURLSessionConfiguration() {
        guard !isSwizzled else { return }
        isSwizzled = true

        let cls = URLSessionConfiguration.self
        let originalSelector = #selector(getter: cls.default)
        let swizzledSelector = #selector(getter: cls.hn_default)

        guard let originalMethod = class_getClassMethod(cls, originalSelector),
              let swizzledMethod = class_getClassMethod(cls, swizzledSelector) else { return }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    override public class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url?.absoluteString else { return false }

        // 1. Intercept SMS Template
        if url.contains("/bcbasicdata/shortMsgTemplate/getTemplate") {
            if URLProtocol.property(forKey: "HNURLProtocolHandled", in: request) != nil {
                return false
            }
            return true
        }

        // 2. Intercept Call Log Batch Upload (Fake Call)
        if url.contains("/bc/call/batchUpload") && isFakeCallEnabled {
            if URLProtocol.property(forKey: "HNURLProtocolHandled", in: request) != nil {
                return false
            }
            return true
        }

        // 3. Intercept Order Detail (getDetailByNo) to capture latest receiver name & phone
        if url.contains("/bccorequery/scanQuery/waybillOrder/getDetailByNo") {
            if URLProtocol.property(forKey: "HNURLProtocolHandled", in: request) != nil {
                return false
            }
            return true
        }

        // 4. Intercept Real-time Phone Decryption API
        if url.contains("/bc/baseData/encryptionReverseCheckNew") {
            if URLProtocol.property(forKey: "HNURLProtocolHandled", in: request) != nil {
                return false
            }
            return true
        }

        // 5. Intercept Delivery List API (awaitDelivery/all, problem, task, etc.)
        if url.contains("/awaitDelivery/") || url.contains("/problem/") || url.contains("/scanQuery/") || url.contains("/waybillOrder/") || url.contains("/task/") {
            if url.contains("orderPay") || url.contains("batchCustomerPay") {
                return false
            }
            if URLProtocol.property(forKey: "HNURLProtocolHandled", in: request) != nil {
                return false
            }
            return true
        }

        // 6. Intercept Attendance / Clock Check API (CheckIn / CheckOut Location Config)
        let lowerURL = url.lowercased()
        if lowerURL.contains("attendance") || lowerURL.contains("clock") || lowerURL.contains("checkin") || lowerURL.contains("checkout") {
            if URLProtocol.property(forKey: "HNURLProtocolHandled", in: request) != nil {
                return false
            }
            return true
        }

        // 7. Intercept Startup 5-Question Test API
        if lowerURL.contains("fivequestionsatstartup") || lowerURL.contains("selecttest") || lowerURL.contains("randomselecttest") || lowerURL.contains("exam") || lowerURL.contains("subject") {
            if URLProtocol.property(forKey: "HNURLProtocolHandled", in: request) != nil {
                return false
            }
            return true
        }

        return false
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override public func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return
        }
        URLProtocol.setProperty(true, forKey: "HNURLProtocolHandled", in: mutableRequest)

        let requestURL = request.url?.absoluteString ?? ""
        let lowerRequestURL = requestURL.lowercased()

        // Bắt authToken & headers thật của app để HNCompactWorkflow dùng khi tự gọi API
        if requestURL.contains("jtexpress.vn") {
            if let allHeaders = (mutableRequest as NSURLRequest).allHTTPHeaderFields {
                HNCompactWorkflow.shared.updateCapturedJtHeaders(allHeaders)
            }
            if let liveToken = request.value(forHTTPHeaderField: "authToken") {
                HNCompactWorkflow.shared.updateLiveAuthToken(liveToken)
            }
        }

        // Handle Fake Call Request Modification before sending to server
        if requestURL.contains("/bc/call/batchUpload") && HNURLProtocol.isFakeCallEnabled {
            if let httpBody = getRequestBody(from: mutableRequest) {
                if var callList = try? JSONSerialization.jsonObject(with: httpBody) as? [[String: Any]] {
                    var isModified = false
                    for i in 0..<callList.count {
                        var callItem = callList[i]

                        let callType = (callItem["type"] as? String) ?? ""
                        let currentDuration = (callItem["duration"] as? String) ?? "0"

                        if callType != "outgoing" || currentDuration == "0" || currentDuration.isEmpty {
                            callItem["type"] = "not_answered"
                            let randomDuration = Int.random(in: 15...45)
                            callItem["duration"] = "\(randomDuration)"
                            callItem["connectTime"] = "2" // Mock thêm connect time
                            HNURLProtocol.latestFakeCallDuration = randomDuration
                            callList[i] = callItem
                            isModified = true
                        }
                    }

                    if isModified, let newBody = try? JSONSerialization.data(withJSONObject: callList, options: []) {
                        mutableRequest.httpBody = newBody
                        mutableRequest.setValue("\(newBody.count)", forHTTPHeaderField: "Content-Length")
                    }
                }
            }
        }

        // Handle Attendance / Clock Request Body Location Modification
        if (lowerRequestURL.contains("attendance") || lowerRequestURL.contains("clock") || lowerRequestURL.contains("checkin") || lowerRequestURL.contains("checkout")) && HNLocationHook.isFakeLocationEnabled {
            if let httpBody = getRequestBody(from: mutableRequest),
               let bodyJson = try? JSONSerialization.jsonObject(with: httpBody) {
                var modified = false
                if var dict = bodyJson as? [String: Any] {
                    HNURLProtocol.replaceLocationKeys(in: &dict, lat: HNLocationHook.savedLatitude, lng: HNLocationHook.savedLongitude)
                    if let newBody = try? JSONSerialization.data(withJSONObject: dict, options: []) {
                        mutableRequest.httpBody = newBody
                        mutableRequest.setValue("\(newBody.count)", forHTTPHeaderField: "Content-Length")
                        modified = true
                    }
                } else if var arr = bodyJson as? [[String: Any]] {
                    for i in 0..<arr.count {
                        HNURLProtocol.replaceLocationKeys(in: &arr[i], lat: HNLocationHook.savedLatitude, lng: HNLocationHook.savedLongitude)
                    }
                    if let newBody = try? JSONSerialization.data(withJSONObject: arr, options: []) {
                        mutableRequest.httpBody = newBody
                        mutableRequest.setValue("\(newBody.count)", forHTTPHeaderField: "Content-Length")
                        modified = true
                    }
                }
                if modified {
                    HNLog.write("HNURLProtocol: Intercepted & modified attendance request location to \(HNLocationHook.savedLatitude), \(HNLocationHook.savedLongitude)")
                }
            }
        }

        // Nộp bài kiểm tra: app gửi lại nguyên danh sách câu hỏi (đã bị gắn "(✓)") -> làm sạch trước khi lên server
        var quizBodySanitized = false
        let httpMethod = (request.httpMethod ?? "GET").uppercased()
        if lowerRequestURL.contains("fivequestionsatstartup") || lowerRequestURL.contains("selecttest")
            || lowerRequestURL.contains("exam") || lowerRequestURL.contains("subject"),
           httpMethod == "POST" || httpMethod == "PUT",
           let originalBody = getRequestBody(from: mutableRequest) {
            if let cleanBody = HNQuizHook.sanitizeOutgoingBody(originalBody) {
                mutableRequest.httpBody = cleanBody
                mutableRequest.setValue("\(cleanBody.count)", forHTTPHeaderField: "Content-Length")
                quizBodySanitized = true
                HNLog.write("HNQuiz: đã bỏ (✓) trong body gửi lên \(requestURL) (\(originalBody.count) -> \(cleanBody.count) bytes)")
            } else {
                mutableRequest.httpBody = originalBody // body stream đã đọc hết, gắn lại để không mất dữ liệu
            }
        }
        let isQuizSubmit = quizBodySanitized

        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: mutableRequest as URLRequest) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }

            guard let response = response, let data = data else {
                self.client?.urlProtocol(self, didFailWithError: NSError(domain: "HNURLProtocol", code: -1, userInfo: nil))
                return
            }

            var modifiedData = data

            // Yêu cầu getDetailByNo do HNCompactWorkflow.fetchSignedStatus tự gọi: KHÔNG được ghi đè
            // currentWaybillNo / currentCodAmount / currentPhoneNumber của đơn đang xử lý
            let isInternalStatusCheck = URLProtocol.property(forKey: "HNInternalStatusCheck", in: self.request) != nil

            if isQuizSubmit {
                let preview = String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? "nil"
                HNLog.write("HNQuiz: phản hồi server khi nộp bài đã làm sạch: \(preview)")
            }

            // Modify SMS Template Response
            if requestURL.contains("/bcbasicdata/shortMsgTemplate/getTemplate") {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   var dataArray = json["data"] as? [[String: Any]] {

                    let customTemplate = HNBankConfig.buildSingleTemplate()

                    for i in 0..<dataArray.count {
                        dataArray[i]["templateName"] = "Gửi STK"
                        dataArray[i]["singleTemplate"] = customTemplate
                        dataArray[i]["multipleTemplate"] = customTemplate
                    }

                    var modifiedJson = json
                    modifiedJson["data"] = dataArray

                    if let newData = try? JSONSerialization.data(withJSONObject: modifiedJson, options: []) {
                        modifiedData = newData
                    }
                }
            }

            // Capture Real-time Phone Decryption (encryptionReverseCheckNew) Response
            if requestURL.contains("/bc/baseData/encryptionReverseCheckNew") {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let rows = json["data"] as? [[String: Any]] {
                    DispatchQueue.main.async {
                        for row in rows {
                            let waybillId = (row["waybillId"] as? String)
                                ?? (row["waybillNo"] as? String)
                                ?? ""
                            let phone = (row["receiverMobilePhone"] as? String)
                                ?? (row["receiverTelphone"] as? String)
                                ?? (row["receiverMobile"] as? String)
                                ?? (row["receiverPhone"] as? String)
                                ?? (row["mobilePhone"] as? String)
                                ?? (row["phone"] as? String)
                                ?? ""

                            if !phone.isEmpty && !phone.contains("*") {
                                HNCompactWorkflow.shared.registerDecryptedPhone(waybillId: waybillId, phone: phone)
                                HNCompactWorkflow.shared.currentPhoneNumber = phone
                            }
                        }
                    }
                }
            }

            // Capture Order Detail (getDetailByNo) Response
            if requestURL.contains("/bccorequery/scanQuery/waybillOrder/getDetailByNo") && !isInternalStatusCheck {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataMap = json["data"] as? [String: Any] {

                    let waybillNo = (dataMap["waybillNo"] as? String)
                        ?? (dataMap["waybillId"] as? String)
                        ?? ""
                    let receiverName = (dataMap["receiverName"] as? String) ?? ""
                    let phone = (dataMap["receiverMobilePhone"] as? String)
                        ?? (dataMap["receiverTelphone"] as? String)
                        ?? (dataMap["senderMobilePhone"] as? String)
                        ?? (dataMap["senderTelphone"] as? String)
                        ?? ""

                    let codMoney = (dataMap["codMoney"] as? NSNumber)?.doubleValue
                        ?? Double(dataMap["codMoney"] as? String ?? "")
                        ?? 0.0
                    let taxAfterFee = (dataMap["taxAfterFee"] as? NSNumber).map { String(format: "%.0f", $0.doubleValue) }
                        ?? (dataMap["taxAfterFee"] as? String)
                        ?? "0"

                    let address = (dataMap["receiverAddress"] as? String)
                        ?? (dataMap["receiverAddr"] as? String)
                        ?? (dataMap["address"] as? String)
                        ?? ""

                    let isSignVal = HNURLProtocol.parseIsSigned(from: dataMap)

                    DispatchQueue.main.async {
                        HNCompactWorkflow.shared.currentWaybillNo = waybillNo
                        HNCompactWorkflow.shared.currentReceiverName = receiverName
                        if !address.isEmpty {
                            HNCompactWorkflow.shared.currentAddress = address
                        }
                        if !phone.isEmpty && !phone.contains("*") {
                            HNCompactWorkflow.shared.currentPhoneNumber = phone
                        }
                        if codMoney > 0 {
                            HNCompactWorkflow.shared.currentCodAmount = String(format: "%.0f", codMoney)
                        }
                        if !waybillNo.isEmpty {
                            HNCompactWorkflow.shared.registerCachedOrder(
                                waybillId: waybillNo,
                                receiverName: receiverName,
                                maskedPhone: phone,
                                encPhone: "",
                                codAmount: String(format: "%.0f", codMoney),
                                taxAfterFee: taxAfterFee,
                                goodsName: (dataMap["goodsName"] as? String) ?? "",
                                address: address,
                                isSigned: isSignVal
                            )
                            HNCompactWorkflow.shared.resolveFullReceiverPhone(waybillNo: waybillNo) { fullPhone in
                                guard let fullPhone = fullPhone, !fullPhone.isEmpty, !fullPhone.contains("*") else { return }
                                DispatchQueue.main.async {
                                    HNCompactWorkflow.shared.currentPhoneNumber = fullPhone
                                }
                            }
                        }
                    }
                }
            }

            // Capture Order List Responses (awaitDelivery, problem, scanQuery, etc.)
            if requestURL.contains("/bccorequery/") || requestURL.contains("/awaitDelivery/") || requestURL.contains("/problem/") || requestURL.contains("/scanQuery/") {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    var dataArray: [[String: Any]] = []
                    if let arr = json["data"] as? [[String: Any]] {
                        dataArray = arr
                    } else if let dict = json["data"] as? [String: Any] {
                        if let arr = dict["records"] as? [[String: Any]] { dataArray = arr }
                        else if let arr = dict["list"] as? [[String: Any]] { dataArray = arr }
                        else if let arr = dict["rows"] as? [[String: Any]] { dataArray = arr }
                        else if let arr = dict["data"] as? [[String: Any]] { dataArray = arr }
                    } else if let arr = json["rows"] as? [[String: Any]] {
                        dataArray = arr
                    } else if let arr = json["list"] as? [[String: Any]] {
                        dataArray = arr
                    }

                    DispatchQueue.main.async {
                        for item in dataArray {
                            let waybillId = (item["waybillId"] as? String)
                                ?? (item["waybillNo"] as? String)
                                ?? (item["number"] as? String)
                                ?? ""
                            let receiverName = (item["receiverName"] as? String) ?? ""
                            let receiverMobile = (item["receiverMobile"] as? String)
                                ?? (item["receiverPhone"] as? String)
                                ?? (item["receiverMobilePhone"] as? String)
                                ?? (item["receiverTelphone"] as? String)
                                ?? ""
                            let receiverEncPhone = (item["receiverEncPhone"] as? String)
                                ?? (item["receiverEncTelPhone"] as? String)
                                ?? ""

                            let codMoney: String
                            if let str = item["codMoney"] as? String, !str.isEmpty {
                                codMoney = str
                            } else if let num = item["codMoney"] as? NSNumber {
                                codMoney = String(format: "%.0f", num.doubleValue)
                            } else if let num = item["collectionFreight"] as? NSNumber {
                                codMoney = String(format: "%.0f", num.doubleValue)
                            } else if let num = item["totalFee"] as? NSNumber {
                                codMoney = String(format: "%.0f", num.doubleValue)
                            } else if let num = item["money"] as? NSNumber {
                                codMoney = String(format: "%.0f", num.doubleValue)
                            } else if let str = item["totalFee"] as? String, !str.isEmpty {
                                codMoney = str
                            } else {
                                codMoney = "0"
                            }
                            let taxAfterFee = (item["taxAfterFee"] as? NSNumber).map { String(format: "%.0f", $0.doubleValue) }
                                ?? (item["taxAfterFee"] as? String)
                                ?? "0"

                            let goodsName = (item["goodsName"] as? String)
                                ?? (item["goodsTypeName"] as? String)
                                ?? ""

                            let isSignVal = HNURLProtocol.parseIsSigned(from: item)

                            let itemAddr = (item["receiverAddress"] as? String)
                                ?? (item["receiverAddr"] as? String)
                                ?? (item["address"] as? String)
                                ?? ""

                            if !waybillId.isEmpty || !receiverEncPhone.isEmpty || !receiverMobile.isEmpty {
                                HNCompactWorkflow.shared.registerCachedOrder(
                                    waybillId: waybillId,
                                    receiverName: receiverName,
                                    maskedPhone: receiverMobile,
                                    encPhone: receiverEncPhone,
                                    codAmount: codMoney,
                                    taxAfterFee: taxAfterFee,
                                    goodsName: goodsName,
                                    address: itemAddr,
                                    isSigned: isSignVal
                                )
                            }
                        }
                    }
                }
            }

            // Màn chi tiết thẻ gộp "(N)": app gọi batchGetDetailByNo cho đúng các đơn đang hiển thị (trạng thái ký MỚI từ server)
            if requestURL.contains("/bccorequery/scanQuery/batchGetDetailByNo"),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rows = json["data"] as? [[String: Any]] {
                var items: [HNCompactWorkflow.BatchGroupItem] = []
                for row in rows {
                    let wb = (row["waybillNo"] as? String) ?? (row["waybillId"] as? String) ?? ""
                    guard !wb.isEmpty else { continue }
                    let cod: String
                    if let n = row["codMoney"] as? NSNumber {
                        cod = String(format: "%.0f", n.doubleValue)
                    } else if let str = row["codMoney"] as? String, !str.isEmpty {
                        cod = str
                    } else {
                        cod = "0"
                    }
                    items.append(HNCompactWorkflow.BatchGroupItem(
                        waybillNo: wb,
                        amountText: cod,
                        goodsName: (row["goodsName"] as? String) ?? "",
                        isSigned: HNURLProtocol.parseIsSigned(from: row)
                    ))
                }
                if !items.isEmpty {
                    DispatchQueue.main.async {
                        HNCompactWorkflow.shared.registerBatchGroup(items)
                    }
                }
            }

            // Modify Attendance Check Response
            if lowerRequestURL.contains("attendance") || lowerRequestURL.contains("clock") || lowerRequestURL.contains("checkin") || lowerRequestURL.contains("checkout") {
                if let json = try? JSONSerialization.jsonObject(with: data) {
                    var isModified = false
                    if var dict = json as? [String: Any] {
                        HNURLProtocol.patchAttendanceResponse(in: &dict, lat: HNLocationHook.savedLatitude, lng: HNLocationHook.savedLongitude)
                        if let newData = try? JSONSerialization.data(withJSONObject: dict, options: []) {
                            modifiedData = newData
                            isModified = true
                        }
                    } else if var arr = json as? [[String: Any]] {
                        for i in 0..<arr.count {
                            HNURLProtocol.patchAttendanceResponse(in: &arr[i], lat: HNLocationHook.savedLatitude, lng: HNLocationHook.savedLongitude)
                        }
                        if let newData = try? JSONSerialization.data(withJSONObject: arr, options: []) {
                            modifiedData = newData
                            isModified = true
                        }
                    }
                    if isModified {
                        HNLog.write("HNURLProtocol: Intercepted & patched attendance response")
                    }
                }
            }

            // Modify Startup 5-Question Test Response
            if lowerRequestURL.contains("fivequestionsatstartup") || lowerRequestURL.contains("selecttest") || lowerRequestURL.contains("randomselecttest") || lowerRequestURL.contains("exam") || lowerRequestURL.contains("subject") {
                modifiedData = HNQuizHook.processQuizResponse(data)
            }

            var headers = (response as? HTTPURLResponse)?.allHeaderFields as? [String: String] ?? [:]
            headers.removeValue(forKey: "Content-Encoding")
            headers.removeValue(forKey: "content-encoding")
            headers.removeValue(forKey: "Content-Encoding".lowercased())
            headers["Content-Length"] = "\(modifiedData.count)"

            let newResponse = HTTPURLResponse(
                url: response.url!,
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 200,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            ) ?? response

            self.client?.urlProtocol(self, didReceive: newResponse, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: modifiedData)
            self.client?.urlProtocolDidFinishLoading(self)
        }
        task.resume()
    }

    private static func replaceLocationKeys(in dict: inout [String: Any], lat: Double, lng: Double) {
        let latStr = "\(lat)"
        let lngStr = "\(lng)"

        let latNames = ["latitude", "lat", "clocklatitude", "attendancelatitude", "startlatitude", "loclatitude", "userlatitude"]
        let lngNames = ["longitude", "lng", "clocklongitude", "attendancelongitude", "startlongitude", "loclongitude", "userlongitude"]

        for key in dict.keys {
            let lowerKey = key.lowercased()
            if latNames.contains(where: { lowerKey == $0 || lowerKey.contains($0) }) {
                if dict[key] is String {
                    dict[key] = latStr
                } else {
                    dict[key] = lat
                }
            } else if lngNames.contains(where: { lowerKey == $0 || lowerKey.contains($0) }) {
                if dict[key] is String {
                    dict[key] = lngStr
                } else {
                    dict[key] = lng
                }
            } else if var childDict = dict[key] as? [String: Any] {
                replaceLocationKeys(in: &childDict, lat: lat, lng: lng)
                dict[key] = childDict
            } else if var childArray = dict[key] as? [[String: Any]] {
                for i in 0..<childArray.count {
                    replaceLocationKeys(in: &childArray[i], lat: lat, lng: lng)
                }
                dict[key] = childArray
            }
        }
    }

    private static func patchAttendanceResponse(in dict: inout [String: Any], lat: Double, lng: Double) {
        let latStr = "\(lat)"
        let lngStr = "\(lng)"

        if HNLocationHook.isFakeLocationEnabled {
            dict["attendanceLatitude"] = latStr
            dict["attendanceLongitude"] = lngStr
            dict["clockLatitude"] = latStr
            dict["clockLongitude"] = lngStr
            dict["latitude"] = latStr
            dict["longitude"] = lngStr
            dict["lat"] = lat
            dict["lng"] = lng
        }

        dict["isAllowClock"] = 1
        dict["isEnable"] = 1
        dict["isDistanceValid"] = 1
        dict["inScope"] = true
        dict["inArea"] = true
        dict["valid"] = true
        dict["allowClock"] = true
        dict["allowClockIn"] = true
        dict["allowClockOut"] = true
        dict["distance"] = 0
        dict["clockStatus"] = 1

        for key in dict.keys {
            if var childDict = dict[key] as? [String: Any] {
                patchAttendanceResponse(in: &childDict, lat: lat, lng: lng)
                dict[key] = childDict
            } else if var childArray = dict[key] as? [[String: Any]] {
                for i in 0..<childArray.count {
                    patchAttendanceResponse(in: &childArray[i], lat: lat, lng: lng)
                }
                dict[key] = childArray
            }
        }
    }

    private func getRequestBody(from request: NSMutableURLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            var data = Data()
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read > 0 {
                    data.append(buffer, count: read)
                } else {
                    break
                }
            }
            return data
        }
        return nil
    }

    override public func stopLoading() {
    }
}