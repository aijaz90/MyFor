//
//  ExcelCmdViewController.swift
//  MTUSDK_Sample
//
//  Created by Wenbo Ma on 10/17/22.
//

import UIKit
import MTUSDK

class SendExcelFileViewController: OpenDeviceViewController {
    
    private var rs3: RS3Client? = nil
    private var isSendingExcelFile = false
    private var currentFilename = "Dummy"
    private var currentFilenameStartTime: CFAbsoluteTime = 0.0
        
    @IBOutlet var btnSendExcel: UIButton!
    @IBOutlet var btnSendLocalExcel: UIButton!
    
    private enum Constant {
        
        static let excelFilenames = [
            "CFG0006706-200" : "MagTek L2 C01 (PIN Enabled)",
            "CFG0006752-200" : "MagTek L2 C01",
            "CFG0006614-BA0" : "Live CAPK"
        ]
        
        enum PropertyTag {
            static let arqc = "ARQC TAGS"
            static let batchData = "BATCH DATA TAGS"
            static let reversalData = "REVERSAL DATA TAGS"
        }
        
        enum FileId {
            static let terminal = "00000000"
            static let processing = "00000100"
            static let entryPoint = "00000200"
            static let caKeys = "00000300"
            static let amexDRL = "00000500"
        }
        
        static func filenameByID(_ fileID: String) -> String {
            var filename = ""
            
            if fileID == Constant.FileId.terminal {
                filename = "Terminal"
            } else if fileID == Constant.FileId.processing {
                filename = "Processing"
            } else if fileID == Constant.FileId.entryPoint {
                filename = "Entry_point"
            } else if fileID == Constant.FileId.caKeys {
                filename = "CAKeys"
            } else if fileID == Constant.FileId.amexDRL {
                filename = "AmexDRL"
            }
            
            return filename
        }
        
        static let localExcelFileAlertTitle = "Excel Filenames"
        static let localExcelFileAlertMessage = "Please select an excel file"
        static let cancelButtonTitle = "Cancel"
        
    }
    
    
    // MARK: - VC Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        rs3 = RS3Client("magensars@magtek.com", "@freeconfig4U", "001000032") // PROD account
        //rs3 = RS3Client("DEV", "Password#12345", "UQ48014613")              // Magensa DEV account
        setupSettingsBarButtonItem()
    }
    
    override func stateDeviceDisconnect(){
        super.stateDeviceDisconnect()
        
        //configureButtonStates(isEnabled: false)
    }
    
    override func stateDeviceConnect() {
        super.stateDeviceConnect()
        
        //configureButtonStates(isEnabled: true)
    }
    
    // MARK: - Actions
    
    // Browse and Send an Excel file
    @IBAction func sendExcelFile() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard let rs3 = self.rs3 else { return }
        rs3.onError = { errorInfo in
            self.setText(text: errorInfo)
            self.debugPrintLog(errorInfo)
        }
        
        guard !isSendingExcelFile else {
            setText(text: "Sending excel file...")
            return
        }
        
        isSendingExcelFile = true
        
        pickFile { [weak self] success, data in
            guard let weakSelf = self else { return }
            
            guard let data = data, success else {
                weakSelf.isSendingExcelFile = false
                return
            }
            
            MTProgressHud.sharedInstance.showDarkBackgroundView(withTitle: "Start sending file...")
            
            rs3.transform(data) { bins in
                weakSelf.isSendingExcelFile = false
                
                DispatchQueue.main.async {
                    guard let bins = bins else {
                        self?.setText(text: "Failed to get payload from Magensa!")
                        MTProgressHud.sharedInstance.hide()
                        return
                    }
    
                    // use bins to send file to device
                    let count = bins.count
                    var currentIterator = 0
                    self?.setText(text: MTUConstant.sendExcelFileStarted)
                    
                    for emvConfigBin in bins {
                        currentIterator = currentIterator + 1
                        let emvConfigId = emvConfigBin.configId ?? ""
                        // Byte array for the file ID. For DynaFlex, use a 4-byte file id.
                        let fileId = HexUtil.getBytesFromHexString(emvConfigId)
                        
                        // File contents to be sent to the device.
                        let fileData = Data(base64Encoded: emvConfigBin.config!)
                        
                        MTProgressHud.sharedInstance.updateProgressTitle(String(currentIterator) + "/" + String(count))
                        
                        weakSelf.backgroundManagementQueue.async {
                            weakSelf.currentFilename = "Send \(emvConfigId) File"
                            weakSelf.currentFilenameStartTime = CFAbsoluteTimeGetCurrent()
                            _ = weakSelf.cfg!.sendFile(fileId! as Data, data: fileData! as Data, callback: weakSelf)
                        }
                    }
                    
                    MTProgressHud.sharedInstance.hide()
                }
            }
            
        }
    }
    
    // Send Built-in Excel file
    @IBAction func sendLocalExcelFile() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        let alert = UIAlertController(
            title: Constant.localExcelFileAlertTitle,
            message: Constant.localExcelFileAlertMessage,
            preferredStyle: .actionSheet
        )
        
        for (item, desc) in Constant.excelFilenames {
            let itemAction = UIAlertAction(title: item, style: .default, handler: { action in
                self.handleLocalExcelFile(action)
            })
            alert.addAction(itemAction)
        }
        
        let cancelAction = UIAlertAction(title: Constant.cancelButtonTitle, style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.btnSendLocalExcel
            popover.sourceRect = self.btnSendLocalExcel!.bounds
        }
        
        present(alert, animated: true, completion: nil)
    }
    
}

// MARK: - Private helpers

private extension SendExcelFileViewController {
    
    func configureButtonStates(isEnabled flag: Bool) {
        btnSendExcel.isEnabled = flag
        btnSendLocalExcel.isEnabled = flag
    }
    
    func pickFile(_ complete: @escaping (_ success: Bool, _ data: Data?) -> Void) {
        let picker = FilePickerViewController { success, data in
            if success {
                complete(true, data)
            } else {
                complete(false, nil)
            }
        }
        
        picker.delegate = picker
        present(picker, animated: true, completion: nil)
    }
    
    
    // Handle Built-in Excel file
    func handleLocalExcelFile(_ action: UIAlertAction) {
        guard action.title != Constant.cancelButtonTitle else { return }
        let startTime = CFAbsoluteTimeGetCurrent()
        self.setText(text: MTUConstant.sendExcelFileStarted)
        
        MTProgressHud.sharedInstance.showDarkBackgroundView(withTitle: "Start Convert...")
        
        let filename = action.title!
        
        //-1. Terminal
        let terminal = Terminal(sourceFile: filename)
        let terminalResult: [UInt8] = terminal.RunAndGenerateOutputFile(fileName: filename)
        if terminalResult.count > 0 {
            let magtekHeader = terminal.getDataWithMagtekHeader()
            sendFileWithID(fileID: Constant.FileId.terminal, data: magtekHeader)
        }
        
        //-2. Properties
        let properties = Properties(inputFile: filename)
        properties.Run()
        if properties.dicProperties.count > 0 {
            sendProperty(prop: properties)
        }
        
        //-3. AmexDRL
        let ameDRL = AmexDRL(sourceFile: filename)
        let ameDRLResult: [UInt8] = ameDRL.RunAndGenerateOutputFile()
        if ameDRLResult.count > 0 {
            let magtekHeader = ameDRL.getDataWithMagtekHeader()
            sendFileWithID(fileID: Constant.FileId.amexDRL, data: magtekHeader)
        }
        
        //-4. Processing
        let processing = Processing(sourceFile: filename)
        let processingResult: [UInt8] = processing.RunAndGenerateOutputFile()
        if processingResult.count > 0 {
            let magtekHeader = processing.getDataWithMagtekHeader()
            sendFileWithID(fileID: Constant.FileId.processing, data: magtekHeader)
        }
        
        //-5. Entry Point
        let entryPoint = Entry_Point(sourceFile: filename)
        let entry_PointResult: [UInt8] = entryPoint.RunAndGenerateOutputFile()
        if entry_PointResult.count > 0 {
            let magtekHeader = entryPoint.getDataWithMagtekHeader()
            sendFileWithID(fileID: Constant.FileId.entryPoint, data: magtekHeader)
        }
        
        //-6. CaKeys
        let cakeys = CaKeys(_SourceFile: filename)
        let cakeysResult: [UInt8] = cakeys.RunAndGenerateOutputFile()
        if cakeysResult.count > 0 {
            let magtekHeader = cakeys.getDataWithMagtekHeader()
            sendFileWithID(fileID: Constant.FileId.caKeys, data: magtekHeader)
        }
        
        MTProgressHud.sharedInstance.hide()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        self.debugPrintLog("Send Files about Runtime: \(String(format: "%.2f", Float(endTime - startTime))) seconds")
    }
    
    func sendFileWithID(fileID: String, data: String) {
        guard isDeviceOpened() else { return }
        
        let resultData = HexUtil.getBytesFromHexString(data)!
        let aFileId = HexUtil.getBytesFromHexString(fileID)
        
        MTProgressHud.sharedInstance.updateProgressTitle("Sending File - \(currentFilename)")
        
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            
            weakSelf.currentFilename = Constant.filenameByID(fileID)
            weakSelf.currentFilenameStartTime = CFAbsoluteTimeGetCurrent()
            // IConfigurationCallback
            _ = weakSelf.cfg!.sendFile(aFileId! as Data, data: resultData as Data, callback: weakSelf)
        }
    }
    
    func sendProperty(prop: Properties) {
        guard isDeviceOpened() else { return }
        
        for (key, value) in prop.dicProperties {
            MTProgressHud.sharedInstance.updateProgressTitle("Setting Property - \(key)")
            
            backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                
                weakSelf.currentFilename = key
                weakSelf.currentFilenameStartTime = CFAbsoluteTimeGetCurrent()
                
                var info = ConfigurationInfo.initWithASN1Oid("1.1.1.1.1.2", hexValue: value)!
                
                if key == Constant.PropertyTag.arqc {
                    info = ConfigurationInfo.initWithASN1Oid("1.1.1.1.1.2", hexValue: value)!
                }
                else if key == Constant.PropertyTag.batchData {
                    info = ConfigurationInfo.initWithASN1Oid("1.1.1.1.1.3", hexValue: value)!
                }
                else if key == Constant.PropertyTag.reversalData {
                    info = ConfigurationInfo.initWithASN1Oid("1.1.1.1.1.4", hexValue: value)!
                }
                
                // Type of configuration. For DynaFlex, this is the first number of the Property OID.
                _ = weakSelf.cfg!.setConfigInfo(info.configType, data: info.oidAndValue, callback: weakSelf)
            }
        }
    }
    
}

// MARK: - IConfigurationCallback

extension SendExcelFileViewController: IConfigurationCallback {
    
    func onProgress(_ progressValue: Int32) {
        DispatchQueue.main.async {
            MTProgressHud.sharedInstance.updateProgressTitle("Sending File - \(self.currentFilename) \(progressValue)%")
        }
    }
    
    func onResult(_ status: MTU_StatusCode, data: Data) {
        self.debugPrintLog("Send File - \(currentFilename) and Result status: \(status)")
        
        if status == MTU_StatusCode_Success {
            self.setText(text: "Send File - \(currentFilename) Success")
        } else {
            self.setText(text: "Send File - \(currentFilename) Failed")
        }
        
        outputOperationRuntime(op: currentFilename, startTime: currentFilenameStartTime)
    }
    
}
