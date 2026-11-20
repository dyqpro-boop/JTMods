import UIKit
import PhotosUI

@objc public class HNPickerHelper: NSObject, PHPickerViewControllerDelegate {

    private var completion: ((UIImage?) -> Void)?

    @objc public static func showPicker(in vc: UIViewController, completion: @escaping (UIImage?) -> Void) {
        if #available(iOS 14.0, *) {
            let helper = HNPickerHelper()
            helper.completion = completion

            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1

            let picker = PHPickerViewController(configuration: config)
            picker.delegate = helper

            // Retain helper until picker finishes
            objc_setAssociatedObject(picker, "HNPickerHelperRetain", helper, .OBJC_ASSOCIATION_RETAIN)

            vc.present(picker, animated: true)
        } else {
            completion(nil)
        }
    }

    @available(iOS 14.0, *)
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else {
            completion?(nil)
            return
        }

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            DispatchQueue.main.async {
                if let image = object as? UIImage {
                    self?.completion?(image)
                } else {
                    self?.completion?(nil)
                }
            }
        }
    }
}
