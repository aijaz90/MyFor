//
//  OpenDeviceViewController.swift
//  MTUSDK_Sample
//
//  Created by Yong Guo on 8/10/22.
//

import Foundation
import UIKit
import MTUSDK
import CoreData

class OpenDeviceViewController: UIViewController, MTSoapToolDelegate , MTUSDKDelegate {
    func onDeviceList(_ instance: Any, with connectionType: MTU_ConnectionType, deviceList: [IDevice]) {
        // check reconnect condition
        if ((connectionType == MTU_ConnectionType_EXTERNAL_ACCESSORY || connectionType == MTU_ConnectionType_BLUETOOTH_LE_EMV) && SelectDeviceViewController.autoReconnectDevice ){
            
            for device in deviceList {
                if (device.getConnectionInfo()?.getAddress() == theSelectedDevice?.getConnectionInfo()?.getAddress()) {
                    // same device then reconnect
                    topConnect()
                    break
                }
                
            }
        }
    }
    
    func didSystemUpdate(_ state: SystemState) {
        // used to check system bluetooth on
        if state == SystemState.bluetoothLEPoweredOn {
            turnOnReconnect()
        }
    }
    
    
    @IBOutlet var txtData: UITextView!
    @IBOutlet var txtCmd: UITextView!
    
    @IBOutlet var btnTopConnect: UIButton!  // Connect/Disconnect button
    @IBOutlet var btnDisplayIP: UIButton!   // Select Device and Device Address button
    
    @IBOutlet weak var bottomLayoutConstraint: NSLayoutConstraint?
    @IBOutlet weak var stackViewHideForShowingKeyboard: UIStackView?
    
    // Serial queue
    let backgroundManagementQueue = DispatchQueue(label: "Background Management Queue", qos: .background)
    
    // Opeartion debounce flag
    var isTheOperationOngoing = false
    
    static var isTransactionOngoing = false
    
    /*
    static var deviceWillReset = false
    static var deviceErrorOccur = false
     */
    
    var connectDeviceStartTime: CFAbsoluteTime = 0.0
    var disconnectDeviceStartTime: CFAbsoluteTime = 0.0

    private static var _selectIPAddress: String = ""
    var selectIPAddress: String? {
        return OpenDeviceViewController._selectIPAddress
    }
    
    static var hasSelectedDynaFlexIIGo = false
    
    // The current selected Device
    private static var _device: IDevice? = nil
    var theSelectedDevice: IDevice? {
        return OpenDeviceViewController._device
    }
    
    private static var _devCtrl: IDeviceControl? = nil
    var devCtrl : IDeviceControl? {
        return OpenDeviceViewController._devCtrl
    }
    
    private static var _cfg : IDeviceConfiguration? = nil
    var cfg : IDeviceConfiguration? {
        return OpenDeviceViewController._cfg
    }
    
    private var hasPanArrived = false
    
    private var hasSelectedDeviceIpAddress = false
    private static var isConnecting : Bool = false
    
    var fallBackValue:String = ""
    var tlvData  : NSMutableDictionary?
    var arqcData : String?
    var batchData: NSMutableDictionary?
    
    var nfcCardType : MTNFCCardType = .none
    
    fileprivate let HOST_ID = "QPH768302346"; //prod //dev as of dec/29
    //private let HOST_ID = "QPH768302341";//dev
    
    fileprivate let HOST_PW = "sNGB$M7Jn!36cQ" //prod //dev as of dec/29
    //private let HOST_PW = "D!7x4eK$6B7eXB";//dev
    
    //NOTE: If nothing is setup we always point to production as default
    fileprivate let URL = "https://qpgw.magensa.net/QwickPAY/Service.asmx" //prod
    
    fileprivate var transactionResult: NSMutableDictionary = NSMutableDictionary();
   
    private enum MTCreditCardBrand: NSInteger {
        case creditCardBrandVisa
        case creditCardBrandMasterCard
        case creditCardBrandAmex
        case creditCardBrandDiscover
        case creditCardBrandQwickCode
        case creditCardBrandQwickT
        case creditCardBrandInvoice
        case creditCardBrandUnknown
    }
    
    private enum CardTypeRegEx {
        static let visa = "^4\\d{15}$"
        static let master = "^5[1-5]\\d{14}$"
        static let amex =  "^3[47]\\d\\d([\\ \\-]?)\\d{6}\\1\\d{5}$"
        static let discover = "^6(?:011\\d\\d|5\\d{4}|4[4-9]\\d{3}|22(?:1(?:2[6-9]|[3-9]\\d)|[2-8]\\d\\d|9(?:[01]\\d|2[0-5])))\\d{10}$"
        static let quickCode = "[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}"
        static let quickT = "^0[0]{3}|^6364"
        static let dummy = ""
    }
    
    private let creditCardMap: [MTCreditCardBrand: String] = [
        .creditCardBrandVisa: CardTypeRegEx.visa,
        .creditCardBrandMasterCard: CardTypeRegEx.master,
        .creditCardBrandAmex: CardTypeRegEx.amex,
        .creditCardBrandDiscover: CardTypeRegEx.discover,
        .creditCardBrandQwickCode: CardTypeRegEx.quickCode,
        .creditCardBrandQwickT: CardTypeRegEx.quickT,
        .creditCardBrandInvoice: CardTypeRegEx.dummy,
        .creditCardBrandUnknown: CardTypeRegEx.dummy
    ]
    
    
    // MARK: - VC Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        handleSelectedDevice()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.theSelectedDevice != nil {
            self.theSelectedDevice?.unsubscribeAll(self)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { context in
            let keyWindow = UIApplication.shared.mainKeyWindow
            guard let statusBarFrame = keyWindow?.windowScene?.statusBarManager?.statusBarFrame else { return }
            UIApplication.shared.statusBarView?.frame = statusBarFrame
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        setupNavigationTitle()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
    
    
    override open var shouldAutorotate: Bool {
        return false
    }
    
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override open var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    // Update connect/disconnet button and Select Device button
    func stateDeviceDisconnect() {
        btnTopConnect.isEnabled = true
        self.btnTopConnect.setImage(UIImage(named: "connect"), for: .normal)
        self.btnTopConnect.setImage(UIImage(named: "Connect_unable"), for: .disabled)
        
        if self.selectIPAddress!.count > 0 {
            self.btnDisplayIP.setTitle(self.selectIPAddress, for: .normal)
        }
    }
    
    func stateDeviceConnect() {
        btnTopConnect.isEnabled = true
        self.btnTopConnect.setImage(UIImage(named: "disconnect"), for: .normal)
        
        if self.selectIPAddress!.count > 0 {
            self.btnDisplayIP.setTitle(self.selectIPAddress, for: .normal)
        }
    }
    
    func connectDevice() {
        guard let device = self.theSelectedDevice else { return }
        
        if !isDeviceOpened() {
            setText(text: "[Connect Device]")
            
            OpenDeviceViewController._devCtrl = device.getControl()
            OpenDeviceViewController._cfg = device.getConfiguration()
            self.devCtrl!.open()
        }
        else {
            setText(text: "Device has opened already")
        }
    }
    
    func disconnectDevice() {
        if isDeviceOpened() {
            setText(text: "[Disconnect Device]")
            
            self.devCtrl?.close()
        } else {
            setText(text: "Device has closed already")
        }
    }
    
    func turnOnReconnect() {
        guard SelectDeviceViewController.autoReconnectDevice else { return }
        guard let device = theSelectedDevice, let connectionInfo = device.getConnectionInfo(), device.getConnectionState() == MTU_ConnectionState_Disconnected else { return }
        
        // turn on scanning
        let connectionType = connectionInfo.getConnectionType()
        if connectionType == MTU_ConnectionType_BLUETOOTH_LE_EMV {
            CoreAPI.shared().mtuSDKDelegate = self
            CoreAPI.shared().setDeviceType(MTU_DeviceType_MMS, andConnectionType: MTU_ConnectionType_BLUETOOTH_LE_EMV)
            CoreAPI.shared().startDiscover()
        } else if connectionType == MTU_ConnectionType_EXTERNAL_ACCESSORY {
            CoreAPI.shared().mtuSDKDelegate = self
            CoreAPI.shared().setDeviceType(MTU_DeviceType_MMS, andConnectionType: MTU_ConnectionType_EXTERNAL_ACCESSORY)
            CoreAPI.shared().startDiscover()
        }
        
    }
    
    func turnOffReconnect() {
        //
        CoreAPI.shared().stopDiscover()
    }
    
    func isDeviceOpened() -> Bool {
        guard let device = self.theSelectedDevice else { return false }
        return device.getConnectionState() == MTU_ConnectionState_Connected
    }
    
    func isDeviceOpening() -> Bool {
        guard let device = self.theSelectedDevice else { return false }
        
        let state = device.getConnectionState()
        if state == MTU_ConnectionState_Connecting || state == MTU_ConnectionState_Disconnecting || state == MTU_ConnectionState_Connected {
            return true
        } else {
            return false
        }
    }
    
    func sendCommandSync(_ cmd : String) -> String {
        if let ctrl = devCtrl {
            let result = ctrl.sendSync(IData(hex: cmd))
            if result.status == MTU_StatusCode_Success {
                return result.data.byteArray.hexadecimalString
            }
        }
        return ""
    }
    
    // cmd -- a Hex string
    func sendCommand(_ cmd: String) {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            let startTime = CFAbsoluteTimeGetCurrent()
            // This function sends a command to the Device. The response will be passed to the event (MTU_EventType_DeviceResponse) OnEvent().
            // The `data` -- Byte array or string data to send to the Device. Data must contain the full command as required by the Device.
            weakSelf.devCtrl?.send(IData(hex: cmd), completionHandler: { resultFlag in
                weakSelf.isTheOperationOngoing = false
                if resultFlag {
                    weakSelf.setText(text: "\(MTUConstant.sendCommandOperationName) Success")
                } else {
                    weakSelf.setText(text: "\(MTUConstant.sendCommandOperationName) Failed")
                }
                weakSelf.outputOperationRuntime(op: MTUConstant.sendCommandOperationName, startTime: startTime)
            })
        }
    }
    
    // Switch USB Connection Mode
    func sendCommandToSetUSBMode(_ cmd: String, usbMode: String = "iAP2") {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            
            // This function sends a command to the Device. The response will be passed to the event (MTU_EventType_DeviceResponse) OnEvent().
            // The `data` -- Byte array or string data to send to the Device. Data must contain the full command as required by the Device.
            weakSelf.devCtrl?.send(IData(hex: cmd), completionHandler: { resultFlag in
                weakSelf.isTheOperationOngoing = false
                if resultFlag {
                    weakSelf.setText(text: "\(MTUConstant.setUSBModeOperationName) \(usbMode) - Success")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { weakSelf.resetTheDevice() }
                } else {
                    weakSelf.setText(text: "\(MTUConstant.setUSBModeOperationName) \(usbMode) - Failed")
                }
            })
        }
    }
    
    func resetTheDevice() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !isTheOperationOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        isTheOperationOngoing = true
        
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            
            // This is equivalent to a power reset. After the reset, connection to the device will need to be re-established.
            weakSelf.devCtrl?.resetDevice(completionHandler: { resultFlag in
                weakSelf.isTheOperationOngoing = false
                if resultFlag {
                    weakSelf.setText(text: "\(MTUConstant.deviceResetOperationName) Success")
                } else {
                    weakSelf.setText(text: "\(MTUConstant.deviceResetOperationName) Failed")
                }
               
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { weakSelf.disconnectDevice() }
            })
        }
    }
    
    func warnResult(content: String) {
        
        let msgAlertCtr = UIAlertController.init(title: "Warning", message: content, preferredStyle: .alert)
        let OK = UIAlertAction.init(title: "OK", style: .cancel) { (action: UIAlertAction) in
            print("Cancel input")
        }
        
        msgAlertCtr.addAction(OK)
        
        self.present(msgAlertCtr, animated: true, completion: nil)
    }
    
    // MARK: - Actions
    
    @IBAction func clearText() {
        txtData.text = ""
    }
    
    // Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let selectDeviceVC = segue.destination as? SelectDeviceViewController {
            selectDeviceVC.delegate = self
            selectDeviceVC.backgroundManagementQueue = backgroundManagementQueue
        }
    }
    
    @IBAction func selectDeviceTapped() {
        // do nothing
    }
    
    // not using
    @IBAction func unwindToOpenDeviceVC(_ unwindSegue: UIStoryboardSegue) {
        
//        if let sourceViewController = unwindSegue.source as? SelectDeviceViewController,
//           let selectDeviceAddress = sourceViewController.currentSelectedDeviceAddress
//        {
//            sourceViewController.delegate = self
//            sourceViewController.backgroundManagementQueue = backgroundManagementQueue
//            
//            hasSelectedDeviceIpAddress = true
//            
//            OpenDeviceViewController._selectIPAddress = selectDeviceAddress
//            btnDisplayIP.setTitle(selectDeviceAddress, for: .normal)
//            
//            backgroundManagementQueue.async {
//                OpenDeviceViewController._device = sourceViewController.currentSelectedDevice
//            }
//            
//            handleSelectedDevice()
//        }
    }
    
    // Connect a device -- connectTapped
    @IBAction func topConnect() {
        guard let selectIPAddress = self.selectIPAddress, !selectIPAddress.isEmpty else {
            warningAlert("Please select an IP Address or a BLE device.")
            return
        }
        
        guard self.theSelectedDevice != nil else {
            //warningAlert("The selected device object is nil.")
            return
        }
        
        // Re-connect debouncing
        guard !OpenDeviceViewController.isConnecting else { return }
        
        OpenDeviceViewController.isConnecting = true
        btnTopConnect.isEnabled = false
        btnDisplayIP.isEnabled = false
        
        if !isDeviceOpened() {
            connectDevice()
        }
        else {
            // manually disconnect, will not auto reconnect device.
            SelectDeviceViewController.autoReconnectDevice = false
            disconnectDevice()
        }
        
        //isConnecting = false
    }
        
    func loadDynaFlexInfo() {
        let readerID: String = (self.cfg?.getDeviceInfo(MTU_InfoType_DeviceSerialNumber))!
        self.setText(text: "[ReaderID]:      \((readerID.count > 0) ? readerID : "N/A")")
        let firmwareVersion: String = (self.cfg?.getDeviceInfo(MTU_InfoType_FirmwareVersion))!
        self.setText(text: "[Firmware]:      \((firmwareVersion.count > 0) ? firmwareVersion : "N/A")")
        let serialNumber: String = (self.cfg?.getDeviceInfo(MTU_InfoType_DeviceSerialNumber))!
        self.setText(text: "[SerialNumber]:      \((serialNumber.count > 0) ? serialNumber : "N/A")")
    }
    
    func scrollTextView(toBottom textView: UITextView?) {
        let range = NSRange(location: textView?.text.count ?? 0, length: 0)
        textView?.scrollRangeToVisible(range)
        
        textView?.isScrollEnabled = false
        textView?.isScrollEnabled = true
    }
    
    func setText(text: String) {
        guard let outputTextView = txtData else { return }
        
        //let dispText = "< \(Date.now) >" + text
        let dispText = text
        
        DispatchQueue.main.async {
            //outputTextView.text += "\r\(text)"
            outputTextView.text += "\(dispText)\n"
            self.scrollTextView(toBottom: outputTextView)
        }
    }
    
    func outputOperationRuntime(op: String, startTime: CFAbsoluteTime) {
        let endTime = CFAbsoluteTimeGetCurrent()
        let outputString = "\(op) Runtime: \(String(format: "%.2f", endTime - startTime)) seconds"
        
        if AppDelegate.kAPIRuntimeLogFlag { setText(text: outputString) }
        
        debugPrintLog(outputString)
    }
    
    func getInput(_ title : String, _ message : String, _ placeHolder : String, _ inputed : @escaping(_ text : String)->Void)
    {
        var inputText: UITextField = UITextField()
        let msgAlertCtr = UIAlertController.init(title: title, message: message, preferredStyle: .alert)
        
        let ok = UIAlertAction.init(title: "OK", style: .default) { (action: UIAlertAction) in
            if inputText.text != nil {
                inputed(inputText.text!)
            }
        }
        
        let cancel = UIAlertAction.init(title: "Cancel", style: .cancel) { (action: UIAlertAction) in
            print("Cancel input")
        }
        
        msgAlertCtr.addAction(ok)
        msgAlertCtr.addAction(cancel)
        
        msgAlertCtr.addTextField { (textField) in
            inputText = textField
            inputText.placeholder = placeHolder
        }
        
        self.present(msgAlertCtr, animated: true, completion: nil)
    }
    

    func didRecieveEMVData(_ tlv: NSMutableDictionary) {
//        DispatchQueue.main.async {
//            self.getFinalApproval()
//        }
    }
    
    func didUpdateNfcCardType(nfcType : MTNFCCardType) {
        // override this function
    }
    
    // Authorization Request Cryptogram (ARQC) is a Ciphertext used for a process called Online Authorization.
    func onARQCReceived(_ data: Data!) {
        let dataString = data.hexadecimalString.uppercased()
        print(#line, #function, "[dataString]: \(dataString)")
        
        let emvBytes = HexUtil.getBytesFromHexString(dataString as String)! as NSData
        print(#line, #function, "[emvBytes]: \(emvBytes)")
        
        guard let tlv = emvBytes.parseTLVData() else { return }
        print(#line, #function, "[Parsed TLV Data]: \(String(describing: tlv))")
        
        DispatchQueue.main.async {
            if let tlvTagDFDF53 = tlv["DFDF53"] {
                self.fallBackValue = (tlvTagDFDF53 as! MTTLV).value as String
                print(#line, #function ,"dbg-fallbackValue", self.fallBackValue)
                
                self.didReceiveRawAQRC(arqc: dataString as String)
                
                let tlvDict = NSMutableDictionary.init(dictionary: tlv)
                self.didRecieveEMVData(tlvDict)
            }
            else {
                if !self.validateAllTLVTags(readerTLVTags: tlv as NSDictionary) { return }
                
                if let _ = (tlv as NSDictionary).object(forKey: AppsTLVTags.tlv5F20) {
                    print(#line, #function, "card holder name found in 5F20" )
                    
                    self.didRecieveEMVData(tlv as! NSMutableDictionary)
                }
            }
        }
    }
    
    func getFinalApproval() {
        let amount = "0.01"
        
        // New added elements for EMV XML
        let taxAmount = String("0.09")
        let subTotal  = String("0.01")
        
        let taxPcFlt  = (String("0.01") as NSString).doubleValue / 100
        let taxPct = String(format: "%.00005f", taxPcFlt)
        
        let tipAmt    = String("0.01")
        let tipPct    = String(((tipAmt as NSString).floatValue) /  ((amount as NSString).floatValue))
        
        let emvAmounts = (taxAmount: taxAmount, subtotal: subTotal, taxPct: taxPct, tipAmt: tipAmt, tipPct: tipPct)
        
        var nameIn = "Unavailable/Name"
        
        if (self.fallBackValue != "01") {
            nameIn = (self.getTLVTagValueString(AppsTLVTags.tlv5F20)!).stringFromHexString
        }
        else {
            nameIn = (self.getTLVTagValueString("DFDF31")!.count > 0 ? self.getTLVTagValueString("DFDF31")?.stringFromHexString :  self.getTLVTagValueFromBatchString("DFDF31")?.stringFromHexString)!
            
            nameIn = nameIn.count > 0 ? String(nameIn.split(separator: "^")[1]) : ""
        }
        
        if (self.getTLVTagValueString(AppsTLVTags.tlvDFDF59) == ""
            || self.getTLVTagValueString(AppsTLVTags.tlvDFDF56) == ""
            || self.getTLVTagValueString(AppsTLVTags.tlvDFDF57) == ""
        ) {
            self.haveReaderWithWrongConfig()
            return
        }
        
        // NEW Dev - Web Services
        self.processEMVNewDev(
            /*MTPaymentManager.sharedInstance.getTLVTagValueString(AppsTLVTags.tlvDFDF59)!*/
            self.getFullARQC(),
            ksn: self.getTLVTagValueString(AppsTLVTags.tlvDFDF56)!,
            amount: amount,
            nameIn: nameIn,
            encryptType: self.getTLVTagValueString(AppsTLVTags.tlvDFDF57)!,
            emvAmounts: (emvAmounts.taxAmount,emvAmounts.subtotal, emvAmounts.taxPct, emvAmounts.tipAmt, emvAmounts.tipPct)
        )
    }
    
    func validateAllTLVTags(readerTLVTags: NSDictionary) -> Bool {
        
        for tlvTag in AppsTLVTags.allAppsTLVTags {
            print(#line, #function, "dbg-tlvTag:", tlvTag)
            
            guard let _ = readerTLVTags[tlvTag] else {
                DispatchQueue.main.async() {
                    self.haveReaderWithWrongConfig()
                }
                
                print(#line, #function, "validate-tag failed :", tlvTag)
                
                return false
            }
        }
        
        return true
    }
    
    func haveReaderWithWrongConfig(){
        print("have Reader With Wrong Config")
    }
    
    func getTLVTagValueString(_ tlvStringTag: String) -> String? {
        var tlvTagData = ""
        
        if let _ = self.tlvData?.object(forKey: tlvStringTag) {
            tlvTagData = (self.tlvData!.object(forKey: tlvStringTag) as! MTTLV).value
        }
        
        return tlvTagData
    }
    
    func getTLVTagValueFromBatchString(_ tlvStringTag: String) -> String? {
        var tlvTagData = ""
        
        if let _ = self.batchData?.object(forKey: tlvStringTag) {
            tlvTagData = (self.batchData!.object(forKey: tlvStringTag) as! MTTLV).value
        }
        
        return tlvTagData
    }
    
    func didReceiveRawAQRC(arqc: String) {
        arqcData = arqc
    }
    
    func getFullARQC() -> String {
        return arqcData!
    }
    
    func getTransactionInformation() -> NSDictionary {
        let transDict:NSDictionary = ["invoice":"1234567", "poNumber":"7654321abcde", "notes": "Sample", "cvv": "506", "billingZip": "52556"];
        return transDict
    }
    
    func setupSettingsBarButtonItem() {
        let settingsIcon = UIImage(named: "settings")
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: settingsIcon, style: .plain, target: self, action: #selector(navigateToSettingsView))
    }
    
    @objc func navigateToSettingsView() {
        let settingsViewStoryboard = UIStoryboard(name: MTUConstant.settingsViewStoryboardName, bundle: nil)
        let settingsVC = settingsViewStoryboard.instantiateViewController(withIdentifier: MTUConstant.settingsViewStoryboardID)
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    // MARK: - EMV - Chip Processing - New in DEV (for now)
    func processEMVNewDev(
        _ sredData: String,
        ksn: String,
        amount: String,
        nameIn: String,
        encryptType: String,
        emvAmounts: (taxAmount:String, subTotal:String, taxPct:String, tipAmt:String, tipPct:String)
    ) {
        var invoice = ""
        var poNumber = ""
        var notes = ""
        let firstName = "Dummy First Name" //MTTransactionManager.sharedInstance.getContactFirstName();
        let lastName = "Dummy Last Name"   //MTTransactionManager.sharedInstance.getContactLastName();
        let address = "Dummy Address"
        let city = "Dummy City"
        let state = "Dummy State"
        let zip = "55555"
        let phone = "666-555-0000"     //MTTransactionManager.sharedInstance.getPhoneNumber();
        let email = "dummy@gmail.com"  //MTTransactionManager.sharedInstance.getEmail();
        var cvv = "123"
        var billingZip = ""
        
        let transInfo: Dictionary<String, Any> = self.getTransactionInformation() as! Dictionary<String, Any>
        
        if transInfo.keys.count > 0 {
            invoice = transInfo["invoice"] as! String;
            poNumber = transInfo["poNumber"] as! String;
            notes = transInfo["notes"] as! String;
            cvv = transInfo["cvv"] as! String;
            billingZip = transInfo["billingZip"] as! String
        }
        
        let deviceSN = self.getDeviceSNFromTLV()
        let numberOfPaddedBytes = "05" //self.getNumberOfPaddedBytesTLV()
        
        // New - ProcesDATA10
        let tags: Array<String> = ["HostID", "HostPW", "MerchantID", "MerchantPW", "Data", "DataFormatType", "PaymentMode", "IsEncrypted", "KSN", "EncryptionType", "NumberOfPaddedBytes","DeviceType", "DeviceSN","TransactionType", "Amt", "CVV", "ZIP", "AuthCode", "TerminalName", "SubTotal","TaxAmt","TaxPct","TipAmt", "TipPct", "PurchaseOrder", "InvoiceNumber", "FirstName", "LastName", "Email", "Phone", "CustomerAddress1", "CustomerAddress2", "CustomerCity", "CustomerState" ,"CustomerZip", "Comments", "AdditionalRequestData", "ClientCertAsBase64String", "ClientCertPassword", "TransactionInputDetails" ]
        
        let devInfo = UIDevice.current;
        
        let taxPcFlt = (String("0.01") as NSString).doubleValue / 100;
        let taxPc = String(format: "%.00005f", taxPcFlt);
    
        //let tipAmount = 0.01      //MTSalesManager.sharedInstance.getTipAmount()
        //let subTotalAmount = 0.01 //MTSalesManager.sharedInstance.getTotalWithoutTax() //.getTotal()
        var tipPc = String(format: "0.01")
    
        let amountAmt = String(format: "0.02")
        let amountSubTotal = String(format: "0.01")
        let amountTaxAmt = String(format: "0.01")
        let amountTipAmt = String(format: "0.01")
        
        var paymentModeString = "EMV"
        if (self.fallBackValue == "01" || self.getTLVTagValueString("DFDF52") == "01") {
            paymentModeString = "MagStripe"
        }
        
        if Double(tipPc) == 0.00 && Double(amountTipAmt)! > 0.00 {
            tipPc = String(format: "%.4f", Double(amountTipAmt)! / Double(amountSubTotal)!);
        }
        
        // New - ProcesDATA10
        let variable: [Any] = [
            HOST_ID,
            HOST_PW,
            "QPP061523067", //cred.merchantID,
            "Password@1",   //cred.merchantPW,
            sredData,
            "TLV",             // "TLV" or "NONE"
            paymentModeString, // "None", "MagStripe", "EMV" or "ManualEntry"
            "true",
            ksn,
            encryptType,
            numberOfPaddedBytes,   // NumberOfPaddedBytes: previsous processEMV -- hard coded "0" -
            "",  // DeviceType: actual device used?  -- cardData.deviceName  (check if this is meant)
            deviceSN,
            "S", // "SALE",  //TransactionType: processEMV uses: "SALE"; processPC11 uses: "S" -- check witch one?
            amountAmt,
            cvv,
            billingZip,
            "",           // AuthCode?
            devInfo.name, // TerminalName
            amountSubTotal,
            amountTaxAmt,
            taxPc,
            amountTipAmt,
            tipPc,
            poNumber,
            invoice,
            firstName,
            lastName,
            email,
            phone,
            address,  // CustomerAddress1
            "",       // CustomerAddress2
            city,
            state,
            zip,
            notes,
            [AnyHashable: Any](),
            "", // ClientCertAsBase64String
            "", // ClientCertPassword
            ["5F20": nameIn]
        ]
        
        let soap = MTSoapTool()
        soap.delegate = self
        
        soap.callSoapServiceWithParameters("ProcessDATA10", tagsIn: tags, varsIn: variable, wsdlURLIn: URL as NSString) { [weak self] (dictIn, status) -> Void in
            guard let weakSelf = self else { return }
            
            guard let rsDict = (dictIn as AnyObject).value(forKeyPath:"soap:Body.ProcessDATA10Response.ProcessDATA10Result") as? NSDictionary else {
                // if URL goes down - faultdict -- will crash app
                guard let faultDict = (dictIn as AnyObject).value(forKeyPath:"soap:Body.soap:Fault") as? [String : Any] else {
                    weakSelf.didGetError(dictIn as NSDictionary)
                    return
                }
                
                weakSelf.didGetError(faultDict as NSDictionary)
                return
            }
            
            for (key, item) in rsDict {
                weakSelf.setText(text: "\(key) = \(item)")
            }
            
            if let statusCode = rsDict.value(forKey: "StatusCode") as? String {
                if statusCode.isNumber {
                    if let rsCode = rsDict.value(forKey: "TransactionMsg") as? NSString {
                        weakSelf.didCompleteProcessingCard(rsDict, rsCode: rsCode);
                    }
                    else if let rsCode = rsDict.value(forKey: "StatusCode") as? NSString {
                        weakSelf.didCompleteProcessingCard(rsDict, rsCode: rsCode);
                    }
                }
                else {
                    weakSelf.didGetError(rsDict as NSDictionary)
                }
            }
        }
    }
    
    func getDeviceSNFromTLV() -> String {
        let deviceSN = (self.tlvData!.object(forKey: AppsTLVTags.tlvDFDF25) as! MTTLV).value
        
        if (deviceSN as NSString).substring(to: 2) == "42" {
            return ((self.tlvData!.object(forKey: AppsTLVTags.tlvDFDF25) as! MTTLV).value).stringFromHexString
        }
        else {
            return (self.tlvData!.object(forKey: AppsTLVTags.tlvDFDF25) as! MTTLV).value
        }
    }
    
    func getNumberOfPaddedBytesTLV() -> String {
        return (self.tlvData!.object(forKey: AppsTLVTags.tlvDFDF58) as! MTTLV).value
    }
    
    
    func connectionGotError(_ error: NSError) {
        
    }
    
    func didGetError(_ rsDict: NSDictionary) {
        
    }
    
    private func getCardType() -> MTCreditCardBrand? {
        let maskedT2Tag = (getTLVTagValue(AppsTLVTags.tlvDFDF4D) != nil) ? getTLVTagValue(AppsTLVTags.tlvDFDF4D) : getTLVTagValue(AppsTLVTags.tlvDFDF33)
        guard let maskedT2Tag = maskedT2Tag else { return nil }
        
        let rang = Range(uncheckedBounds: (lower: 0, upper: maskedT2Tag.count - 1))
        let maskedT2HexString = maskedT2Tag.subdata(in: rang).hexadecimalString
        
        let maskedT2String = (maskedT2HexString as String).stringFromHexString
        
        let r1 = (maskedT2String as NSString).range(of: ";")
        let r2 = (maskedT2String as NSString).range(of: "=")
        
        var maskedT2Pan = ""
        var s2 = ""
        if (r1.location != NSNotFound && r2.location != NSNotFound) {
            
            if ((r1.length > 0) && (r2.length > 0))
            {
                let subStringRange = NSRange(location: (r1.location + r1.length), length: (r2.location - (r1.location + r1.length)))
                s2 = (maskedT2String as NSString).substring(with: subStringRange)
            } else {
                s2 = ""
            }
            maskedT2Pan = s2
        }
        
        return getCurrentCardType(maskedT2Pan)
    }
    
    func getTLVTagValue(_ tlvTag: String) -> Data? {
        guard let tlvTagValue = tlvData?.object(forKey: tlvTag) else { return nil }
        
        let tlvTagData: Data? = HexUtil.getBytesFromHexString((tlvTagValue as! MTTLV).value) as Data?
        return tlvTagData
    }
    
    private func getCurrentCardType(_ cardNumber: String) -> MTCreditCardBrand {
        let cardNumberReplaced = cardNumber.replacingOccurrences(of: "*", with: "0", options: NSString.CompareOptions.widthInsensitive, range: nil)
        
        for (cardTypeKey, pattern) in creditCardMap {
            if pattern == CardTypeRegEx.dummy { continue }
            
            if Regex(pattern).test(cardNumberReplaced) { return cardTypeKey }
        }
        
        return MTCreditCardBrand.creditCardBrandUnknown
    }
    
    func didCompleteProcessingCard(_ rsDict: NSDictionary, rsCode: NSString) {
        if getCardType() == MTCreditCardBrand.creditCardBrandQwickT {
            let qwiktRS = rsDict.mutableCopy() as! NSMutableDictionary;
            let indexRange: Range = Range(uncheckedBounds:(lower:10000, upper: 999999))
            let fakeNumber = self.getRandRange(indexRange);
            qwiktRS.setValue(String(format: "QT%i", fakeNumber), forKey: "AuthCode");
            qwiktRS.setValue(String(format: "QT%i", fakeNumber), forKey: "TransactionID")
            qwiktRS.setValue("Approved", forKey: "TransactionMsg");
            qwiktRS.setValue(("0"), forKey: "TransactionStatus");
            
            self.transactionResult = qwiktRS
            self.transactionManagerDidFinishWithStatus("Approved", rsDict: qwiktRS)
        }
    }
    
    func getRandRange (_ range: Range<Int> ) -> Int {
        var offset = 0
        
        if range.lowerBound < 0   // allow negative ranges
        {
            offset = abs(range.lowerBound)
        }
        
        let mini = UInt32(range.lowerBound + offset)
        let maxi = UInt32(range.upperBound   + offset)
        
        return Int(mini + arc4random_uniform(maxi - mini)) - offset
    }
    
    func transactionManagerDidFinishWithStatus(_ status: NSString, rsDict: NSDictionary) {
        
    }
    
}

// MARK: - IEventSubscriber

extension OpenDeviceViewController: IEventSubscriber {
    
    func onEvent(_ eventType: MTU_EventType, data: IData!) {
        DispatchQueue.main.async {
            switch eventType {
            case MTU_EventType_ConnectionState:
                self.connectionStateHandler(data.stringValue)
                break
            case MTU_EventType_OperationStatus:
                self.operationStatusHandler(dataString: data.stringValue)
                break
            case MTU_EventType_FeatureStatus:
                self.setText(text: "[Feature Status]\n\(data.stringValue)")
                self.isTheOperationOngoing = false
                break
            case MTU_EventType_TransactionStatus:
                self.transactionStatusHandler(dataString: data.stringValue)
                break
            case MTU_EventType_NFCEvent:
                self.nfcEventHandler(dataString: data.stringValue)
                break;
            case MTU_EventType_NFCData:
                self.nfcDataHandler(data: data.byteArray)
                break;
            case MTU_EventType_NFCCardData:
                self.nfcCardDataHandler(data: data.byteArray)
                break;
            case MTU_EventType_NFCPassThroughData:
                let hexData = HexUtil.toHex(data.byteArray);
                self.setText(text: "[NFC PassThrough Data]\n\(hexData ?? "")")
                break;
            case MTU_EventType_NFCPassThroughResponse:
                let hexData = HexUtil.toHex(data.byteArray);
                self.setText(text: "[NFC PassThrough Response]\n\(hexData ?? "")")
                break;
            case MTU_EventType_AuthorizationRequest:
                // Handle ARQC data
                self.authorizationRequestHandler(data: data.byteArray)
                break
            case MTU_EventType_TransactionResult:
                // Handle Batch data
                self.transactionResultHandler(data: data.byteArray)
                break
            case MTU_EventType_PINData:
                self.pinDataHandler(data: data.byteArray)
                break
            case MTU_EventType_PANData:
                self.panDataHandler(data: data.byteArray)
                break
            case MTU_EventType_BarCodeData:
                self.barcodeDataHandler(data: data.byteArray)
                OpenDeviceViewController.isTransactionOngoing = false
                break
                
            case MTU_EventType_UserEvent:
                let userEvent = HexUtil.toHex(data.byteArray)?.uppercased() ?? "Unknown"
                self.debugPrintLog("User Event Data: \(userEvent)")
                self.setText(text: "[User Event]\n\(data.stringValue)")
                break
                
            case MTU_EventType_DeviceResponse:
                let temp = HexUtil.toHex(data.byteArray)?.uppercased() ?? "No Data"
                self.debugPrintLog("EventType: \(eventType), Device Response: \(temp)")
                self.setText(text: "[Device Response]\n\(temp)")
                break
            
            case MTU_EventType_DeviceEvent:
                // e.g. "Device_Not_Paired"
                self.deviceEventHandler(data.stringValue)
                break
                
            case MTU_EventType_DeviceNotification:
                self.deviceNotificationDataHandler(data: data.byteArray)
                break
                
            case MTU_EventType_DisplayMessage:
                // Parse message like Welcome, Thank You, Tap Card, etc. Display Messages
                self.displayMessageNotificationDataHandler(data: data.byteArray)
                break
                
            case MTU_EventType_TouchScreenPresentCardFunctionalButtonSelected:
                OpenDeviceViewController.isTransactionOngoing = false
                break;
            case MTU_EventType_TouchScreenPersonalInfo:
                let personalInfo =  PersonalInfoEntryBuilder.getPersonalInfoEntry(MTU_DeviceType_MMS, data: data.byteArray)
                self.debugPrintLog("PersonalInfo : \(personalInfo)")
                self.setText(text: "PersonalInfo : \(personalInfo)")
                break
            default:
                let log = HexUtil.toHex(data.byteArray)?.uppercased() ?? "No Data"
                self.debugPrintLog("onEvent callback Default Case - EventType: \(eventType), Device Response Data: \(log)")
                //self.setText(text: "[Default Case - \(eventType)]\n\(temp)")
                break
            }
        }
    }
    
}

// MARK: - Private helpers

private extension OpenDeviceViewController {
    
    func connectionStateHandler(_ connectionStateString: String) {
        self.setText(text: "Connection State Changed - \(connectionStateString)")
        switch connectionStateString {
        case MTUConstant.kConnectionStateConnectingString:
            self.connectDeviceStartTime = CFAbsoluteTimeGetCurrent()
            self.btnTopConnect.isEnabled = false
            OpenDeviceViewController.isConnecting = true
        case MTUConstant.kConnectionStateDisconnectingString:
            self.disconnectDeviceStartTime = CFAbsoluteTimeGetCurrent()
            self.btnTopConnect.isEnabled = false
            OpenDeviceViewController.isConnecting = true
            
        case MTUConstant.kConnectionStateConnectedString:
            if self.connectDeviceStartTime != 0.0 {
                self.outputOperationRuntime(op: "Connect Device", startTime: self.connectDeviceStartTime)
                self.connectDeviceStartTime = 0.0
            }
            OpenDeviceViewController.isConnecting = false
            self.stateDeviceConnect()
            //self.loadDynaFlexInfo()
        case MTUConstant.kConnectionStateDisconnectedString:
            if self.disconnectDeviceStartTime != 0.0 {
                self.outputOperationRuntime(op: "Disconnect Device", startTime: self.disconnectDeviceStartTime)
                self.disconnectDeviceStartTime = 0.0
            }
            OpenDeviceViewController.isConnecting = false
            self.stateDeviceDisconnect()
            self.btnDisplayIP.isEnabled = true
            
            turnOnReconnect()
            /*
            if (!OpenDeviceViewController.deviceErrorOccur) {
                OpenDeviceViewController.deviceWillReset = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.topConnect()
                }
            }
             */
        case MTUConstant.kConnectionStateErrorString:
            OpenDeviceViewController.isConnecting = false
            self.stateDeviceDisconnect()
            self.btnDisplayIP.isEnabled = true
        default:
            break
        }
    }
    
    func deviceEventHandler(_ deviceEventString: String) {
        if MTUConstant.kBleDeviceNotPairedString == deviceEventString {
            OpenDeviceViewController.isConnecting = false
            self.stateDeviceDisconnect()
            self.btnDisplayIP.isEnabled = true
            
            self.setText(text: "The BLE Device is not paired yet!\nPlease enter the pairing mode (Press the Power Button x 4 beeps on DynaFlex II Go) and pair the Device first.")
        } 
        else {
            // do nothing yet
        }
    }
    
    func deviceNotificationDataHandler(data: Data) {
        //let hexString = HexUtil.toHex(data)?.uppercased() ?? "No Data"
        //debugPrintLog("onEvent callback Device Notification dataString: \(hexString)")
    }
    
    func displayMessageNotificationDataHandler(data: Data) {
        let hexString = HexUtil.toHex(data)?.uppercased() ?? "No Data"
        debugPrintLog("onEvent callback DisplayMessage Notification dataString: \(hexString)")
        
        let tlv: [AnyHashable: Any] = (data as NSData).parseTLVDataWithNoLength()!
        if let asciiTag83Value = ((tlv["83"] as? MTTLV)?.value)?.hexStringToAscii {
            if asciiTag83Value == MTUConstant.asciiTimout || asciiTag83Value == MTUConstant.asciiFailed {
                if OpenDeviceViewController.isTransactionOngoing { OpenDeviceViewController.isTransactionOngoing = false }
                if isTheOperationOngoing { isTheOperationOngoing = false }
            }
            
            // let dumpTLVs = tlv.dumpTags(),
            //print("Dump DisplayMsg TLVs: \(dumpTLVs)")
            setText(text: self.displayMessage(asciiTag83Value))
        }
    }
    
    func authorizationRequestHandler(data: Data) {
        var tlv: [AnyHashable: Any] = [:]
        var arqcDataString = ""
        
        // Passing zero for the value is useful for when two threads need to reconcile the completion of a particular event.
        // Passing a value greater than zero is useful for managing a finite pool of resources, where the pool size is equal to the value.
        let dSemaphore = DispatchSemaphore(value: 0)
        let queue = OperationQueue()
        
        let temp = HexUtil.toHex(data)?.uppercased()
        if let indexVal = temp?.indexDistance(of: "F9"){
            queue.addOperation {
                arqcDataString = (temp as NSString?)!.substring(from: indexVal)
                let emvBytes = HexUtil.getBytesFromHexString(arqcDataString)!
                
                tlv = emvBytes.parseTLVDataWithNoLength()!
                dSemaphore.signal()
            }
            dSemaphore.wait()
        }
        
        queue.waitUntilAllOperationsAreFinished()
        
        DispatchQueue.main.async {
            self.setText(text: "\n[ARQC Data]\n\(temp!)")
            
            if let dumpTags = tlv.dumpTags() {
                self.setText(text: "\n[ARQC TLV Parsed Data]\n\(dumpTags)")
            }
            
            self.tlvData = NSMutableDictionary.init(dictionary: tlv)
            
            // Authorization Request Cryptogram (ARQC) is a Ciphertext used for a process called Online Authorization.
            self.onARQCReceived(data)
        }
    }
    
    func barcodeDataHandler(data: Data) {
        let barCodeData = HexUtil.toHex(data)?.uppercased() ?? "N/A"
        self.setText(text: "[Barcode Data]\n \(barCodeData)")
        
        let bc: BarCodeData = BarCodeDataBuilder.getBarCodeData(MTU_DeviceType_MMS, data: data)!
        if let result = HexUtil.toHex(bc.data)?.uppercased() {
            self.debugPrintLog("Got Barcode Data HexResult: \(result)")
            self.setText(text: "ASCII Text=\(result.hexStringToAscii)")
            
            // Check "https:" exists or not in the result
            if let indexVal = result.indexDistance(of: "68747470733A") {
                let dataString = (result as NSString?)!.substring(from: indexVal)
                let urlString = dataString.stringFromHexString
                let url = NSURL(string: urlString)
                UIApplication.shared.open(url! as URL)
            }
        }
    }
    
    func operationStatusHandler(dataString: String) {
        let log = "[Operation Status]\n\(dataString)"
        debugPrintLog(log)
        setText(text: "[Operation Status]\n\(dataString)")
        
        if OpenDeviceViewController.isTransactionOngoing && dataString.index(of: MTUConstant.operationFailed) != nil {
            OpenDeviceViewController.isTransactionOngoing = false
        }
        if isTheOperationOngoing && dataString.index(of: MTUConstant.operationFailed) != nil { isTheOperationOngoing = false }
    }
    
    // Transaction process status
    func transactionStatusHandler(dataString: String) {
        setText(text: "[Transaction Status]\n\(dataString)")
        
        // Works for DF2PED and DF2GO
        if MTUConstant.codeTransactionExceptionStatusSet.contains(dataString.lowercased()) {
            OpenDeviceViewController.isTransactionOngoing = false
        }
    }
    
    func NfcCardChanged(nfcType : MTNFCCardType ) {
        if (nfcCardType != nfcType) {
            nfcCardType = nfcType
            didUpdateNfcCardType(nfcType: nfcCardType)
        }
    }

    // NFC process data
    func nfcDataHandler (data: Data) {
        let uid = data.hexadecimalString
        self.setText(text: "[NFC Data]\n\(uid)\n")
    }
    
    // NFC process data
    func nfcCardDataHandler (data: Data) {
        let carddata = data.hexadecimalString
        self.setText(text: "[NFC Card Data]\n\(carddata)\n")
    }
    
    // NFC process event
    func nfcEventHandler (dataString: String) {
        let nfcEvent = NFCEventBuilder.getEventValue(dataString)
        switch (nfcEvent) {
        case MTU_NFCEvent_NFCMifareUltralight:
            NfcCardChanged(nfcType: .ntag)
        case MTU_NFCEvent_MifareClassic1K:
            NfcCardChanged(nfcType: .mifare_classic_1k)
        case MTU_NFCEvent_MifareClassic4K:
            NfcCardChanged(nfcType: .mifare_classic_4k)
        case MTU_NFCEvent_MifareDESFire:
            NfcCardChanged(nfcType: .mifare_desfire)
        case MTU_NFCEvent_MifareMini:
            NfcCardChanged(nfcType: .mifare_mini)
        case MTU_NFCEvent_MifarePlusEV1:
            NfcCardChanged(nfcType: .mifare_plus_ev1)
        case MTU_NFCEvent_MifarePlusEV2:
            NfcCardChanged(nfcType: .mifare_plus_ev2)
        case MTU_NFCEvent_MifarePlusSE:
            NfcCardChanged(nfcType: .mifare_plus_se)
        case MTU_NFCEvent_MifarePlusX:
            NfcCardChanged(nfcType: .mifare_plus_x)
        case MTU_NFCEvent_TagRemoved:
            NfcCardChanged(nfcType: .none)
        default:
            break
        }
        if MTUConstant.codeTransactionExceptionStatusSet.contains(dataString.lowercased()) {
            OpenDeviceViewController.isTransactionOngoing = false
        }
    }
    
    func transactionResultHandler(data: Data) {
        OpenDeviceViewController.isTransactionOngoing = false
        let dataString = data.hexadecimalString
        self.setText(text: "[Batch Data]\n\(dataString)")
        debugPrintLog("Transaction Result - didReceive raw Batch Data string: \(dataString)")
        let emvBytes = HexUtil.getBytesFromHexString(dataString as String)! as NSData
        let tlv = emvBytes.parseTLVData()
        batchData = tlv as? NSMutableDictionary
    }
    
    func pinDataHandler(data: Data) {
        let pin = HexUtil.toHex(data)?.uppercased()
        let pinData: PINData = PINDataBuilder.getPINData(MTU_DeviceType_MMS, data: data)!
        let pinKSN = HexUtil.toHex(pinData.ksn)?.uppercased()
        self.setText(text: "[PIN Data]\n\(pin!)\n\n[PIN KSN]\n\(pinKSN!) \n")
        
        if self.hasPanArrived {
            self.backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                
                let stopPin = PINRequest.newRequest(30, mode: 0xff, min: 4, max: 8, tone: 1, format: 0, pan: "000000000000")
                let stopPan = PANRequest.newRequest(30, payment: .MSR)
                weakSelf.theSelectedDevice?.requestPAN(stopPan, withPIN: stopPin, completionHandler: { resultFlag in
                    if resultFlag {
                        weakSelf.setText(text:"PAN Stopped!")
                    }
                })
            }
        }
        else {
            self.backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                
                let stopPin = PINRequest.newRequest(30, mode: 0xff, min: 4, max: 8, tone: 1, format: 0, pan: "000000000000")
                weakSelf.theSelectedDevice?.requestPIN(stopPin, completionHandler: { resultFlag in
                    if resultFlag {
                        weakSelf.setText(text:"PIN Stopped!")
                    }
                })
            }
        }
        
        self.hasPanArrived = false
    }
    
    func panDataHandler(data: Data) {
        let pan = HexUtil.toHex(data)?.uppercased()
        let panData:PANData = PANDataBuilder.getPANData(MTU_DeviceType_MMS, data: data)!
        let panKSN = HexUtil.toHex(panData.ksn)?.uppercased()
        self.setText(text:"[PAN Data] \n \(pan!) \n\n [PAN KSN] \n \(panKSN!)")
        self.hasPanArrived = true
    }
    
    
    func setupUI() {
        setupNavigationTitle()
        if let logDataView = txtData { logDataView.isEditable = false }
        
        UIApplication.shared.statusBarView?.frame = UIApplication.shared.mainKeyWindow?.windowScene?.statusBarManager?.statusBarFrame ?? .zero
        UIApplication.shared.statusBarView?.backgroundColor = .darkGray
        
        // Handle keyboard show and hide
        if bottomLayoutConstraint != nil {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillShow(_:)),
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillHide(_:)),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackgroundHandler),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc func appDidEnterBackgroundHandler(_ notification: NSNotification) {
        if isDeviceOpened() {
            devCtrl?.close()
        }
        OpenDeviceViewController.isConnecting = false
    }
    
    func setupNavigationTitle() {
        let fgColor = UIColor.white // isDarkMode ? UIColor.white : UIColor.black
        let textAttributes = [
            NSAttributedString.Key.foregroundColor: fgColor,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.backgroundColor = .darkGray
    }
    
    @objc func keyboardWillShow(_ notification: NSNotification) {
        guard let info = notification.userInfo,
              let keyboardHeight = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height
        else { return }
        
        let animationDuration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.0
        bottomLayoutConstraint?.constant = keyboardHeight
        
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        guard let info = notification.userInfo else { return }
        
        let animationDuration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.0
        bottomLayoutConstraint?.constant = 10.0
        
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
    
    func handleSelectedDevice() {
        if hasSelectedDeviceIpAddress {
            if self.devCtrl != nil {
                self.devCtrl!.close()
                
                // del org code
                //OpenDeviceViewController._devCtrl = nil
                //OpenDeviceViewController._cfg = nil
                //OpenDeviceViewController._device = nil
            }
            
            hasSelectedDeviceIpAddress = false
        }
        
        if self.theSelectedDevice != nil {
            // !!!: This function allows the host to be notified of all events sent by the device.
            // - (Boolean) subscribeAll :(id<IEventSubscriber>) delegate
            self.theSelectedDevice?.subscribeAll(self)
        }
        
        updateDeviceConnectionState()
    }
    
    func updateDeviceConnectionState() {
        if let device = self.theSelectedDevice {
            let state = device.getConnectionState()
            switch(state) {
            case MTU_ConnectionState_Connected:
                OpenDeviceViewController.isConnecting = false
                btnDisplayIP.isEnabled = false
                stateDeviceConnect()
                break;
            case MTU_ConnectionState_Disconnected:
                OpenDeviceViewController.isConnecting = false
                btnDisplayIP.isEnabled = true
                stateDeviceDisconnect()
                break;
            case MTU_ConnectionState_Connecting:
                btnDisplayIP.isEnabled = false
                btnTopConnect.isEnabled = false
                break;
            case MTU_ConnectionState_Disconnecting:
                btnDisplayIP.isEnabled = false
                btnTopConnect.isEnabled = false
                break;
            case MTU_ConnectionState_Error:
                OpenDeviceViewController.isConnecting = false
                btnDisplayIP.isEnabled = true
                btnTopConnect.isEnabled = true
                stateDeviceDisconnect()
                break
            default:
                break;
            }
        }
        else {
            btnDisplayIP.isEnabled = true
            btnTopConnect.isEnabled = true
            stateDeviceDisconnect()
        }
    }
    
}

// MARK: - SelectDeviceViewControllerDelegate

extension OpenDeviceViewController: SelectDeviceViewControllerDelegate {
    
    func didSelectedReader(_ viewController: SelectDeviceViewController, device: IDevice?) {
        navigationController?.popViewController(animated: true)
        
        OpenDeviceViewController.hasSelectedDynaFlexIIGo = viewController.isSelectingDynaFlexIIGo
        hasSelectedDeviceIpAddress = true
        
        if let selectDeviceAddress = viewController.currentSelectedDeviceAddress {
            OpenDeviceViewController._selectIPAddress = selectDeviceAddress
            btnDisplayIP.setTitle(selectDeviceAddress, for: .normal)
        }
        
        //backgroundManagementQueue.async {
            OpenDeviceViewController._device = viewController.currentSelectedDevice
        //}
        
        // Set IEventSubscriber delegate
        handleSelectedDevice()
        
        btnDisplayIP.isEnabled = false
        btnTopConnect.isEnabled = false
        
        // 1 to 0.75
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            // Connect the selected WebSocket or BLE device directly
            self.topConnect()
        }
    }
    
}
