import Foundation
import UIKit
import AVFoundation

@objc public class HNDumpCamera: NSObject {
    @objc public static func dumpMethods() {
        if let cls = NSClassFromString("DeliverySignCaptureViewController") {
            var count: UInt32 = 0
            if let methods = class_copyMethodList(cls, &count) {
                HNLog.write("=== Methods of DeliverySignCaptureViewController ===")
                for i in 0..<Int(count) {
                    let sel = method_getName(methods[i])
                    let name = NSStringFromSelector(sel)
                    HNLog.write("Method: \(name)")
                }
                free(methods)
            }
        } else {
            HNLog.write("DeliverySignCaptureViewController not found")
        }
    }
}
