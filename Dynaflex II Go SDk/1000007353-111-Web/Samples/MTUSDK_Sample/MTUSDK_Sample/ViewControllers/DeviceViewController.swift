//
//  DevicesViewController.swift
//  MTUSDK_Sample
//
//  Created by Wenbo Ma on 12/1/21.
//

import UIKit
import Photos
import MTUSDK
import AVFoundation
import JavaScriptCore
import MobileCoreServices
import UniformTypeIdentifiers

class DeviceViewController: OpenDeviceViewController {
    
    @IBOutlet private var textFieldCommand: UITextField!
    @IBOutlet private var stackViewOutput: UIStackView!
        
    var isConnected = false
    var TLVDic = [String: String]()
    var deviceInfoDictionaryArray: [NSDictionary] = []
    var documentCallback: (UIDocument)->Void = { document  in }
    
    private var currentOperation = "Dummy"
    private var currentOperationStartTime: CFAbsoluteTime = 0.0
    
    var cmdTitle : String = ""
    var cmdString: String = "AA008104012A1001843D1001820178A3098101018201018301018402000386279C01009F02060000000001009F03060000000000005F2A0208405F3601029F150200009F530100"
     
    private enum DeviceInfoActionTitle {
        static let cancel = "Cancel"
        static let deviceSN = "Device Serial Number"
        static let firmwareVersion = "Firmware Version"
        static let firmwareHash = "Firmware Hash"
        static let boot1Version = "Boot1 Version"
        static let tamperStatus = "Tamper Status"
        
        static let wlanFirmware = "WLAN Firmware"
        static let bleFirmware = "BLE Firmware"
        static let batteryLevel = "Battery Level"
    }
    
    private var chosenUpdateFirmwareImageType = 1  // Default is Main firmware
    private enum FirmwareImageType {
        static let fwBootLoader1Image = 0
        static let fwMainAppImage = 1
        static let fwWiFiModuleImage = 2
        static let fwBLEModuleImage = 3
    }
    
    @IBOutlet var btnGetDevInfo: UIButton!
    @IBOutlet var btnDeviceReset: UIButton!
    @IBOutlet var btnSendImage: UIButton!
    @IBOutlet var btnSendFile: UIButton!
    @IBOutlet var btnGetFile: UIButton!
    @IBOutlet var btnGetChallenge: UIButton!
    @IBOutlet var btnPIN: UIButton!
    @IBOutlet var btnSendCommand: UIButton!
    @IBOutlet var btnSetImage: UIButton!
    @IBOutlet var btnShowImage: UIButton!
    @IBOutlet var btnDisplayMsg: UIButton!
    @IBOutlet var btnUpdateFirmware: UIButton!
    @IBOutlet var btnScanBarCode: UIButton!
    @IBOutlet var btnPAN: UIButton!
    @IBOutlet private var btnClear: UIButton!
    
    
    var buttonItems : [String:()->Void] = [:]
    var buttonTexts : [String] = []
    
    // MARK: - VC life cycle
    
    override func viewDidLoad() {
        
        buttonItems["Send Image"] = sendImage
        buttonItems["Show Image"] = showImage
        buttonItems["Set Display Image"] = setImage
        buttonItems["Get Challenge"] = getChallenge
        buttonItems["Update Firmware"] = UpdateFirmware
        buttonItems["Scan Barcode"] = scanBarcode
        buttonItems["Send File"] = sendFile
        buttonItems["Get File"] =  getFile
        buttonItems["Delete File"] = deleteFile
        buttonItems["Display Message"] = displayMessage
        buttonItems["Request PIN"] = PINOperation
        buttonItems["Request PAN"] = PANOperation
        buttonItems["Device Reset"] = deviceReset
        buttonItems["Play Sound"] = playSound
        buttonItems["Start NFC Card Emulation"] = startNFCEmulation
        buttonItems["Stop NFC Card Emulation"] = stopNFCEmulation
        buttonItems["Enter Personal Info - Phone Number"] = enterPhoneNumber
        buttonItems["Enter Personal Info - Social Security Number"] = enterSocialNumber
        buttonItems["Enter Personal Info - Zip Code"] = enterZipCode
        buttonItems["Enter Personal Info - Employee ID"] = enterEmployeeID
        buttonItems["Enter Personal Info - Birthday"] = enterBirthday
        buttonItems["Cancel Enter Personal Info"] = cancelEnterPersonalInfo
        buttonItems["Read Mobile Credential (ECP2)"] = readECP2
        
        // NFC Pass-Through Mode buttons
        buttonItems["Start NFC Pass-Through Mode"] = startNFCPassThroughMode
        buttonItems["Stop NFC Pass-Through Mode"] = stopNFCPassThroughMode
        buttonItems["Start NFC Polling"] = startNFCPolling
        buttonItems["Stop NFC Polling"] = stopNFCPolling
        buttonItems["Send NFC APDU Command"] = sendNFCAPDUCommand
        buttonItems["Turn All LEDs ON (Green)"] = turnAllLEDsOnGreen
        buttonItems["Turn All LEDs OFF"] = turnAllLEDsOff
        

        
        buttonTexts = buttonItems.keys.sorted()

        super.viewDidLoad()
        
        setupUI()
        
        loadDeviceInfoCommands()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        setupCommandTextField()
    }
    
    override func stateDeviceDisconnect() {
        super.stateDeviceDisconnect()
        
        //configureButtonStates(isEnabled: false)
    }
    
    override func stateDeviceConnect() {
        super.stateDeviceConnect()
        
        //configureButtonStates(isEnabled: true)
    }
    
    func log(_ info : String) {
        self.txtData?.text += info + "\n"
    }
    
    // MARK: - Actions

    @IBAction func sendCommand() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard let commandText = textFieldCommand.text, !commandText.isEmpty else {
            warningAlert("Please input a command.")
            return
        }
        
        // The command is a Hex string
        self.cmdString = commandText
        
        // Byte array or string data to send to the device. Data must contain the full command as required by the device.
        sendCommand(self.cmdString)
    }
    
    @IBAction func getDevInfo() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        let alert = UIAlertController(title: "Device", message: "Please select an option", preferredStyle: .actionSheet)
        for item in deviceInfoDictionaryArray {
            cmdTitle = item.object(forKey: "deviceName") as! String
            alert.addAction(
                UIAlertAction(title: cmdTitle, style: .default, handler: { action in self.deviceInfoHandler(action) })
            )
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.btnGetDevInfo
            popover.sourceRect = self.btnGetDevInfo!.bounds
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func deviceReset() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        setText(text: MTUConstant.deviceResetStarted)
        
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // This is equivalent to a power reset. After the reset, connection to the device will need to be re-established.
            weakSelf.devCtrl?.resetDevice(completionHandler: { resultFlag in
                weakSelf.isTheOperationOngoing = false
                if resultFlag {
                    weakSelf.setText(text: "\(MTUConstant.deviceResetOperationName) Success")
                } else {
                    weakSelf.setText(text: "\(MTUConstant.deviceResetOperationName) Failed")
                }
                weakSelf.outputOperationRuntime(op: MTUConstant.deviceResetOperationName, startTime: startTime)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { weakSelf.disconnectDevice() }
            })
        }
    }
        
    @IBAction func sendImage() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !OpenDeviceViewController.hasSelectedDynaFlexIIGo else {
            warningAlert(MTUConstant.notSupportedOperation)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        
        var inputText = UITextField()
        let alert = UIAlertController(title: "Send Image", message: "Image ID:", preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
            guard let inputString = inputText.text, !inputString.isEmpty,
                  let imageID = Int(inputString), 1 <= imageID && imageID <= 4 else {
                self.warningAlert("Invalid input for Image ID (It must be 1 - 4)")
                self.isTheOperationOngoing = false
                return
            }
            
            let documentPicker: UIDocumentPickerViewController
            if #available(iOS 14.0, *) {
                documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item])
            } else {
                documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: UIDocumentPickerMode.import)
            }
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            self.present(documentPicker, animated: true, completion: nil)
            
            self.documentCallback = { [weak self] docObj in
                guard let weakSelf = self else { return }
                MTProgressHud.sharedInstance.hide()
                
                // file:///private/var/mobile/Library/Mobile%20Documents/com~apple~CloudDocs/image1.jpg // not supported
                // file:///private/var/mobile/Library/Mobile%20Documents/com~apple~CloudDocs/image1.bmp // works (ONLY support BMP file)
                weakSelf.debugPrintLog("Send Image File URL: \(docObj.fileURL)")
                
                let imageData = try? NSData(contentsOf: docObj.fileURL, options: .uncached)
                
                weakSelf.currentOperation = MTUConstant.sendImageOperationName
                weakSelf.currentOperationStartTime = CFAbsoluteTimeGetCurrent()
                weakSelf.setText(text: MTUConstant.sendImageStarted)
                // This function sends an image to the device, with the imageID (1,2,3, or 4)
                weakSelf.backgroundManagementQueue.async {
                    // IConfigurationCallback
                    _ = weakSelf.cfg!.sendImage(UInt8(imageID), data: imageData! as Data, callback: self)
                }
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in self.isTheOperationOngoing = false }
        
        alert.addAction(ok)
        alert.addAction(cancel)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.placeholder = "Image ID 1 - 4"
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    
    
    // Set display image of the Device
    @IBAction func setImage() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !OpenDeviceViewController.hasSelectedDynaFlexIIGo else {
            warningAlert(MTUConstant.notSupportedOperation)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        
        var inputText = UITextField()
        let alert = UIAlertController(title: "Set Display Image", message: "Image ID:", preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
            guard let inputString = inputText.text, !inputString.isEmpty,
                  let imageID = Int(inputString), 0 <= imageID && imageID <= 4 else {
                self.warningAlert("Invalid input for Image ID (It must be 0 - 4)")
                return
            }
            
            let result = self.cfg?.setDisplayImage(UInt8(imageID));
            if (result == 0) {
                self.setText(text: "\(MTUConstant.setDisplayImageOperationName) Success")
            } else {
                self.setText(text: "\(MTUConstant.setDisplayImageOperationName) Failed")
            }

        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in self.isTheOperationOngoing = false }
        
        alert.addAction(ok)
        alert.addAction(cancel)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.placeholder = "Image ID 0 - 4"
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func sendFile() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        
        var inputText = UITextField()
        let alert = UIAlertController(title: "Send File", message: "File ID:", preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
            guard let inputString = inputText.text, !inputString.isEmpty,
                  let fileID = HexUtil.getBytesFromHexString(inputString) else {
                self.warningAlert("Invalid input for file ID")
                self.isTheOperationOngoing = false
                return
            }
            
            let documentPicker: UIDocumentPickerViewController
            if #available(iOS 14.0, *) {
                documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item])
            } else {
                documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: UIDocumentPickerMode.import)
            }
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            self.present(documentPicker, animated: true, completion: nil)
            
            self.documentCallback = { [weak self] docObj in
                guard let weakSelf = self else { return }
                
                MTProgressHud.sharedInstance.hide()
                let dataObj = NSData(contentsOf: docObj.fileURL)
                
                weakSelf.currentOperation = MTUConstant.sendFileOperationName
                weakSelf.currentOperationStartTime = CFAbsoluteTimeGetCurrent()
                weakSelf.setText(text: MTUConstant.sendFileStarted)
                weakSelf.backgroundManagementQueue.async {
                    // This function sends a file to the Device.
                    // the fildID -- Byte array for the file ID. For DynaFlex, uses a 4-byte file ID.
                    // the data   -- File contents to be sent to the Device.
                    weakSelf.cfg!.sendFile(fileID as Data, data: dataObj! as Data, callback: self)
                }
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in self.isTheOperationOngoing = false }
        
        alert.addAction(ok)
        alert.addAction(cancel)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.placeholder = "00000000"
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    func deleteFile() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        var inputText = UITextField()
        let alert = UIAlertController(title: "Delete File", message: "File ID:", preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
            guard let inputString = inputText.text, !inputString.isEmpty,
                  let fileID = HexUtil.getBytesFromHexString(inputString) else {
                self.warningAlert("Invalid input for file ID")
                return
            }
            
            self.setText(text: "Delete file - \(inputString)")
            self.backgroundManagementQueue.async {
                    // This function sends a file to the Device.
                    // the fildID -- Byte array for the file ID. For DynaFlex, uses a 4-byte file ID.
                    // the data   -- File contents to be sent to the Device.
                self.cfg!.deleteFile(fileID as Data)
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in self.isTheOperationOngoing = false }
        
        alert.addAction(ok)
        alert.addAction(cancel)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.placeholder = "00000000"
        }
        
        present(alert, animated: true, completion: nil)
    }
    

    @IBAction func showImage() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !OpenDeviceViewController.hasSelectedDynaFlexIIGo else {
            warningAlert(MTUConstant.notSupportedOperation)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        
        var inputText = UITextField()
        let alert = UIAlertController(title: "Show Image", message: "Image ID:", preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
            guard let inputString = inputText.text, !inputString.isEmpty,
                  let imageID = Int(inputString), 1 <= imageID && imageID <= 4 else {
                self.warningAlert("Invalid input for Image ID (It must be 1 - 4)")
                self.isTheOperationOngoing = false
                return
            }
            
            self.setText(text: MTUConstant.showImageStarted)
            
            self.backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                let startTime = CFAbsoluteTimeGetCurrent()
                
                // 0x01 -- show the image at slot 1
                // 0x02 -- show the image at slot 2
                // 0x03 -- show the image at slot 3
                // 0x04 -- show the image at slot 4
                // This function sends a command to immediately show an image on the device’s display. The image must already be loaded into a slot.
                weakSelf.devCtrl?.showImage(UInt8(imageID), completionHandler: { resultFlag in
                    weakSelf.isTheOperationOngoing = false
                    if resultFlag {
                        weakSelf.setText(text: "\(MTUConstant.showImageOperationName) Success")
                    } else {
                        weakSelf.setText(text: "\(MTUConstant.showImageOperationName) Failed")
                    }
                    weakSelf.outputOperationRuntime(op: MTUConstant.showImageOperationName, startTime: startTime)
                })
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in self.isTheOperationOngoing = false }
        
        alert.addAction(ok)
        alert.addAction(cancel)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.placeholder = "Image ID 1 - 4"
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func getFile() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        
        var inputText = UITextField()
        let alert = UIAlertController(title: "Get File", message: "File ID:", preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
            // Byte array for the file ID. For DynaFlex, use a 4-byte file id.
            // you can use file id 00000000 or 00000100
            guard let fileID = inputText.text,
                  let fileIDToData = HexUtil.getBytesFromHexString(fileID) else {
                self.warningAlert("Invalid input for file ID")
                self.isTheOperationOngoing = false
                return
            }
            
            self.currentOperation = MTUConstant.getFileOperationName
            self.currentOperationStartTime = CFAbsoluteTimeGetCurrent()
            self.setText(text: MTUConstant.getFileStarted)
            self.backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                
                // Returns 0 if the asynchronous configuration operation started. Otherwise, returns a non 0 value.
                weakSelf.cfg!.getFile(fileIDToData as Data, callback: self)
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in self.isTheOperationOngoing = false }
        
        alert.addAction(ok)
        alert.addAction(cancel)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.placeholder = "File ID 00000000"
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func displayMessage() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !OpenDeviceViewController.hasSelectedDynaFlexIIGo else {
            warningAlert(MTUConstant.notSupportedOperation)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        
        var inputText = UITextField()
        let alert = UIAlertController(title: "Display Message", message: "Message ID:", preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
            guard let inputString = inputText.text, !inputString.isEmpty,
                  let msgID = UInt8(inputString) else {
                self.warningAlert("Invalid input for Message ID")
                self.isTheOperationOngoing = false
                return
            }
            
            self.setText(text: MTUConstant.displayMsgStarted)
            
            self.backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                let startTime = CFAbsoluteTimeGetCurrent()
                weakSelf.devCtrl?.displayMessage(msgID, timeout: 5, completionHandler: { resultFlag in
                    weakSelf.isTheOperationOngoing = false
                    if resultFlag {
                        weakSelf.setText(text: "\(MTUConstant.displayMsgOperationName) Success")
                    } else {
                        weakSelf.setText(text: "\(MTUConstant.displayMsgOperationName) Failed")
                    }
                    weakSelf.outputOperationRuntime(op: MTUConstant.displayMsgOperationName, startTime: startTime)
                })
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in self.isTheOperationOngoing = false }
        
        alert.addAction(ok)
        alert.addAction(cancel)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.placeholder = "0000"
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    // Get Challenge Token
    @IBAction func getChallenge() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        
        var inputText = UITextField()
        let alert = UIAlertController(title: "Get Challenge Token", message: "Data:", preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            guard let inputString = inputText.text, !inputString.isEmpty,
                  let challengeData = HexUtil.getBytesFromHexString(inputString) else {
                self.warningAlert("Invalid input for Challenge Token")
                self.isTheOperationOngoing = false
                return
            }
            
            self.setText(text: MTUConstant.getChallengeTokenStarted)
            
            self.backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                let startTime = CFAbsoluteTimeGetCurrent()
                let result = weakSelf.cfg!.getChallengeToken(challengeData as Data)
                weakSelf.isTheOperationOngoing = false
                if result.count > 0 {
                    weakSelf.setText(text: "\(MTUConstant.getChallengeTokenOperationName):\n\(String(describing: HexUtil.toHex(result)!))")
                } else {
                    weakSelf.setText(text: "\(MTUConstant.getChallengeTokenOperationName) Failed")
                }
                weakSelf.outputOperationRuntime(op: MTUConstant.getChallengeTokenOperationName, startTime: startTime)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in self.isTheOperationOngoing = false }
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.placeholder = "0000"
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func UpdateFirmware() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        
        var inputText = UITextField()
        let alert = UIAlertController(title: "Update Firmware", message: "Firmware ID:", preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
            guard let inputString = inputText.text, let fmID = Int(inputString), 0 <= fmID && fmID <= 3 else {
                self.warningAlert("Invalid input for firmware ID (It must be 0 - 3)")
                self.isTheOperationOngoing = false
                return
            }
            
            let documentPicker: UIDocumentPickerViewController
            if #available(iOS 14.0, *) {
                documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item])
            } else {
                documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: UIDocumentPickerMode.import)
            }
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            self.present(documentPicker, animated: true, completion: nil)
            
            self.documentCallback = { [weak self] docObj in
                guard let weakSelf = self else { return }
                
                MTProgressHud.sharedInstance.showDarkBackgroundView(withTitle: "Updating Firmware...")
                let fwFileData = NSData(contentsOf: docObj.fileURL)
                
                weakSelf.chosenUpdateFirmwareImageType = fmID
                weakSelf.currentOperation = MTUConstant.updateFirmwareOperationName
                weakSelf.currentOperationStartTime = CFAbsoluteTimeGetCurrent()
                weakSelf.setText(text: MTUConstant.updateFirmwareStarted)
                weakSelf.backgroundManagementQueue.async
                {
                    // Call the MTU SDK to update the device firmware
                    // fmId -- Firmware Type. For DynaFlex, use 1, which means "Main App"
                    // data -- Firmware image file to be sent to the device
                    // Returns 0 if the asynchronous update operation started. Otherwise, returns a non 0 value.
                    _ = weakSelf.cfg!.updateFirmware(ushort(fmID), data: fwFileData! as Data, callback: self)
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in self.isTheOperationOngoing = false }
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.placeholder = "Firmware ID 0 - 3"
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func scanBarcode() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        setText(text: MTUConstant.scanBarcodeStarted)
        
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            let startTime = CFAbsoluteTimeGetCurrent()
            weakSelf.devCtrl?.startScanBarcode(withTimeout: 30, encryptionMode: 0, completionHandler: { resultFlag in
                weakSelf.isTheOperationOngoing = false
                weakSelf.outputOperationRuntime(op: MTUConstant.scanBarcodeOperationName, startTime: startTime)
            })
        }
    }
    
    @IBAction func PINOperation() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !OpenDeviceViewController.hasSelectedDynaFlexIIGo else {
            warningAlert(MTUConstant.notSupportedOperation)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        setText(text: MTUConstant.pinRequestStarted)
        
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            weakSelf.theSelectedDevice?.requestPIN(PINRequest.newRequest(30), completionHandler: { resultFlag in
                weakSelf.isTheOperationOngoing = false
//                if resultFlag {
//                    weakSelf.setText(text: "\(MTUConstant.pinOperationName) Success.")
//                } else {
//                    weakSelf.setText(text: "\(MTUConstant.pinOperationName) Failed.")
//                }
                weakSelf.outputOperationRuntime(op: MTUConstant.pinOperationName, startTime: startTime)
            })
        }
    }
    
    @IBAction func PANOperation() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !OpenDeviceViewController.hasSelectedDynaFlexIIGo else {
            warningAlert(MTUConstant.notSupportedOperation)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        setText(text: MTUConstant.panRequestStarted)
        
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            
            let pinRequest = PINRequest.newRequest(30)
            pinRequest.pinMode = 1
            
            let startTime = CFAbsoluteTimeGetCurrent()
            weakSelf.theSelectedDevice?.requestPAN(PANRequest.newRequest(30, payment: .MSR), withPIN: pinRequest, completionHandler: { resultFlag in
                weakSelf.isTheOperationOngoing = false
                weakSelf.outputOperationRuntime(op: MTUConstant.panOperationName, startTime: startTime)
            })
        }
    }
    
    func playSound() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        setText(text: "Play Sound")
        
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            
            weakSelf.isTheOperationOngoing = weakSelf.theSelectedDevice?.getControl()?.playSound(IData(hex: "0479005A060B0064075B006407C500A2067E006407C3008E")) ?? false
        }
    }
    
    func startNFCEmulation() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        

        
        var inputText = UITextField()
        let alert = UIAlertController(title: "NFC Card Emulation", message: "URL:", preferredStyle: .alert)

        let ok = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction) in
            guard let url = inputText.text else {
                self.warningAlert("Invalid input for URL")
                self.isTheOperationOngoing = false
                return
            }
            
            self.setText(text: MTUConstant.startNFCEmulationStarted)
            self.backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }

                weakSelf.devCtrl?.startNFCCardEmulation(30, data: url)
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in self.isTheOperationOngoing = false }
        
        alert.addAction(ok)
        alert.addAction(cancel)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.text = "www.magtek.com"
            inputText.placeholder = "URL"
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    func stopNFCEmulation() {
        devCtrl?.stopNFCCardEmulation()
    }
    
    func enterZipCode() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        devCtrl?.startPersonalInfoEntry(.zipCode, encrypt: false)
    }
 
    func enterPhoneNumber() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        devCtrl?.startPersonalInfoEntry(.phoneNumber, encrypt: false)
    }
 
    func enterSocialNumber() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        devCtrl?.startPersonalInfoEntry(.socialSecurityNumber, encrypt: false)
    }
    
    func enterEmployeeID() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        devCtrl?.startPersonalInfoEntry(.employeeID, encrypt: false)
    }
    
    func enterBirthday() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        devCtrl?.startPersonalInfoEntry(.birthday, encrypt: false)
    }
 
    func cancelEnterPersonalInfo() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        devCtrl?.stopPersonalInfoEntry()
    }
    
    func readECP2() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        if let device = self.theSelectedDevice {
            let transaction = ITransaction.amount(
                "0.0",
                cashback: "0.0",
                transactionType: UInt8(MTUConstant.transactionType),
                timeout: UInt8(MTUConstant.transactionTimeout),
                for: [.contactless, .NFC],
                quickChip: true
            )
            transaction.appleVASMode = .ECP2
            transaction.customNFCDataMode = .ASCII
            transaction.customNFCTransactionMode = .appleWalletMobileDESFire
            
            device.start(transaction)
        }
    }
    
    // MARK: - NFC Pass-Through Mode Functions
    
    /// Start NFC Pass-Through Mode
    /// Enables the device to enter Pass-Through Mode for direct APDU communication
    func startNFCPassThroughMode() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        var inputText = UITextField()
        let alert = UIAlertController(title: "Start NFC Pass-Through Mode", message: "Enter timeout (seconds, 0 = no timeout):", preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default) { [weak self] (action: UIAlertAction) in
            guard let weakSelf = self else { return }
            guard let timeoutStr = inputText.text, let timeout = UInt8(timeoutStr) else {
                weakSelf.warningAlert("Invalid timeout value")
                return
            }
            
            weakSelf.setText(text: "Starting NFC Pass-Through Mode with timeout: \(timeout) seconds")
            weakSelf.backgroundManagementQueue.async {
                let success = weakSelf.devCtrl?.setNFCPassThroughMode(timeout, mode: 0x01) ?? false
                DispatchQueue.main.async {
                    if success {
                        weakSelf.setText(text: "✅ NFC Pass-Through Mode Started")
                    } else {
                        weakSelf.setText(text: "❌ Failed to start NFC Pass-Through Mode")
                    }
                }
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(ok)
        alert.addAction(cancel)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.text = "30"
            inputText.placeholder = "Timeout (0-255 seconds)"
            inputText.keyboardType = .numberPad
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    /// Stop NFC Pass-Through Mode
    /// Exits Pass-Through Mode and returns device to normal state
    func stopNFCPassThroughMode() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        setText(text: "Stopping NFC Pass-Through Mode...")
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            let success = weakSelf.devCtrl?.setNFCPassThroughMode(0, mode: 0x00) ?? false
            DispatchQueue.main.async {
                if success {
                    weakSelf.setText(text: "✅ NFC Pass-Through Mode Stopped")
                } else {
                    weakSelf.setText(text: "❌ Failed to stop NFC Pass-Through Mode")
                }
            }
        }
    }
    
    /// Start NFC Polling
    /// Starts polling for NFC Type A and Type B cards
    func startNFCPolling() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        var inputText = UITextField()
        let alert = UIAlertController(title: "Start NFC Polling", message: "Enter polling timeout (seconds, 0 = no timeout):", preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default) { [weak self] (action: UIAlertAction) in
            guard let weakSelf = self else { return }
            guard let timeoutStr = inputText.text, let timeout = UInt8(timeoutStr) else {
                weakSelf.warningAlert("Invalid timeout value")
                return
            }
            
            weakSelf.setText(text: "Starting NFC Polling with timeout: \(timeout) seconds")
            weakSelf.backgroundManagementQueue.async {
                let success = weakSelf.devCtrl?.setNFCPollingMode(timeout, mode: 0x01) ?? false
                DispatchQueue.main.async {
                    if success {
                        weakSelf.setText(text: "✅ NFC Polling Started - Waiting for card...")
                    } else {
                        weakSelf.setText(text: "❌ Failed to start NFC Polling")
                    }
                }
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(ok)
        alert.addAction(cancel)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.text = "30"
            inputText.placeholder = "Timeout (0-255 seconds)"
            inputText.keyboardType = .numberPad
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    /// Stop NFC Polling
    /// Stops polling for NFC cards
    func stopNFCPolling() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        setText(text: "Stopping NFC Polling...")
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            let success = weakSelf.devCtrl?.setNFCPollingMode(0, mode: 0x00) ?? false
            DispatchQueue.main.async {
                if success {
                    weakSelf.setText(text: "✅ NFC Polling Stopped")
                } else {
                    weakSelf.setText(text: "❌ Failed to stop NFC Polling")
                }
            }
        }
    }
    
    /// Send NFC APDU Command
    /// Sends a raw APDU command to the activated NFC card
    func sendNFCAPDUCommand() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        var inputText = UITextField()
        let alert = UIAlertController(title: "Send NFC APDU Command", message: "Enter APDU command (hex format):\n\nExamples:\n• SELECT: 00A4040007A0000000031010\n• GET DATA: 00CA9F7F00", preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "Send", style: .default) { [weak self] (action: UIAlertAction) in
            guard let weakSelf = self else { return }
            guard let apduHex = inputText.text, !apduHex.isEmpty else {
                weakSelf.warningAlert("Please enter an APDU command")
                return
            }
            
            // Remove spaces and validate hex
            let cleanHex = apduHex.replacingOccurrences(of: " ", with: "")
            guard cleanHex.count % 2 == 0 else {
                weakSelf.warningAlert("Invalid hex string (must have even number of characters)")
                return
            }
            
            weakSelf.setText(text: "Sending APDU: \(cleanHex)")
            weakSelf.backgroundManagementQueue.async {
                let apduData = IData(hex: cleanHex)
                    
                let success = weakSelf.devCtrl?.sendNFCPassThroughCommand(apduData) ?? false
                if !success {
                    weakSelf.setText(text: "❌ Failed to send APDU Command")
                }
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(ok)
        alert.addAction(cancel)
        
        alert.addTextField { (textField) in
            inputText = textField
            inputText.text = "00A4040007A0000000031010"
            inputText.placeholder = "Hex APDU (e.g., 00A4040007A0000000031010)"
            inputText.autocapitalizationType = .allCharacters
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    /// Turn All LEDs ON (Green)
    /// Turns on all 4 LEDs in green color
    func turnAllLEDsOnGreen() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        setText(text: "Turning all LEDs ON (Green)...")
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            // 0xFF = All LEDs, 0x01 = Green ON
            let success = weakSelf.devCtrl?.setLEDStatus(0xFF, status: 0x01) ?? false
            DispatchQueue.main.async {
                if success {
                    weakSelf.setText(text: "✅ All LEDs turned ON (Green)")
                } else {
                    weakSelf.setText(text: "❌ Failed to turn LEDs ON")
                }
            }
        }
    }
    
    /// Turn All LEDs OFF
    /// Turns off all 4 LEDs
    func turnAllLEDsOff() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        setText(text: "Turning all LEDs OFF...")
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            // 0xFF = All LEDs, 0x00 = OFF
            let success = weakSelf.devCtrl?.setLEDStatus(0xFF, status: 0x00) ?? false
            DispatchQueue.main.async {
                if success {
                    weakSelf.setText(text: "✅ All LEDs turned OFF")
                } else {
                    weakSelf.setText(text: "❌ Failed to turn LEDs OFF")
                }
            }
        }
    }
    
}

// MARK: - UIImagePickerControllerDelegate

extension DeviceViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    private func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        // get the image
        guard (info[UIImagePickerController.InfoKey.originalImage.rawValue] as? UIImage) != nil else {
            return
        }
    }
    
}


// MARK: - UIDocumentPickerDelegate

extension DeviceViewController: UIDocumentPickerDelegate {
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.isTheOperationOngoing = false
    }
    
    // e.g. Open the picked document to open and begin to update firmware
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        MTProgressHud.sharedInstance.showDarkBackgroundView(withTitle: "Opening File...")
        let docObj = Document(fileURL: urls[0])
        docObj.open { (status) in
            self.documentCallback(docObj)
        }
    }
}

// MARK: - IConfigurationCallback

extension DeviceViewController: IConfigurationCallback {
    
    // e.g. update firmware on progress
    func onProgress(_ progressValue: Int32) {
        DispatchQueue.main.async {
            MTProgressHud.sharedInstance.updateProgressTitle("\(self.currentOperation) Progress: \(progressValue)%")
        }
        
        self.debugPrintLog("\(currentOperation) onProgress: \(progressValue)%")
    }
    
    // Completed
    func onResult(_ status: MTU_StatusCode, data: Data) {
        let temp = HexUtil.toHex(data)?.uppercased() ?? "Unknown"
        
        DispatchQueue.main.async {
            self.isTheOperationOngoing = false
            self.outputOperationRuntime(op: self.currentOperation, startTime: self.currentOperationStartTime)
            MTProgressHud.sharedInstance.hide()
            
            if status == MTU_StatusCode_Success {
                self.setText(text: "\(self.currentOperation) Success\n\(temp)")
                
                if self.currentOperation == MTUConstant.updateFirmwareOperationName &&
                   self.chosenUpdateFirmwareImageType == FirmwareImageType.fwBLEModuleImage {
                    self.setText(text: MTUConstant.repairBLEDeviceRequiredMessage)
                }
                
                if self.currentOperation == MTUConstant.updateFirmwareOperationName {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.disconnectDevice() }
                }
            } else {
                self.setText(text: "\(self.currentOperation) Failed\n\(temp)")
                self.debugPrintLog("\(self.currentOperation) Failed, status: \(status), device response: \(temp)")
            }
        }
    }
    
}

// MARK: - Private helpers

private extension DeviceViewController {
    
    func setupCommandTextField() {
        let textColor = isDarkMode ? UIColor.init(white: 1.0, alpha: 0.7) : UIColor.darkGray
        let attributedString = AttributedString("Command", attributes: AttributeContainer.init([
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14),
            NSAttributedString.Key.foregroundColor: textColor
        ]))
        textFieldCommand.attributedPlaceholder = NSAttributedString(attributedString)
    }
    
    func setupUI() {
        textFieldCommand.delegate = self
        setupCommandTextField()
        setupSettingsBarButtonItem()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShowCallback(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHideCallback(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    func configureButtonStates(isEnabled flag: Bool) {
        btnGetDevInfo.isEnabled = flag
        btnDeviceReset.isEnabled = flag
        btnSendImage.isEnabled = flag
        btnSendFile.isEnabled = flag
        btnGetFile.isEnabled = flag
        btnGetChallenge.isEnabled = flag
        btnPIN.isEnabled = flag
        btnSendCommand.isEnabled = flag
        btnSetImage.isEnabled = flag
        btnShowImage.isEnabled = flag
        btnDisplayMsg.isEnabled = flag
        btnUpdateFirmware.isEnabled = flag
        btnScanBarCode.isEnabled = flag
        btnPAN.isEnabled = flag
    }
    
    @objc func keyboardWillShowCallback(_ notification: NSNotification) {
        UIView.animate(withDuration: Constant.showOrHideKeyboardTimeDuration) {
            self.stackViewHideForShowingKeyboard?.isHidden = true
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillHideCallback(_ notification: NSNotification) {
        bottomLayoutConstraint?.constant = 202.0
        
        UIView.animate(withDuration: Constant.showOrHideKeyboardTimeDuration) {
            self.stackViewHideForShowingKeyboard?.isHidden = false
            self.view.layoutIfNeeded()
        }
    }
    
    // Get the device info commands from local devCmd.plist file
    func loadDeviceInfoCommands() {
        guard let path = Bundle.main.path(forResource: "devCmd", ofType: "plist") else {
            warningAlert("devCmd.plist file path not found")
            return
        }
        
        guard let array = NSArray(contentsOfFile: path) else {
            warningAlert("devCmd array not Found")
            return
        }
        
        deviceInfoDictionaryArray = array as! [NSDictionary]
    }
    
    func deviceInfoHandler(_ action: UIAlertAction) {
        guard let actionTitle = action.title, actionTitle != DeviceInfoActionTitle.cancel else { return }
        
        self.setText(text: "[Get \(actionTitle) Started]")
        
        if actionTitle == DeviceInfoActionTitle.deviceSN {
            backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                let startTime = CFAbsoluteTimeGetCurrent()
                let deviceSN = weakSelf.cfg?.getDeviceInfo(MTU_InfoType_DeviceSerialNumber) ?? ""
                weakSelf.setText(text: "\(DeviceInfoActionTitle.deviceSN):\n\(deviceSN)")
                weakSelf.outputOperationRuntime(op: action.title ?? "The Action", startTime: startTime)
            }
        }
        else if actionTitle == DeviceInfoActionTitle.firmwareVersion {
            backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                let startTime = CFAbsoluteTimeGetCurrent()
                let firmwareVersion = weakSelf.cfg?.getDeviceInfo(MTU_InfoType_FirmwareVersion) ?? ""
                weakSelf.setText(text: "\(DeviceInfoActionTitle.firmwareVersion):\n\(firmwareVersion)")
                weakSelf.outputOperationRuntime(op: action.title ?? "The Action", startTime: startTime)
            }
        }
        else if actionTitle == DeviceInfoActionTitle.firmwareHash {
            backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                let startTime = CFAbsoluteTimeGetCurrent()
                let firmwareHash = weakSelf.cfg?.getDeviceInfo(MTU_InfoType_FirmwareHash) ?? ""
                weakSelf.setText(text: "\(DeviceInfoActionTitle.firmwareHash):\n\(firmwareHash)")
                weakSelf.outputOperationRuntime(op: action.title ?? "The Action", startTime: startTime)
            }
        }
        else if actionTitle == DeviceInfoActionTitle.boot1Version {
            backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                let startTime = CFAbsoluteTimeGetCurrent()
                let boot1Version = weakSelf.cfg?.getDeviceInfo(MTU_InfoType_Boot1Version) ?? ""
                weakSelf.setText(text: "\(DeviceInfoActionTitle.boot1Version):\n\(boot1Version)")
                weakSelf.outputOperationRuntime(op: action.title ?? "The Action", startTime: startTime)
            }
        } else if actionTitle == DeviceInfoActionTitle.tamperStatus {
            backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                let startTime = CFAbsoluteTimeGetCurrent()
                let tamperStatus = weakSelf.cfg?.getDeviceInfo(MTU_InfoType_TamperStatus) ?? ""
                weakSelf.setText(text: "\(DeviceInfoActionTitle.tamperStatus):\n\(tamperStatus)")
                weakSelf.outputOperationRuntime(op: action.title ?? "The Action", startTime: startTime)
            }
        } else if actionTitle == DeviceInfoActionTitle.wlanFirmware {
            backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                let startTime = CFAbsoluteTimeGetCurrent()
                let wlanFirmware = weakSelf.cfg?.getDeviceInfo(MTU_InfoType_FirmwareVersionWLAN) ?? ""
                weakSelf.setText(text: "\(DeviceInfoActionTitle.wlanFirmware):\n\(wlanFirmware)")
                weakSelf.outputOperationRuntime(op: action.title ?? "The Action", startTime: startTime)
            }
        } else if actionTitle == DeviceInfoActionTitle.bleFirmware {
            backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                let startTime = CFAbsoluteTimeGetCurrent()
                let bleFirmware = weakSelf.cfg?.getDeviceInfo(MTU_InfoType_FirmwareVersionBLE) ?? ""
                weakSelf.setText(text: "\(DeviceInfoActionTitle.bleFirmware):\n\(bleFirmware)")
                weakSelf.outputOperationRuntime(op: action.title ?? "The Action", startTime: startTime)
            }
        } else if actionTitle == DeviceInfoActionTitle.batteryLevel {
            backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                let startTime = CFAbsoluteTimeGetCurrent()
                let batteryLevel = weakSelf.cfg?.getDeviceInfo(MTU_InfoType_BatteryLevel) ?? ""
                weakSelf.setText(text: "\(DeviceInfoActionTitle.batteryLevel):\n\(batteryLevel)")
                weakSelf.outputOperationRuntime(op: action.title ?? "The Action", startTime: startTime)
            }
        }
    }
    
    @objc func openAblum() {
        let imagePick = UIImagePickerController()
        
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.photoLibrary) {
            PHPhotoLibrary.requestAuthorization { (status) in
                switch status {
                case .notDetermined:
                    break
                case .restricted:
                    break
                case .denied:
                    break
                case .authorized:
                    DispatchQueue.main.async {
                        imagePick.delegate = self
                        imagePick.allowsEditing = true
                        imagePick.sourceType = UIImagePickerController.SourceType.photoLibrary
                        imagePick.mediaTypes = UIImagePickerController.availableMediaTypes(for: UIImagePickerController.SourceType.photoLibrary)!
                        
                        self.present(imagePick, animated: true, completion: {})
                    }
                    break
                default:
                    break
                }
            }
        }
    }
    
}

// MARK: - UITextFieldDelegate

extension DeviceViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}

extension DeviceViewController : UITableViewDelegate, UITableViewDataSource {

    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? buttonItems.count : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "ActionButton")

        cell.textLabel?.text = buttonTexts[indexPath.row]
        cell.backgroundColor = UIColor.systemBlue

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let text = buttonTexts[indexPath.row]
        if let action = buttonItems[text] {
            action()
        }
    }

}
