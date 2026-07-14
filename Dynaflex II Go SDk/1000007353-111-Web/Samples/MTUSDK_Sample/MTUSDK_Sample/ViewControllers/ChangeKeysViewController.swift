//
//  ChangeKeysViewController.swift
//  MTUSDK_Sample
//
//  Created by Wenbo Ma on 10/17/22.
//

import UIKit
import MTUSDK

class ChangeKeysViewController: OpenDeviceViewController {
    
    @IBOutlet var btnChangeKey: UIButton!
    
    var rs3: RS3Client? = nil
    var selectKeys: [KeyInfo]? = nil
    var currentKeyName: String! = nil
    var iWrapperDevice: IWrapperDevice? = nil
    
    private var isGettingKey = false
    private var isInjectingKey = false
    
    private enum Constant {
        static let keySelectionTitle = "Billing"
        static let keySelectionMessage = "Are you sure you want to continue?\r\nThis is a billable event"
        static let cancelButtonTitle = "Cancel"
        static let continueButtonTitle = "Continue"
        
        static let billingInfoTitle = "Billing Info"
        static let billingInfoMessage = "Please enter your billing information"
        
        static let selectKeyTitle = "Keys"
        static let selectKeyMessage = "Please select a Key to inject"
        
        static let gettingTheKeys = "Getting the Keys..."
        static let cannotGetKeys = "Cannot get keys from RS3."
    }
    
    
    // MARK: - VC life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        rs3 = RS3Client("magensars@magtek.com", "@freeconfig4U", "001000032") // This one is Magensa Prod account
        //rs3 = RS3Client("DEV", "Password#12345", "UQ48014613")              // This one is Magensa DEV account
    }
    
    override func stateDeviceDisconnect(){
        super.stateDeviceDisconnect()
        //btnChangeKey.isEnabled = false
    }
    
    override func stateDeviceConnect() {
        super.stateDeviceConnect()
        //btnChangeKey.isEnabled = true
    }
    
    // MARK: - Actions
    
    @IBAction func sendChangeKey() {
        guard let rs3 = self.rs3 else { return }
        
        guard !isGettingKey else {
            setText(text: Constant.gettingTheKeys)
            print(Constant.gettingTheKeys)
            return
        }
        
        isGettingKey = true
        
        rs3.getKey { [weak self] keys in
            guard let weakSelf = self else { return }
            
            weakSelf.isGettingKey = false
            
            guard let keys = keys else {
                weakSelf.setText(text: Constant.cannotGetKeys)
                print(Constant.cannotGetKeys)
                return
            }
            
            weakSelf.debugPrintLog("Got keys from RS3: \(keys)")
            
            weakSelf.selectKeys = keys
            
            DispatchQueue.main.async {
                weakSelf.showSelectKeyAlert()
            }
        }
    }
    
}

// MARK: - Private helpers

private extension ChangeKeysViewController {
    
    @objc private func clearReaderData() {
        self.txtData!.text = ""
        self.btnChangeKey!.backgroundColor = UIColor(rgb: 0xCD5D65);
    }
    
    func showSelectKeyAlert() {
        guard let keys = selectKeys else { return }
        
        let alert = UIAlertController(title: Constant.selectKeyTitle, message: Constant.selectKeyMessage, preferredStyle: .actionSheet)
        
        for key in keys {
            let keyNameAction = UIAlertAction(title: key.keyName, style: .default) { action in
                self.keySelected(action)
            }
            alert.addAction(keyNameAction)
        }
        
        let cancelAction = UIAlertAction(title: Constant.cancelButtonTitle, style: .cancel)
        alert.addAction(cancelAction)
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.btnChangeKey
            popover.sourceRect = self.btnChangeKey!.bounds
        }
        
        present(alert, animated: true, completion: nil)
    }
    

    func keySelected(_ action: UIAlertAction) {
        if action.title != "Cancel" {
            currentKeyName = action.title
            
            let alertController = UIAlertController(title: Constant.keySelectionTitle, message: Constant.keySelectionMessage, preferredStyle: .actionSheet)
            
            let continueAction = UIAlertAction(title: Constant.continueButtonTitle, style: .default) { _ in
                let delayTime = DispatchTime.now() + Double(Int64(0.5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                DispatchQueue.main.asyncAfter(deadline: delayTime) {
                    self.showBillingInfoAlert()
                }
            }
            
            let cancelAction = UIAlertAction(title: Constant.cancelButtonTitle, style: .destructive)
            
            alertController.addAction(continueAction)
            alertController.addAction(cancelAction)
            present(alertController, animated: true)
        }
    }
    
    func showBillingInfoAlert() {
        var inputText = UITextField()
        
        let alert = UIAlertController(title: Constant.billingInfoTitle, message: Constant.billingInfoMessage, preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            self.injectKeyWithName(self.currentKeyName)
        }
        
        let cancelAction = UIAlertAction(title: Constant.cancelButtonTitle, style: .cancel) { _ in }
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        
        
        alert.addTextField { (textField) in
            // If you need to customize the text field, you can do so here.
            //textField.font = UIFont(name: "HelveticaNeue-Light", size:(textField.font?.pointSize)!)
            //textField.autocapitalizationType = UITextAutocapitalizationType.allCharacters
            //textField.autocorrectionType = UITextAutocorrectionType.no
            
            inputText = textField
            inputText.placeholder = "Billing Info"
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    func injectKeyWithName(_ keyName: String) {
        guard let rs3 = self.rs3 else { return }
        
        guard !isInjectingKey else { return }
        
        isInjectingKey = true
        
        rs3.onError = { errorInfo in
            self.setText(text: errorInfo)
            self.debugPrintLog(errorInfo)
        }
        
        let currentKey: KeyInfo? = getCurrentKeyInfoByName(keyName)
        
        _ = openDevice(close: false) { [weak self] in
            guard let weakSelf = self else { return }
            
            weakSelf.backgroundManagementQueue.async {
                do {
                    let keyInfo = try weakSelf.getKeyInfo("1081")
                    
                    guard
                        let token = weakSelf.iWrapperDevice?.configuration.getChallengeToken("ef01"),
                        let sn = weakSelf.iWrapperDevice?.serialNumber
                    else {
                        DispatchQueue.main.async { weakSelf.setText(text: "Can't get device SN and challenge token.") }
                        weakSelf.isInjectingKey = false
                        return
                    }
                    
                    rs3.getKeyToken("2007", currentKey!, keyInfo, token, sn) { tokenString in
                        guard let tokenString = tokenString else {
                            DispatchQueue.main.async { weakSelf.setText(text: "Get key token failed.") }
                            weakSelf.isInjectingKey = false
                            return
                        }
                        
                        weakSelf.debugPrintLog("Got key token: \(tokenString)")
                        
                        _ = weakSelf.iWrapperDevice?.configuration.injectkey(Data(tokenString.utf8)) { statusCode, data in
                            weakSelf.isInjectingKey = false
                            
                            // Update UI
                            DispatchQueue.main.async {
                                if (statusCode == MTU_StatusCode_Success) {
                                    weakSelf.setText(text: "***[Inject Key Success]***")
                                } else { // Timeout, Error, or Unavailable
                                    weakSelf.setText(text: "***[Inject Key Failed]***")
                                }
                            }
                        }
                    }
                } catch {
                    weakSelf.isInjectingKey = false
                    print("Get Key Info Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func getCurrentKeyInfoByName(_ keyName: String) -> KeyInfo? {
        guard let selectKeys = self.selectKeys else { return nil }
        for key in selectKeys {
            if key.keyName == keyName { return key }
        }
        return nil
    }
    
    // This func already called in background thread
    func getKeyInfo(_ keyId: String) throws -> Dictionary<String, String> {
        var result: Dictionary<String, String> = [:]
        
        let keyinfo = self.iWrapperDevice?.configuration.configuration?.getKeyInfo(2, data: Data(hexString: keyId)!)
        
        let tlvs = try RTLV.parse(data: keyinfo!)
        let derivationData = RTLV.getTagValue(tlvList: tlvs, tagString: "84")
        result["derivationData"] = derivationData
        result["keyID"] = keyId
        
        return result
    }
    
    func openDevice(
        close: Bool = true,
        _ openHandler: () -> Void
    ) -> Bool {
        var result: Bool = false
        
        if iWrapperDevice == nil || !iWrapperDevice!.isConnected {
            if isDeviceOpened() {
                iWrapperDevice = nil
                iWrapperDevice = IWrapperDevice(self.theSelectedDevice!)
                
                if iWrapperDevice == nil { return false }
            }
            
            // var event: (MTU_EventType, IData) -> Void
            iWrapperDevice?.event = { [weak self] t, d in
                guard let weakSelf = self else { return }
                weakSelf.onEvent(t, data: d)
            }
        }
        
        if !iWrapperDevice!.isConnected {
            // This function opens a connection to the device.
            iWrapperDevice?.device.getControl()?.open()
        }
        
        if iWrapperDevice!.isConnected {
            result = true
            openHandler()
        }
        
        if close {
            // This function closes the connection to the device.
            iWrapperDevice?.device.getControl()?.close()
        }
        
        return result
    }
    
}
