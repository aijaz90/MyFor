//
//  DataViewController.swift
//  MTUSDK_Sample
//
//  Created by Wenbo Ma on 8/16/22.
//

import UIKit
import MTUSDK

class DataViewController: OpenDeviceViewController, UINavigationControllerDelegate, IConfigurationCallback {
    
    @IBOutlet var btnClear: UIButton!
    @IBOutlet var btnInfo: UIButton!
    @IBOutlet var btnSend: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func sendInfo() {
        for i in 0..<10 {
            let info: String = (self.cfg?.getDeviceInfo(MTU_InfoType(UInt(i))))!
            displayInfo(i, info)
        }
    }
    
    func displayInfo(_ id: Int, _ info: String) {
        switch id {
        case 0:
            setText(text: "[Device Serial Number]:\n\(info)")
        case 1:
            setText(text: "[Firmware Version]:\n\(info)")
        case 2:
            setText(text: "[Device Capabilities]:\n\(info)")
        case 3:
            setText(text: "[Boot1 Version]:\n\(info)")
        case 4:
            setText(text: "[Boot0 Version]:\n\(info)")
        case 5:
            setText(text: "[Firmware Hash]:\n\(info)")
        case 6:
            setText(text: "[Tamper Status]:\n\(info)")
        case 7:
            setText(text: "[Operation Status]:\n\(info)")
        case 8:
            setText(text: "[Offline Detail]:\n\(info)")
        case 9:
            setText(text: "[DeviceModel]:\n\(info)")
        default:
            setText(text: "[Error Response]")
        }
    }
    
    override func stateDeviceDisconnect() {
        super.stateDeviceDisconnect()
        
        self.btnInfo.isEnabled = false
        self.btnClear.isEnabled = false
        self.btnSend.isEnabled = false
    }
    
    override func stateDeviceConnect() {
        super.stateDeviceConnect()
        
        self.btnInfo.isEnabled = true
        self.btnClear.isEnabled = true
        self.btnSend.isEnabled = true
    }

    @IBAction func sendCmd() {
        if txtCmd.text.count > 0 {
            sendCommand(txtCmd.text)
        }else {
            warnResult(content: "Please input command")
        }
    }
}
