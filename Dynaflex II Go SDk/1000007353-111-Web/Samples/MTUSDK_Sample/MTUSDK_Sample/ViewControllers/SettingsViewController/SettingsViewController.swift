//
//  SettingsViewController.swift
//  MTUSDK_Sample
//
//  Created by Harry Zhang on 12/6/23.
//

import UIKit

class SettingsViewController: OpenDeviceViewController {
    
    @IBOutlet weak var timingLogSwitch: UISwitch!
    @IBOutlet weak var usbModeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var versionLabel: UILabel!
    
    private var cmdUSBModeString = MTUConstant.cmdUSBiAP2WithHIDFallbackMode
    private var currentSelectedIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    // MARK: - Actions
    
    @IBAction func toggleTimingLogFlagTapped(_ sender: UISwitch) {
        AppDelegate.kAPIRuntimeLogFlag = timingLogSwitch.isOn
        UserDefaults.standard.setValue(AppDelegate.kAPIRuntimeLogFlag, forKey: UserDefaultsKey.currentAPIRuntimeLogFlagKey)
        UserDefaults.standard.synchronize()
    }
    
    // SegmentedControl Value Changed
    @IBAction func switchUSBModeTapped(_ sender: UISegmentedControl) {
        currentSelectedIndex = sender.selectedSegmentIndex
        
        switch sender.selectedSegmentIndex {
        case 0:
            cmdUSBModeString = MTUConstant.cmdUSBiAP2WithHIDFallbackMode
        case 1:
            cmdUSBModeString = MTUConstant.cmdUSBiAP2Mode
        case 2:
            cmdUSBModeString = MTUConstant.cmdUSBHIDMode
        default:
            break
        }
    }
    
    @IBAction func setUSBModeTapped(_ sender: UIButton) {
        var usbMode = "iAP2"
        if currentSelectedIndex == 0 {
            usbMode = "Auto Detect" // "iAP2 with HID Fallback"
        } else if currentSelectedIndex == 1 {
            usbMode = "iAP2"
        } else if currentSelectedIndex == 2 {
            usbMode = "HID"
        } else {
            // do nothing
        }
        sendCommandToSetUSBMode(cmdUSBModeString, usbMode: usbMode)
    }
    
    
    @IBAction func faqsButtonTapped(_ sender: UIButton) {
        guard let faqURL = URL(string: MTUConstant.faqURL) else { return }
        
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(faqURL, completionHandler: nil)
        } else {
            UIApplication.shared.openURL(faqURL)
        }
    }
    
}

// MARK: - Private helpers

private extension SettingsViewController {
    
    func setupUI() {
        title = "Settings"
        
        let previousTimingLogFlag = UserDefaults.standard.bool(forKey: UserDefaultsKey.currentAPIRuntimeLogFlagKey)
        timingLogSwitch.isOn = previousTimingLogFlag
        
        navigationController?.navigationBar.backgroundColor = .darkGray
        navigationController?.navigationBar.tintColor = .white
        
        usbModeSegmentedControl.selectedSegmentIndex = 0
        usbModeSegmentedControl.selectedSegmentTintColor = .systemBlue
        usbModeSegmentedControl.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : UIColor.white], for: .selected)
        
        cmdUSBModeString = MTUConstant.cmdUSBiAP2WithHIDFallbackMode
        
        setupVersion()
    }
    
    func setupVersion() {
        if let infoDict = Bundle.main.infoDictionary,
           let version = infoDict["CFBundleShortVersionString"] as? String,
           let buildNumber = infoDict["CFBundleVersion"] as? String {
            versionLabel.text = "Version \(version) Build \(buildNumber)"
        }
    }
    
}
