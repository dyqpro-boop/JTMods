import UIKit
import AVFoundation

@objc public class HNCameraHook: NSObject {
    static var proxyKey: UInt8 = 0
    public static var mockedImageData: Data? = nil
    private static var didSwizzlePhoto = false

    @objc public static func setup() {
        HNLog.write("HNCameraHook: Setting up...")
        swizzleAVCapturePhotoOutput()
    }

    private static func swizzleAVCapturePhotoOutput() {
        guard let originalMethod = class_getInstanceMethod(AVCapturePhotoOutput.self, #selector(AVCapturePhotoOutput.capturePhoto(with:delegate:))),
              let swizzledMethod = class_getInstanceMethod(AVCapturePhotoOutput.self, #selector(AVCapturePhotoOutput.hn_capturePhoto(with:delegate:))) else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    public static func swizzleFileDataRepIfNeeded() {
        guard !didSwizzlePhoto else { return }
        didSwizzlePhoto = true
        guard let originalMethod = class_getInstanceMethod(AVCapturePhoto.self, NSSelectorFromString("fileDataRepresentation")),
              let swizzledMethod = class_getInstanceMethod(AVCapturePhoto.self, #selector(AVCapturePhoto.hn_fileDataRepresentation)) else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

extension AVCapturePhotoOutput {
    @objc dynamic func hn_capturePhoto(with settings: AVCapturePhotoSettings, delegate: AVCapturePhotoCaptureDelegate) {
        HNLog.write("📸 AVCapturePhotoOutput capturePhoto called! Delegate is: \(String(describing: type(of: delegate)))")

        let proxy = HNCaptureDelegateProxy(original: delegate)
        objc_setAssociatedObject(delegate, &HNCameraHook.proxyKey, proxy, .OBJC_ASSOCIATION_RETAIN)

        self.hn_capturePhoto(with: settings, delegate: proxy)
    }
}

extension AVCapturePhoto {
    @objc dynamic func hn_fileDataRepresentation() -> Data? {
        if let mocked = HNCameraHook.mockedImageData {
            return mocked
        }
        return self.hn_fileDataRepresentation()
    }
}

extension UIImage {
    func hn_normalized() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}

class HNCaptureDelegateProxy: NSObject, AVCapturePhotoCaptureDelegate {
    weak var originalDelegate: AVCapturePhotoCaptureDelegate?

    init(original: AVCapturePhotoCaptureDelegate) {
        self.originalDelegate = original
        super.init()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(photoOutput(_:didFinishProcessingPhoto:error:)) {
            return true
        }
        return originalDelegate?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        return originalDelegate
    }

    @available(iOS 11.0, *)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        HNLog.write("📸 HNCaptureDelegateProxy intercepted photoOutput!")
        guard let delegate = originalDelegate else { return }

        guard let data = photo.perform(NSSelectorFromString("fileDataRepresentation"))?.takeUnretainedValue() as? Data, let image = UIImage(data: data) else {
            delegate.photoOutput?(output, didFinishProcessingPhoto: photo, error: error)
            return
        }

        let normalizedImage = image.hn_normalized()
        let topVC = UIApplication.shared.topViewController()
        let dashedRects = findDashedBoxes(in: topVC?.view)

        let imgSize = normalizedImage.size
        var houseRect = CGRect(x: imgSize.width * 0.04, y: imgSize.height * 0.243, width: imgSize.width * 0.92, height: imgSize.height * 0.105)
        var barcodeRect = CGRect(x: imgSize.width * 0.04, y: imgSize.height * 0.486, width: imgSize.width * 0.92, height: imgSize.height * 0.110)

        if dashedRects.count >= 2 {
            let sorted = dashedRects.sorted { $0.minY < $1.minY }
            let screenSize = UIScreen.main.bounds.size
            let scaleX = imgSize.width / screenSize.width
            let scaleY = imgSize.height / screenSize.height
            let scale = max(scaleX, scaleY)

            let offsetX = (screenSize.width * scale - imgSize.width) / 2
            let offsetY = (screenSize.height * scale - imgSize.height) / 2

            func convert(_ r: CGRect) -> CGRect {
                return CGRect(
                    x: r.minX * scale - offsetX,
                    y: r.minY * scale - offsetY,
                    width: r.width * scale,
                    height: r.height * scale
                )
            }
            houseRect = convert(sorted[0])
            barcodeRect = convert(sorted[1])
        } else {
            HNLog.write("⚠️ Không tìm thấy đủ 2 khung đứt nét, dùng tỉ lệ fallback.")
        }

        func padAndClamp(_ r: CGRect) -> CGRect {
            let dx = r.width * 0.08
            let dy = r.height * 0.08
            var padded = r.insetBy(dx: -dx, dy: -dy)
            padded.origin.x = max(0, padded.origin.x)
            padded.origin.y = max(0, padded.origin.y)
            if padded.maxX > imgSize.width { padded.size.width = imgSize.width - padded.origin.x }
            if padded.maxY > imgSize.height { padded.size.height = imgSize.height - padded.origin.y }
            return padded
        }

        houseRect = padAndClamp(houseRect)
        barcodeRect = padAndClamp(barcodeRect)

        HNLog.write("📸 Gốc: \(imgSize), Crop Nhà: \(houseRect), Crop Barcode: \(barcodeRect)")

        guard let cgImage = normalizedImage.cgImage,
              let houseCg = cgImage.cropping(to: houseRect),
              let barcodeCg = cgImage.cropping(to: barcodeRect) else {
            delegate.photoOutput?(output, didFinishProcessingPhoto: photo, error: error)
            return
        }

        let fullData = normalizedImage.jpegData(compressionQuality: 0.9)
        let houseData = fullData
        let barcodeData = fullData

        HNCameraHook.swizzleFileDataRepIfNeeded()

        // Gửi ảnh 1 lần. Chỉ gửi lại nếu app báo "Không nhận diện được mã vận đơn"
        HNCameraHook.mockedImageData = barcodeData
        delegate.photoOutput?(output, didFinishProcessingPhoto: photo, error: error)

        func poll(_ tick: Int, retries: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if tick >= 12 {
                    HNCameraHook.mockedImageData = nil
                    return
                }
                let topView = UIApplication.shared.topViewController()?.view
                if retries > 0 && self.hasOCRError(in: topView) {
                    HNLog.write("⚠️ OCR báo lỗi, gửi lại ảnh")
                    delegate.photoOutput?(output, didFinishProcessingPhoto: photo, error: error)
                    poll(tick + 4, retries: retries - 1) // chờ ~2s cho app xử lý lại
                } else {
                    poll(tick + 1, retries: retries)
                }
            }
        }
        poll(0, retries: 2)
    }

    private func hasOCRError(in view: UIView?) -> Bool {
        guard let view = view else { return false }
        if let label = view as? UILabel, !label.isHidden, label.alpha > 0.1,
           let text = label.text, text.contains("Không nhận diện được mã vận đơn") {
            return true
        }
        for sub in view.subviews where hasOCRError(in: sub) { return true }
        return false
    }

    private func findDashedBoxes(in view: UIView?) -> [CGRect] {
        guard let view = view else { return [] }
        var results = [CGRect]()

        func traverse(_ v: UIView) {
            if let shapeLayers = v.layer.sublayers?.compactMap({ $0 as? CAShapeLayer }) {
                for layer in shapeLayers {
                    if layer.lineDashPattern != nil {
                        let rect = v.convert(v.bounds, to: nil)
                        if rect.width > 100 && rect.height > 50 {
                            results.append(rect)
                        }
                    }
                }
            }
            if let layer = v.layer as? CAShapeLayer, layer.lineDashPattern != nil {
                let rect = v.convert(v.bounds, to: nil)
                if rect.width > 100 && rect.height > 50 {
                    results.append(rect)
                }
            }
            for sub in v.subviews { traverse(sub) }
        }
        traverse(view)
        return results
    }
}