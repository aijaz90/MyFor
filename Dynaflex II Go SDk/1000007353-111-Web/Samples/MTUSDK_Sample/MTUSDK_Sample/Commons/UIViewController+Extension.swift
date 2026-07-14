//
//  UIViewController+Extension.swift
//  MTUSDK_Sample
//
//  Created by Harry Zhang on 6/29/23.
//

import UIKit

extension UIViewController {
    
    enum Constant {
        static let showOrHideKeyboardTimeDuration = 0.25
    }
    
    var isDarkMode: Bool {
        UITraitCollection.current.userInterfaceStyle == .dark
    }
    
    func warningAlert(_ message: String, title: String = "Warning") {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let okAction = UIAlertAction.init(title: "OK", style: .cancel) { _ in }
            alert.addAction(okAction)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func debugPrintLog(_ log: String) {
#if DEBUG
        print("Debug - \(log)")
#endif
    }
    
    func displayMessage(_ msg: String) -> String {
        "[DisplayMsg]: \(msg)"
    }
    
}
