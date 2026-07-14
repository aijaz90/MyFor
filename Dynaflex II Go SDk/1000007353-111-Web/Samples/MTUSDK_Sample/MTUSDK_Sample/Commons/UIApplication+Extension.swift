//
//  UIApplication+Extension.swift
//  MTUSDK_Sample
//
//  Created by Harry Zhang on 11/1/23.
//

import UIKit

extension UIApplication {
    
    @objc
    var statusBarView: UIView? {
        if #available(iOS 13, *) {
            
            let tag = 38482
            let keyWindow = UIApplication.shared.mainKeyWindow
            if let statusBar = keyWindow?.viewWithTag(tag) {
                return statusBar
            } else {
                guard let statusBarFrame = keyWindow?.windowScene?.statusBarManager?.statusBarFrame else { return nil }
                let statusBarView = UIView(frame: statusBarFrame)
                statusBarView.tag = tag
                keyWindow?.addSubview(statusBarView)
                return statusBarView
            }
        }
        else {
            return value(forKey: "statusBar") as? UIView
        }
    }
    
    @objc
    var mainKeyWindow: UIWindow? {
        get {
            if #available(iOS 13, *) {
                return connectedScenes
                    .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
                    .first { $0.isKeyWindow }
            } else {
                return keyWindow
            }
        }
    }
    
    @objc
    var statusBarHeight: CGFloat {
        if #available(iOS 13, *) {
            return UIApplication.shared.mainKeyWindow?.windowScene?.statusBarManager?.statusBarFrame.size.height ?? 0
        } else {
            return UIApplication.shared.statusBarFrame.height
        }
    }
    
    @objc
    var currentStatusBarOrientation: UIInterfaceOrientation {
        if #available(iOS 13, *) {
            return UIApplication.shared.mainKeyWindow?.windowScene?.interfaceOrientation ?? .unknown
        } else {
            return UIApplication.shared.statusBarOrientation
        }
    }
    
}
