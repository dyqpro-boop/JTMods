//
//  HNLocationHook.swift
//  Runner - Fake Location Manager & GPS Override
//

import Foundation
import CoreLocation
import UIKit

@objc(HNLocationHook)
public class HNLocationHook: NSObject, CLLocationManagerDelegate {

    @objc public static let shared = HNLocationHook()

    private static let kFakeLocationEnabledKey = "hn_fake_location_enabled"
    private static let kSavedLatitudeKey = "hn_saved_latitude"
    private static let kSavedLongitudeKey = "hn_saved_longitude"

    private static var isInstalled = false
    private var tempLocationManager: CLLocationManager?
    @objc public var isCapturingRealLocation = false

    // MARK: - Properties

    @objc public static var isFakeLocationEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: kFakeLocationEnabledKey) == nil {
                return true // Mặc định bật
            }
            return UserDefaults.standard.bool(forKey: kFakeLocationEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kFakeLocationEnabledKey)
            HNLog.write("HNLocationHook: Fake Location state set to \(newValue)")
        }
    }

    @objc public static var savedLatitude: Double {
        get {
            let val = UserDefaults.standard.double(forKey: kSavedLatitudeKey)
            return val != 0 ? val : 11.8333 // Default Lâm Đồng
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kSavedLatitudeKey)
        }
    }

    @objc public static var savedLongitude: Double {
        get {
            let val = UserDefaults.standard.double(forKey: kSavedLongitudeKey)
            return val != 0 ? val : 108.3333 // Default Lâm Đồng
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kSavedLongitudeKey)
        }
    }

    @objc public static var hasSavedLocation: Bool {
        UserDefaults.standard.object(forKey: kSavedLatitudeKey) != nil
            && UserDefaults.standard.object(forKey: kSavedLongitudeKey) != nil
    }

    @objc public static var googleMapsURL: URL? {
        guard hasSavedLocation else { return nil }
        let latitude = savedLatitude
        let longitude = savedLongitude
        guard latitude.isFinite, longitude.isFinite else { return nil }
        guard latitude >= -90, latitude <= 90, longitude >= -180, longitude <= 180 else { return nil }
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(latitude),\(longitude)")
    }

    public static func parseDMSCoordinates(_ value: String) -> (latitude: Double, longitude: Double)? {
        // Chuẩn hoá ký tự: bàn phím iOS (Smart Punctuation) tự đổi ' " thành ’ ” ... làm regex không khớp
        let text = value
            .replacingOccurrences(of: "\u{2018}", with: "'")   // ‘
            .replacingOccurrences(of: "\u{2019}", with: "'")   // ’
            .replacingOccurrences(of: "\u{2032}", with: "'")   // ′
            .replacingOccurrences(of: "\u{02B9}", with: "'")   // ʹ
            .replacingOccurrences(of: "\u{201C}", with: "\"")  // “
            .replacingOccurrences(of: "\u{201D}", with: "\"")  // ”
            .replacingOccurrences(of: "\u{2033}", with: "\"")  // ″
            .replacingOccurrences(of: "\u{02BA}", with: "\"")  // ʺ
            .replacingOccurrences(of: "\u{00BA}", with: "°")   // º
            .replacingOccurrences(of: "\u{02DA}", with: "°")   // ˚
            .replacingOccurrences(of: "\u{00A0}", with: " ")   // khoảng trắng không ngắt
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = "^([0-9]{1,3})°\\s*([0-5]?[0-9])'\\s*([0-5]?[0-9](?:\\.[0-9]+)?)\"\\s*([NSEW])\\s+([0-9]{1,3})°\\s*([0-5]?[0-9])'\\s*([0-5]?[0-9](?:\\.[0-9]+)?)\"\\s*([NSEW])$"
        guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = expression.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        let ranges = [1, 2, 3, 4, 5, 6, 7, 8].compactMap { index -> Range<String.Index>? in
            Range(match.range(at: index), in: text)
        }
        guard ranges.count == 8,
              let latitude = parseDMSCoordinateValue(
                  text,
                  degreeRange: ranges[0],
                  minuteRange: ranges[1],
                  secondRange: ranges[2],
                  directionRange: ranges[3]
              ),
              let longitude = parseDMSCoordinateValue(
                  text,
                  degreeRange: ranges[4],
                  minuteRange: ranges[5],
                  secondRange: ranges[6],
                  directionRange: ranges[7]
              ),
              latitude >= -90, latitude <= 90,
              longitude >= -180, longitude <= 180 else {
            return nil
        }

        return (latitude, longitude)
    }

    private static func parseDMSCoordinateValue(
        _ text: String,
        degreeRange: Range<String.Index>,
        minuteRange: Range<String.Index>,
        secondRange: Range<String.Index>,
        directionRange: Range<String.Index>
    ) -> Double? {
        guard let degreeValue = Double(text[degreeRange]),
              let minuteValue = Double(text[minuteRange]),
              let secondValue = Double(text[secondRange]) else {
            return nil
        }

        let direction = text[directionRange].uppercased()
        let coordinate = degreeValue + minuteValue / 60 + secondValue / 3600
        return direction == "S" || direction == "W" ? -coordinate : coordinate
    }

    // MARK: - Installation & Swizzling

    @objc public static func install() {
        guard !isInstalled else { return }
        isInstalled = true

        swizzleCLLocationManager()
    }

    private static func swizzleCLLocationManager() {
        let cls = CLLocationManager.self

        // 1. Class methods
        swizzleClassMethod(cls: cls, orig: #selector(CLLocationManager.locationServicesEnabled), swiz: #selector(CLLocationManager.hn_locationServicesEnabled))
        swizzleClassMethod(cls: cls, orig: #selector(CLLocationManager.authorizationStatus as () -> CLAuthorizationStatus), swiz: #selector(CLLocationManager.hn_authorizationStatus))

        // 2. Instance methods
        swizzleInstanceMethod(cls: cls, orig: NSSelectorFromString("authorizationStatus"), swiz: #selector(CLLocationManager.hn_instanceAuthorizationStatus))
        swizzleInstanceMethod(cls: cls, orig: #selector(getter: CLLocationManager.location), swiz: #selector(CLLocationManager.hn_location))
        swizzleInstanceMethod(cls: cls, orig: #selector(setter: CLLocationManager.delegate), swiz: #selector(CLLocationManager.hn_setDelegate(_:)))

        swizzleInstanceMethod(cls: cls, orig: #selector(CLLocationManager.requestWhenInUseAuthorization), swiz: #selector(CLLocationManager.hn_requestWhenInUseAuthorization))
        swizzleInstanceMethod(cls: cls, orig: #selector(CLLocationManager.requestAlwaysAuthorization), swiz: #selector(CLLocationManager.hn_requestAlwaysAuthorization))

        swizzleInstanceMethod(cls: cls, orig: #selector(CLLocationManager.startUpdatingLocation), swiz: #selector(CLLocationManager.hn_startUpdatingLocation))
        swizzleInstanceMethod(cls: cls, orig: #selector(CLLocationManager.requestLocation), swiz: #selector(CLLocationManager.hn_requestLocation))
        swizzleInstanceMethod(cls: cls, orig: #selector(CLLocationManager.startMonitoringSignificantLocationChanges), swiz: #selector(CLLocationManager.hn_startMonitoringSignificantLocationChanges))

        // 3. Accuracy Authorization (iOS 14+)
        let origAccuracy = NSSelectorFromString("accuracyAuthorization")
        let swizAccuracy = #selector(CLLocationManager.hn_accuracyAuthorization)
        if class_getInstanceMethod(cls, origAccuracy) != nil {
            swizzleInstanceMethod(cls: cls, orig: origAccuracy, swiz: swizAccuracy)
        }
    }

    private static func swizzleClassMethod(cls: AnyClass, orig: Selector, swiz: Selector) {
        guard let origMethod = class_getClassMethod(cls, orig),
              let swizMethod = class_getClassMethod(cls, swiz) else {
            HNLog.write("HNLocationHook: Failed to find class method \(orig)")
            return
        }
        method_exchangeImplementations(origMethod, swizMethod)
        HNLog.write("HNLocationHook: Swizzled class method \(orig) successfully")
    }

    private static func swizzleInstanceMethod(cls: AnyClass, orig: Selector, swiz: Selector) {
        guard let origMethod = class_getInstanceMethod(cls, orig),
              let swizMethod = class_getInstanceMethod(cls, swiz) else {
            HNLog.write("HNLocationHook: Failed to find instance method \(orig)")
            return
        }
        method_exchangeImplementations(origMethod, swizMethod)
        HNLog.write("HNLocationHook: Swizzled instance method \(orig) successfully")
    }

    // MARK: - Capture Current Real Location

    @objc public func captureAndSaveCurrentLocation(from presenter: UIViewController, completion: ((Bool) -> Void)? = nil) {
        let alert = UIAlertController(title: "LẤY VỊ TRÍ HIỆN TẠI", message: "Đang yêu cầu GPS lấy tọa độ thực của bạn...", preferredStyle: .alert)
        presenter.present(alert, animated: true)

        isCapturingRealLocation = true
        tempLocationManager = CLLocationManager()
        tempLocationManager?.delegate = self
        tempLocationManager?.desiredAccuracy = kCLLocationAccuracyBest

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.tempLocationManager?.requestWhenInUseAuthorization()
            self.tempLocationManager?.startUpdatingLocation()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            guard let self = self, self.isCapturingRealLocation else { return }
            self.isCapturingRealLocation = false
            self.tempLocationManager?.stopUpdatingLocation()
            self.tempLocationManager = nil

            alert.dismiss(animated: true) {
                let failAlert = UIAlertController(
                    title: "LỖI LẤY VỊ TRÍ",
                    message: "Không thể lấy tọa độ GPS thực tế. Đã sử dụng vị trí đã lưu gần nhất:\n\nLat: \(HNLocationHook.savedLatitude)\nLng: \(HNLocationHook.savedLongitude)",
                    preferredStyle: .alert
                )
                failAlert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
                presenter.present(failAlert, animated: true)
                completion?(false)
            }
        }
    }

    // CLLocationManagerDelegate
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isCapturingRealLocation, let loc = locations.last else { return }
        isCapturingRealLocation = false

        manager.stopUpdatingLocation()
        tempLocationManager = nil

        let lat = loc.coordinate.latitude
        let lng = loc.coordinate.longitude

        HNLocationHook.savedLatitude = lat
        HNLocationHook.savedLongitude = lng
        HNLog.write("HNLocationHook: Captured real location -> Lat: \(lat), Lng: \(lng)")

        DispatchQueue.main.async {
            if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
               let topVC = window.rootViewController {
                var current = topVC
                while let presented = current.presentedViewController {
                    current = presented
                }
                if let alert = current as? UIAlertController, alert.title == "LẤY VỊ TRÍ HIỆN TẠI" {
                    alert.dismiss(animated: true) {
                        self.showSuccessLocationDialog(lat: lat, lng: lng, from: current)
                    }
                } else {
                    self.showSuccessLocationDialog(lat: lat, lng: lng, from: current)
                }
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        HNLog.write("HNLocationHook: GPS Capture failed: \(error.localizedDescription)")
    }

    private func showSuccessLocationDialog(lat: Double, lng: Double, from presenter: UIViewController) {
        let formattedLat = String(format: "%.6f", lat)
        let formattedLng = String(format: "%.6f", lng)
        let successAlert = UIAlertController(
            title: "ĐÃ LƯU VỊ TRÍ ✅",
            message: "Tọa độ GPS hiện tại đã được lưu làm vị trí giả lập cố định:\n\nLatitude: \(formattedLat)\nLongitude: \(formattedLng)",
            preferredStyle: .alert
        )
        successAlert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(successAlert, animated: true)
    }
}

// MARK: - Swizzled CLLocationManager Methods

private extension CLLocationManager {

    @objc class func hn_locationServicesEnabled() -> Bool {
        return true
    }

    @objc class func hn_authorizationStatus() -> CLAuthorizationStatus {
        return .authorizedAlways
    }

    @objc func hn_instanceAuthorizationStatus() -> CLAuthorizationStatus {
        return .authorizedAlways
    }

    @objc func hn_accuracyAuthorization() -> Int {
        return 0 // CLAccuracyAuthorization.fullAccuracy
    }

    @objc func hn_location() -> CLLocation? {
        guard HNLocationHook.isFakeLocationEnabled && !HNLocationHook.shared.isCapturingRealLocation else {
            return self.hn_location()
        }
        let fakeLat = HNLocationHook.savedLatitude
        let fakeLng = HNLocationHook.savedLongitude
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: fakeLat, longitude: fakeLng),
            altitude: 10.0,
            horizontalAccuracy: 3.0,
            verticalAccuracy: 3.0,
            course: 0.0,
            speed: 0.0,
            timestamp: Date()
        )
    }

    @objc func hn_setDelegate(_ newDelegate: CLLocationManagerDelegate?) {
        hn_setDelegate(newDelegate)
        guard let delegate = newDelegate else { return }

        if HNLocationHook.isFakeLocationEnabled && !HNLocationHook.shared.isCapturingRealLocation {
            fireFakeLocationToDelegate(delegate)
        }
    }

    @objc func hn_requestWhenInUseAuthorization() {
        if HNLocationHook.isFakeLocationEnabled && !HNLocationHook.shared.isCapturingRealLocation {
            if let delegate = self.delegate {
                fireFakeLocationToDelegate(delegate)
            }
        } else {
            hn_requestWhenInUseAuthorization()
        }
    }

    @objc func hn_requestAlwaysAuthorization() {
        if HNLocationHook.isFakeLocationEnabled && !HNLocationHook.shared.isCapturingRealLocation {
            if let delegate = self.delegate {
                fireFakeLocationToDelegate(delegate)
            }
        } else {
            hn_requestAlwaysAuthorization()
        }
    }

    @objc func hn_startUpdatingLocation() {
        if HNLocationHook.isFakeLocationEnabled && !HNLocationHook.shared.isCapturingRealLocation {
            guard let delegate = self.delegate else { return }
            fireFakeLocationToDelegate(delegate)
        } else {
            hn_startUpdatingLocation()
        }
    }

    @objc func hn_requestLocation() {
        if HNLocationHook.isFakeLocationEnabled && !HNLocationHook.shared.isCapturingRealLocation {
            guard let delegate = self.delegate else { return }
            fireFakeLocationToDelegate(delegate)
        } else {
            hn_requestLocation()
        }
    }

    @objc func hn_startMonitoringSignificantLocationChanges() {
        if HNLocationHook.isFakeLocationEnabled && !HNLocationHook.shared.isCapturingRealLocation {
            guard let delegate = self.delegate else { return }
            fireFakeLocationToDelegate(delegate)
        } else {
            hn_startMonitoringSignificantLocationChanges()
        }
    }

    private func fireFakeLocationToDelegate(_ delegate: CLLocationManagerDelegate) {
        guard HNLocationHook.isFakeLocationEnabled && !HNLocationHook.shared.isCapturingRealLocation else { return }

        for delay in [0.0, 0.05, 0.2, 0.5, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                let fakeLoc = CLLocation(
                    coordinate: CLLocationCoordinate2D(latitude: HNLocationHook.savedLatitude, longitude: HNLocationHook.savedLongitude),
                    altitude: 10.0,
                    horizontalAccuracy: 3.0,
                    verticalAccuracy: 3.0,
                    course: 0.0,
                    speed: 0.0,
                    timestamp: Date()
                )
                delegate.locationManager?(self, didChangeAuthorization: .authorizedAlways)
                if #available(iOS 14.0, *) {
                    delegate.locationManagerDidChangeAuthorization?(self)
                }
                delegate.locationManager?(self, didUpdateLocations: [fakeLoc])

                let legacySel = Selector(("locationManager:didUpdateToLocation:fromLocation:"))
                if (delegate as AnyObject).responds(to: legacySel) {
                    let imp = (delegate as AnyObject).method(for: legacySel)
                    typealias LegacyFunc = @convention(c) (AnyObject, Selector, CLLocationManager, CLLocation, CLLocation) -> Void
                    let fn = unsafeBitCast(imp, to: LegacyFunc.self)
                    fn(delegate, legacySel, self, fakeLoc, fakeLoc)
                }
            }
        }
    }
}
