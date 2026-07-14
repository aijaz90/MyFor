//
//  HomeViewController.swift
//  MTUSDK_Sample
//
//  Created by Wenbo Ma on 1/4/22.
//

import UIKit
import MTUSDK
import CoreData
import MTAESDUKPT

// EMV ViewController
class EMVViewController: OpenDeviceViewController {
    
    @IBOutlet var emvOnlySwitch: UISwitch!
    @IBOutlet var quickChipSwitch: UISwitch!
    @IBOutlet var hostDrBackSwitch: UISwitch!
    @IBOutlet var signCaptureSwitch: UISwitch!
    
    @IBOutlet var eventDrTranSwitch: UISwitch!
    @IBOutlet var MSRSwitch: UISwitch!
    @IBOutlet var contactSwitch: UISwitch!
    @IBOutlet var contactlessSwitch: UISwitch!
    @IBOutlet var nfcSwitch: UISwitch!
    @IBOutlet var tiptaxSwitch: UISwitch!
    @IBOutlet var barcodeSwitch: UISwitch!
    
    @IBOutlet var displayAmountSwitch: UISwitch!
    @IBOutlet var vasSwitch: UISwitch!
    @IBOutlet var ecp2Switch : UISwitch!
    @IBOutlet var customNfcSwitch : UISwitch!

    
    @IBOutlet var amountTxt: UITextField!
    @IBOutlet var btnStartTran: UIButton!
    @IBOutlet var btnManual: UIButton!
    
    private var hostFallback: HostDrivenFallbackManager? = nil
    private var mTransaction = ITransaction()
    
    private var deviceCapability : DeviceCapability? = nil

    private enum EmvConstant {
        static let emptyAmountMessage = "Please input the amount to transfer."
    }
    
    /// callback for nfc command
    private var nfcHandler : ((_ success : Bool , _ data : String?)->Void)? = nil
    
    private var pollingTimer : Timer? = nil
    
    // MARK: - VC Life cycle
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        // ecp2Switch.addTarget(self, action: #selector(toggleECP2), for: .valueChanged)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        setupHostDrivenFallback()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        setupAmountTextField()
    }
    
    override func stateDeviceDisconnect() {
        super.stateDeviceDisconnect()
        
        deviceCapability = nil
        
        configureButtonStates(isEnabled: false)
     }
    
    override func stateDeviceConnect(){
        super.stateDeviceConnect()
        
        DispatchQueue.main.async {
            self.deviceCapability = self.theSelectedDevice?.getCapability()
            
            self.configureButtonStates(isEnabled: true)

        }
    }
    
    // MARK: - Actions
    
    // User Event Notification Controls Enable -- Event Driven Transaction
    @IBAction func setEventDriven() {
        // Here no need to set property at all
//        let value = eventDrTranSwitch.isOn ? "7F000000" : "00000000"
//        
//        backgroundManagementQueue.async { [weak self] in
//            guard let weakSelf = self else { return }
//            let info = ConfigurationInfo.initWithASN1Oid("1.2.7.1.2.1", hexValue: value)!
//            weakSelf.cfg?.setConfigInfo(info.configType, data: info.oidAndValue, callback: self)
//        }
    }
    
    @IBAction func toggleHostDrivenFallback(_ sender: UISwitch) {
        setupHostDrivenFallback()
    }
    
    @IBAction func toggleQuickchip(_ sender: UISwitch) {
        if (quickChipSwitch.isOn) {
            displayAmountSwitch.isEnabled = true
        } else {
            displayAmountSwitch.isOn = false
            displayAmountSwitch.isEnabled = false
        }
    }
    
    @IBAction func toggleContactless(_ sender: UISwitch) {
        if (contactlessSwitch.isOn) {
            vasSwitch.isEnabled = true
        } else {
            vasSwitch.isOn = false
            vasSwitch.isEnabled = false
        }
    }
    
    @IBAction func toggleECP2() {
        if (ecp2Switch.isOn) {
            self.present( EMVSettingsViewController.shared, animated: true)
        }
    }
    
    // Start EMV
    @IBAction func startTransactionButtonTapped() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        var paymentMethods: MTU_PaymentMethod = []
        if MSRSwitch.isEnabled && MSRSwitch.isOn { paymentMethods.insert(.MSR) }
        if contactSwitch.isEnabled && contactSwitch.isOn { paymentMethods.insert(.contact) }
        if contactlessSwitch.isOn { paymentMethods.insert(.contactless) }
        if nfcSwitch.isOn { paymentMethods.insert(.NFC) }
        if barcodeSwitch.isEnabled && barcodeSwitch.isOn { paymentMethods.insert(.barCode) }
        if vasSwitch.isOn {
            paymentMethods.insert(.appleVAS)
            paymentMethods.insert(.googleVAS)
        }
        
        startEmvTransaction(paymentMethods)
    }
    
    // Manually transaction
    @IBAction func manualOperation() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard !OpenDeviceViewController.hasSelectedDynaFlexIIGo else {
            warningAlert(MTUConstant.notSupportedOperation)
            return
        }
        
        guard !EMVViewController.isTransactionOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        EMVViewController.isTransactionOngoing = true
        setText(text: MTUConstant.transactionStarted)
        
        // By default "1"
        var amount = "1"
        if let inputAmount = amountTxt.text, !inputAmount.isEmpty {
            amount = inputAmount.replacingOccurrences(of: "$", with: "")
        }
        
        // MTU_PaymentMethod_ManualEntry = 8,
        let transaction = ITransaction.amount(
            amount,
            cashback: "0.0",
            transactionType: UInt8(MTUConstant.transactionType),
            timeout: UInt8(MTUConstant.transactionTimeout),
            for: [.manualEntry],
            quickChip: false
        )
        
        setText(text: "Amount=\(amount), Timeout=\(MTUConstant.transactionTimeout), Transaction Type=\(MTUConstant.transactionType), ManualEntry=True")
        
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            let startTime = CFAbsoluteTimeGetCurrent()
            weakSelf.theSelectedDevice?.start(transaction, completionHandler: { resultFlag in
//                if resultFlag {
//                    weakSelf.setText(text: "\(MTUConstant.manualStartTransactionOperationName) Success")
//                } else {
//                    weakSelf.setText(text: "\(MTUConstant.manualStartTransactionOperationName) Failed")
//                }
                weakSelf.outputOperationRuntime(op: MTUConstant.manualStartTransactionOperationName, startTime: startTime)
            })
        }
    }
    
    // Stop EMV
    @IBAction func stopTransactionButtonTapped() {
        guard isDeviceOpened() else {
            warningAlert(MTUConstant.connectDeviceAlertMsg)
            return
        }
        
        guard EMVViewController.isTransactionOngoing else {
            warningAlert(MTUConstant.noTransactionOngoing)
            return
        }
        setText(text: MTUConstant.hostCancelledTransaction)
        
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            let startTime = CFAbsoluteTimeGetCurrent()
            weakSelf.theSelectedDevice?.cancelTransaction(completionHandler: { resultFlag in
                if resultFlag {
                    EMVViewController.isTransactionOngoing = false
                }
                weakSelf.outputOperationRuntime(op: MTUConstant.cancelTransactionOperationName, startTime: startTime)
            })
        }
    }
    
    override func didUpdateNfcCardType(nfcType : MTNFCCardType) {
        switch (nfcType)
        {
        case .ntag :
            readNtag()
        case .mifare_classic_1k:
            readMifareClassic()
        case .mifare_classic_4k:
            readMifareClassic()
        case .mifare_desfire:
            getDESFireVersion()
        default:
            break
        }
    }
    
    func readNtag() {
        
        setText(text: "Read NTAG card")
        let card = NTag(sendNfc: sendNFCAsync)
        Task {
            do {
                try await card.getVersion()
                let size = try await card.getMemorySize()
                setText(text: "card size : \(size)" )
                let ndefs = try await card.readNdef()
                for ndef in ndefs {
                    if (ndef.isText()) {
                        setText(text: "TEXT RECORD : \(ndef.getTextString()!)")
                    } else if (ndef.isUri()) {
                        setText(text: "URI RECORD : \(ndef.getUriString()!)")
                    } else {
                        setText(text: "RECORD BYTES : \(ndef.toBytes())")
                    }
                }
            }
            catch {
                if let nfcerror = error as? MTNFCError {
                    setText(text: "ERROR : \(nfcerror.Message)")
                } else {
                    setText(text: "ERROR : \(error)")
                }
            }
        }
    }
    
    func readMifareClassic() {
        setText(text: "Read Mifare Classic card")
        let card = MifareClassic(sendNfc: sendClassicNfcCommandAsync)
        let zeroKey : [UInt8] = [0,0,0,0,0,0]
        let ffffKey : [UInt8] = [0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
        Task {
            do {
                setText(text: "Try read sector 3 ...")
                let blockData = try await card.read(sector:3, starBlock: 1, endBlock:1, keyType:.A, key: ffffKey, lastCommand: true)
                
                setText(text: "Read block 1 -> " + HexUtil.toHex(blockData))
                setText(text: "Success")
            }
            catch {
                setText(text: "ERROR : \(error.localizedDescription)")
            }
        }
    }
    
    /// read card version (60 command)
    func getDESFireVersion() {
        setText(text:"Get DESFire card version")
        let card = MifareDESFire(sendNfc: sendDESFireNfcCommandAsync)

        Task {
            do {
                
                let version = try await card.getVesion()
                
                setText(text: "MIFARE DESFire Card Version : \(version)")
            }
            catch {
                setText(text: "ERROR : \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - IEventSubscriber
    
    // Here handle the data between the App/Host and the Device
    override func onEvent(_ eventType: MTU_EventType, data: IData!) {
        super.onEvent(eventType, data: data)

        DispatchQueue.main.async {
            
            if (self.hostFallback != nil && self.hostDrBackSwitch.isOn && self.hostDrBackSwitch.isEnabled) {
                self.hostFallback?.onEvent(eventType, data: data)
            }
            
            switch eventType {
            case MTU_EventType_AuthorizationRequest:
                // If in Quick Chip mode, just break because no need to send Authorization Response Code (ARPC) to the device
                
                let startTime = CFAbsoluteTimeGetCurrent()
                
                let encryptedData : MTEncryptedData = MTEncryptedData(selectableCardDataKey: "FEDCBA9876543210F1F1F1F1F1F1F1F1")
                do {
                    let selectableCardData = try encryptedData.getSelectableCardData(arqc: data.byteArray)
                    
                    self.outputOperationRuntime(op: "Initialize object and decrypt data (SCDE)", startTime: startTime)
                    
                    if (selectableCardData.cardDataFields.contains(.cardHolderName))  { self.setText(text: "Name: \(selectableCardData.cardHolderName ?? "")") }
                    if (selectableCardData.cardDataFields.contains(.primaryAccountNumber))  { self.setText(text: "PAN: \(selectableCardData.primaryAccountNumber ?? "")") }
                    if (selectableCardData.cardDataFields.contains(.expirationDate))  { self.setText(text: "EXP: \(selectableCardData.expirationDate ?? "")") }
                    if (selectableCardData.cardDataFields.contains(.serviceCode))  { self.setText(text: "SEV: \(selectableCardData.serviceCode ?? "")") }
                    if (selectableCardData.cardDataFields.contains(.track1DiscretionaryData))  { self.setText(text: "T1: \(selectableCardData.track1DiscretionaryData ?? "")") }
                    if (selectableCardData.cardDataFields.contains(.track2DiscretionaryData))  { self.setText(text: "T2: \(selectableCardData.track2DiscretionaryData ?? "")") }
                }
                catch{
                    self.setText(text: "Exception to get selectable card data - \(error)")
                }
                // If in non-QuickChip mode, the App/Host send the ARPC to the Device.
                if !self.quickChipSwitch.isOn {
                    self.processAuthorizationRequest(data)
                }
                break
                
            case MTU_EventType_TransactionStatus:
                let tStatus = TransactionStatusBuilder.getStatusCode(data.stringValue)
                if (tStatus == MTU_TransactionStatus_SignatureCaptureRequested && !self.hostDrBackSwitch.isOn && self.signCaptureSwitch.isOn && self.signCaptureSwitch.isEnabled) {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    self.theSelectedDevice?.requestSignature(completionHandler: { resultFlag in
                        if resultFlag {
                            self.debugPrintLog("\(MTUConstant.requestSignatureOperationName) Success")
                        } else {
                            self.debugPrintLog("\(MTUConstant.requestSignatureOperationName) Failed")
                        }
                        self.outputOperationRuntime(op: MTUConstant.requestSignatureOperationName, startTime: startTime)
                    })
                }
                break;
                
            case MTU_EventType_Signature:
                let signatureData = data.byteArray.hexEncodedString()
                self.setText(text: "[Signature Data]\n\(signatureData)\n")
                break;
                
            case MTU_EventType_InputRequest:
                let inputRequestData = data.byteArray.hexEncodedString()
                self.setText(text: "[Input Request Data]\n\(inputRequestData)\n")
                self.requestUserSelect(data.byteArray)
                break;
                
            case MTU_EventType_EnhancedInputRequest:
                let inputRequestData = data.byteArray.hexEncodedString()
                self.setText(text: "[Enhanced Input Request Data]\n\(inputRequestData)\n")
                self.requestUserSelectEnhanced(data.byteArray)
                break;
                
            case MTU_EventType_UserEvent:
                if self.eventDrTranSwitch.isOn {
                    let userEvent = UserEventBuilder.getValue(data.stringValue)
                    switch userEvent {
                    case MTU_UserEvent_CardSwiped:
                        self.startEmvTransaction(.MSR)
                    case MTU_UserEvent_CardSeated:
                        self.startEmvTransaction(.contact)  // chip transaction
                    case MTU_UserEvent_ContactlessCardPresented:
                        self.startEmvTransaction(.contactless) // contactless transaction
                    case MTU_UserEvent_TouchPresented:
                        self.startEmvTransaction([.MSR, .contact, .contactless])
                    default:
                        break
                    }
                }
                break
            case MTU_EventType_DeviceEvent:
                let event = DeviceEventBuilder.string(toDeviceEvent: data.stringValue)
                /*
                if (event == MTU_DeviceEvent_DeviceResetOccurred) {
                    // auto reconnect after 1 seconds
                    OpenDeviceViewController.deviceWillReset = true
                }
                 */
                break
            case MTU_EventType_NFCData:
                let uid = data.byteArray.hexadecimalString
                self.setText(text: "[NFC Data]\n\(uid)\n")
                break;
            case MTU_EventType_NFCEvent:
                self.setText(text: "[NFC Event]\n\(data.stringValue)\n")
                if let handler = self.nfcHandler {
                    self.nfcHandler = nil
                    handler(false, nil)
                }
                break;
            case MTU_EventType_NFCResponse:
                self.setText(text: "[NFC Response]\n\(data.byteArray.hexadecimalString)\n")
                if let handler = self.nfcHandler {
                    self.nfcHandler = nil
                    let nfcResponse = NFCDataBuilder.getNFC(MTU_DeviceType_MMS, data: data.byteArray)
                    handler(true, nfcResponse?.data.hexadecimalString)
                }
                break;
            case MTU_EventType_NFCRAPDUResponse:
                self.setText(text: "[NFC RAPDU Response]\n\(data.byteArray.hexadecimalString)\n")
                if let handler = self.nfcHandler {
                    self.nfcHandler = nil
                    let nfcRapduResponse = NFCDataBuilder.getNFC(MTU_DeviceType_MMS, rapduData: data.byteArray)
                    var rapduData = nfcRapduResponse!.data
                    rapduData.append(nfcRapduResponse!.response)
                    handler(true, rapduData.hexadecimalString)
                }
                break;
                
            case MTU_EventType_NFCCardData :
                self.setText(text: "[NFC Card Data]\n\(data.byteArray.hexadecimalString)\n")
                
            case MTU_EventType_BarCodeData:
                let barCodeData = BarCodeDataBuilder.getBarCodeData(MTU_DeviceType_MMS, data: data.byteArray)
                self.setText(text: "Barcode data: \n Encrypted : \(barCodeData!.encrypted)\n KSN : \(HexUtil.toHex(barCodeData!.ksn)!)\n Data : \(HexUtil.toHex( barCodeData!.data)!)\n")
                if !barCodeData!.encrypted {
                    self.setText(text: "TEXT : \(barCodeData!.data.toASCIIString) ")
                }
                break;
                
            default:
                break
            }
        }
    }
    
    func sendNfcCommand(_ hexCommand : String, _ lastCommand : Bool = false, _ handler : @escaping (_ success : Bool , _ data : String?)->Void ) {
        nfcHandler = handler
        
        let sendResult = theSelectedDevice!.sendNFCCommand(IData(hex: hexCommand), lastCommand: lastCommand, encrypt: false)
        
        if !sendResult {
            handler(false, nil)
            nfcHandler = nil
        }
    }
    
    func sendNFCAsync(_ command : String, _ lastCommand : Bool = false) async throws -> String {
        return try await withCheckedThrowingContinuation {
            continuation  in
            sendNfcCommand(command, lastCommand)
            {  success, resp in
                if !success {
                    continuation.resume(throwing: MTNFCError(Message: "failed") )
                }
                else {
                    
                    guard let resp = resp else {
                        continuation.resume(throwing: MTNFCError( Message: "no response"))
                        return
                    }
                    
                    continuation.resume(returning: resp)
                }
            }

        }
    }
    
    func sendClassicNfcCommand(_ hexCommand : String, _ lastCommand : Bool = false, _ handler : @escaping (_ success : Bool , _ data : String?)->Void ) {
        nfcHandler = handler
        
        let sendResult = theSelectedDevice!.sendClassicNFCCommand(IData(hex: hexCommand), lastCommand: lastCommand, encrypt: false)
        
        if !sendResult {
            handler(false, nil)
            nfcHandler = nil
        }
    }
    
    func sendClassicNfcCommandAsync(_ command : String, _ lastCommand : Bool = false) async throws -> String {
        return try await withCheckedThrowingContinuation {
            continuation  in
            sendClassicNfcCommand(command, lastCommand)
            {  success, resp in
                if !success {
                    continuation.resume(throwing: MTNFCError(Message: "failed") )
                }
                else {
                    guard let resp = resp else {
                        continuation.resume(throwing: MTNFCError( Message: "no response"))
                        return
                    }
                    
                    continuation.resume(returning: resp)
                }
            }
        }
    }
    
    func sendDESFireNfcCommand(_ hexCommand : String, _ lastCommand : Bool = false, _ handler : @escaping (_ success : Bool , _ data : String?)->Void ) {
        nfcHandler = handler
        
        let sendResult = theSelectedDevice!.sendDESFireNFCCommand(IData(hex: hexCommand), lastCommand: lastCommand, encrypt: false)
        
        if !sendResult {
            handler(false, nil)
            nfcHandler = nil
        }
    }
    
    func sendDESFireNfcCommandAsync(_ command : String, _ lastCommand : Bool = false) async throws -> String {
        return try await withCheckedThrowingContinuation {
            continuation  in
            sendDESFireNfcCommand(command, lastCommand)
            {  success, resp in
                if !success {
                    continuation.resume(throwing: MTNFCError(Message: "failed") )
                }
                else {
                    guard let resp = resp else {
                        continuation.resume(throwing: MTNFCError( Message: "no response"))
                        return
                    }
                    
                    continuation.resume(returning: resp)
                }
            }
        }
    }
    
    func sendSelection (_ index : Int) {
        let selectionBytes : [UInt8] = [0, UInt8(index)]
        theSelectedDevice!.sendSelection(IData(data: Data(bytes: selectionBytes, count: 2)))
    }
    
    func requestUserSelect( _ data : Data) {
        let itemsString =  data.suffix(from: 2).toASCIIString
        let title = data.first! == 0 ? "Language" : "Application"
        let timeout : TimeInterval =  Double (data.suffix(from: 1).first!)
        let separator : CharacterSet = NSCharacterSet(charactersIn: "\0x00\0x0A") as CharacterSet
        let items = itemsString.components(separatedBy: separator).filter{!$0.isEmpty}
        let message = items.first!
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        for (index, item) in items.suffix(from: 1).enumerated() {
            print(item)
            
            let action = UIAlertAction(title: item, style: .default) { _ in
                self.setText(text: "Select - \(item)")
                self.sendSelection(index)
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) {_ in 
            self.setText(text: "User Cancel")
            let selectionBytes : [UInt8] = [1, 0]
            self.theSelectedDevice!.sendSelection(IData(data: Data(bytes: selectionBytes, count: 2)))
        })
        
        Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) {_ in 
            if !alert.isBeingDismissed {
                alert.dismiss(animated: true)
            }
        }
        
        self.present(alert, animated: true)
    }
    
    func requestUserSelectEnhanced( _ data : Data) {
        let itemsString =  data.suffix(from: 2).hexadecimalString
        let title = data.first! == 0 ? "Language" : "Application"
        let separator : CharacterSet = NSCharacterSet(charactersIn: "\0x00\0x0A") as CharacterSet
        
        let timeout : TimeInterval =  Double (data.suffix(from: 1).first!)
        
        do {
            let tlvs = try RTLV.parse(data: data.suffix(from: 2) , recursive: true)
            let message = "Enhanced Application Selection"
            var aids : [String] = []
            var labels :[String] = []
            for tlv in tlvs {
                if (tlv.tag == "4F") {
                    aids.append(tlv.value)
                }
                if (tlv.tag == "50") {
                    labels.append(tlv.value.hexStringToAscii)
                }
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            for (index, item) in aids.enumerated() {
                let subItems = labels[index] + " - " + item
                print (subItems)
                
                let action = UIAlertAction(title: subItems, style: .default) { _ in
                    self.setText(text: "Select - \(subItems)")
                    self.sendSelection(index)
                }
                alert.addAction(action)
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) {_ in
                self.setText(text: "User Cancel")
                let selectionBytes : [UInt8] = [1, 0]
                self.theSelectedDevice!.sendSelection(IData(data: Data(bytes: selectionBytes, count: 2)))
            })
            
            Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) {_ in
                if !alert.isBeingDismissed {
                    alert.dismiss(animated: true)
                }
            }
            
            self.present(alert, animated: true)
        }
        catch {
            
        }
    }
}

// MARK: - Private helpers

private extension EMVViewController {
    
    func setupUI() {
        setupAmountTextField()
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
    
    func setupAmountTextField() {
        let textColor = isDarkMode ? UIColor.init(white: 1.0, alpha: 0.7) : UIColor.darkGray
        let attributedString = AttributedString("$1.00", attributes: AttributeContainer.init([
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14),
            NSAttributedString.Key.foregroundColor: textColor
        ]))
        
        amountTxt.attributedPlaceholder = NSAttributedString(attributedString)
    }
    
    func useMsrCallback() {
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            
            // While the host is waiting for the timeout to expire, it should not send any commands to the device, because the device is busy processing the current command.
            // message ID is 0x12 - "Use MagStripe"
            if (weakSelf.deviceCapability!.paymentMethods.contains(.MSR) ) {
                
                if (weakSelf.deviceCapability!.display) {
                    weakSelf.devCtrl?.displayMessage(18, timeout: 3)
                    weakSelf.setText(text: weakSelf.displayMessage("USE MAGSTRIPE"))
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
                    weakSelf.mTransaction.preventMSRSignatureForCardWithICC = false
                    weakSelf.startEmvTransaction(.MSR)
                }
            }
        }
    }
    
    func useChipCallback() {
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            
            // 0x11 - "Use Chip Reader"
            if (weakSelf.deviceCapability!.display) {
                weakSelf.devCtrl?.displayMessage(17, timeout: 3)
                weakSelf.setText(text: weakSelf.displayMessage("USE CHIP READER"))
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
                var paymentMethods: MTU_PaymentMethod = []
                if weakSelf.contactSwitch.isOn { paymentMethods.insert(.contact) }
                if weakSelf.contactlessSwitch.isOn { paymentMethods.insert(.contactless) }
                weakSelf.startEmvTransaction(paymentMethods)
            }
        }
    }
    
    func captureSignatureCallback() {
        if signCaptureSwitch.isOn  {
            backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                
                let startTime = CFAbsoluteTimeGetCurrent()
                weakSelf.theSelectedDevice?.requestSignature(completionHandler: { resultFlag in
                    if resultFlag {
                        weakSelf.debugPrintLog("\(MTUConstant.requestSignatureOperationName) Success")
                    } else {
                        weakSelf.debugPrintLog("\(MTUConstant.requestSignatureOperationName) Failed")
                    }
                    weakSelf.outputOperationRuntime(op: MTUConstant.requestSignatureOperationName, startTime: startTime)
                })
            }
        }
    }
    
    func tryAgainCallback() {
        backgroundManagementQueue.async { [weak self] in
            guard let weakSelf = self else { return }
            
            // 0x13 - “TRY AGAIN”
            weakSelf.devCtrl?.displayMessage(19, timeout: 3)
            weakSelf.setText(text: weakSelf.displayMessage("TRY AGAIN"))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
                var paymentMethods: MTU_PaymentMethod = []
                if weakSelf.MSRSwitch.isOn { paymentMethods.insert(.MSR) }
                if weakSelf.contactSwitch.isOn { paymentMethods.insert(.contact) }
                if weakSelf.contactlessSwitch.isOn { paymentMethods.insert(.contactless) }
                weakSelf.startEmvTransaction(paymentMethods)
            }
        }
    }
    
    private func setupHostDrivenFallback() {
        if hostDrBackSwitch.isOn {
            // Prevent signature capture on device during MSR transaction if card has ICC
            mTransaction.preventMSRSignatureForCardWithICC = true
            
            hostFallback = HostDrivenFallbackManager(
                useMsr: useMsrCallback,
                useChip: useChipCallback,
                captureSignature: captureSignatureCallback,
                tryAgain: tryAgainCallback
            )
        }
        else {
            hostFallback = nil
        }
    }
    
    private func hasPaymentMethod(paymentMethods: MTU_PaymentMethod, option: MTU_PaymentMethod) -> String {
        paymentMethods.contains(option) ? "True" : "False"
    }
    
    private func showTransactionMessages(paymentMethods: MTU_PaymentMethod, amount: String) {
        setText(text: "Amount=\(amount), Timeout=\(MTUConstant.transactionTimeout), Transaction Type=\(MTUConstant.transactionType)")
        let hasMSR = hasPaymentMethod(paymentMethods: paymentMethods, option: .MSR)
        let hasContact = hasPaymentMethod(paymentMethods: paymentMethods, option: .contact)
        let hasContactless = hasPaymentMethod(paymentMethods: paymentMethods, option: .contactless)
        setText(text: "MSR=\(hasMSR), Contact=\(hasContact), Contactless=\(hasContactless)")
    }
    
    // Start Transaction
    private func startEmvTransaction(_ payments: MTU_PaymentMethod) {
        guard isDeviceOpened() else { return }
        guard !payments.isEmpty else { return }
        
        guard !EMVViewController.isTransactionOngoing else {
            warningAlert(MTUConstant.waitTheOperationToComplete)
            return
        }
        EMVViewController.isTransactionOngoing = true
        setText(text: MTUConstant.transactionStarted)
        
        DispatchQueue.main.async { [weak self] in
            guard let weakSelf = self else { return }
            
            // By default "1"
            var amount = "1"
            if let inputAmount = weakSelf.amountTxt.text, !inputAmount.isEmpty {
                amount = inputAmount.replacingOccurrences(of: "$", with: "")
            }
            
            // Create a Transaction instance
            let transaction = ITransaction.amount(
                amount,
                cashback: "0.0",
                transactionType: UInt8(MTUConstant.transactionType),
                timeout: UInt8(MTUConstant.transactionTimeout),
                for: payments,
                quickChip: weakSelf.quickChipSwitch.isOn
            )
            
            transaction.currencyCode = HexUtil.getBytesFromHexString("0840")! as Data;
            
            //transaction.suppressThankYouMessage = true
            if (weakSelf.hostDrBackSwitch.isOn && payments.contains(.contact)) {
                transaction.preventMSRSignatureForCardWithICC = true
                transaction.suppressThankYouMessage = true
            }
            
            if (weakSelf.tiptaxSwitch.isOn) {
                transaction.tipMode = 1; //using amount
                transaction.tip1DisplayMode = 0;
                transaction.tip1Value = "0.10";
                transaction.tip2DisplayMode = 0;
                transaction.tip2Value = "0.15";
                transaction.tip3DisplayMode = 0;
                transaction.tip3Value = "0.20";
                transaction.tip4DisplayMode = 1; // custom
                transaction.tip4Value = "";
                transaction.tip5DisplayMode = 3; // disabled
                transaction.tip5Value = "";
                transaction.tip6DisplayMode = 3; // disabled
                transaction.tip6Value = "";
                
                transaction.taxAmount = "10.00";
            }
            if (weakSelf.displayAmountSwitch.isOn) {
                transaction.displayAmountForQuickChip = true
            }
            
            if (payments.contains(.googleVAS) || payments.contains(.appleVAS)) {
                transaction.appleVASMode = .dual
                transaction.appleVASProtocol = .full
            }
            
            if (weakSelf.ecp2Switch.isOn) {
                transaction.appleVASMode = .ECP2
                transaction.appleVASProtocol = .full
                
                transaction.ecp2FrameData = EMVSettingsViewController.getValue(forKey: ECP2FrameDataKey)?.dataFromHexString ?? Data()
            }
            
            if (weakSelf.customNfcSwitch.isOn) {
                transaction.customNFCDataMode = .ASCII
                transaction.customNFCTransactionMode = [.appleWalletMobileDESFire]
            }
            
            weakSelf.showTransactionMessages(paymentMethods: payments, amount: amount)
            weakSelf.mTransaction = transaction
            
            weakSelf.backgroundManagementQueue.async {
                let startTime = CFAbsoluteTimeGetCurrent()
                // 0x1001 -- This function starts the transaction. The transaction will be processed through multiple calls to the event OnEvent(...).

                weakSelf.theSelectedDevice?.start(weakSelf.mTransaction, completionHandler: { resultFlag in
                    weakSelf.outputOperationRuntime(op: MTUConstant.startTransactionOperationName, startTime: startTime)
                })
            }
        }
    }
    
    
    private func processAuthorizationRequest(_ data: IData) {
        guard !quickChipSwitch.isOn else { return }
        
        let length = (Int)(data.byteArray[0]) * 256 + (Int)(data.byteArray[1])
        
        let emvData = data.byteArray.subdata(in: 2..<(2 + length))
        
        let tlvs = (emvData as NSData).parseTLVDataWithNoLength()
        
        if tlvs!.count > 0 {
            let deviceSN = (tlvs?.getTLV("DFDF25"))!
            
            // let macKSN = tlvs?.getTLV("DFDF54")
            // let macEncryptionType = tlvs?.getTLV("DFDF55")
            
            // Q: What's the Authorization Response code means? 3030 is the "Approve"
            let ApprovedARC: [UInt8] = [0x8A, 0x02, 0x30, 0x30]
            let response: Data = buildNoMacAcquirerResponse(deviceSN: deviceSN, arc: ApprovedARC)
            
            backgroundManagementQueue.async { [weak self] in
                guard let weakSelf = self else { return }
                
                // In non-QuickChip mode
                // This function sends the Authorization Response Code (ARPC) blob to the device. The response data will be returned in the event OnEvent.
                // data -- Contains ARPC blob.
                weakSelf.theSelectedDevice?.sendAuthorization(IData(data: response))
            }
        }
    }
    
    // If non-QuickChip mode, the App/Host need to send the response to the `Device`
    private func buildNoMacAcquirerResponse(deviceSN: MTTLV, arc: [UInt8]) -> Data {
        var response: Data
        let responseObject: MTTLV = MTTLV()
        
        responseObject.tag = "FF74"
        let resTemp: MTTLV = MTTLV()
        resTemp.tag = "DFDF25"
        resTemp.value = deviceSN.value
        resTemp.length = resTemp.value.count / 2
        responseObject.value.append(TLVtoString(tlv: resTemp))
        responseObject.length = responseObject.value.count / 2
        
        let faObject: MTTLV = MTTLV()
        faObject.tag = "FA"
        faObject.value = ""
        
        let arpcObject: MTTLV = MTTLV()
        arpcObject.tag = "70"
        arpcObject.value = HexUtil.toHex(Data(arc))!
        arpcObject.length = arpcObject.value.count / 2
        
        faObject.value.append(TLVtoString(tlv: arpcObject))
        faObject.length = faObject.value.count / 2
        
        responseObject.value.append(TLVtoString(tlv: faObject))
        responseObject.length = responseObject.value.count / 2
        
        response = HexUtil.getBytesFromHexString(TLVtoString(tlv: responseObject))! as Data
        
        return response
    }
    
    private func TLVtoString(tlv: MTTLV) -> String {
        var result: String = ""
        result.append(tlv.tag)
        result.append(HexTLVLength(Length: tlv.length))
        result.append(tlv.value)
        return result
    }
    
    private func HexTLVLength(Length: Int) -> String {
        switch (Length) {
        case 0..<0x80:
            return String(format: "%02X", Length)
        case 80..<0x100:
            return String(format: "81%02X", Length)
        case 0x100..<0x10000:
            return String(format: "82%04X", Length)
        case 0x10000..<0x1000000:
            return String(format: "83%06X", Length)
        default:
            return String(format: "84%08X", Length)
        }
    }
    
    
    func configureButtonStates(isEnabled flag: Bool) {
        //btnStartTran.isEnabled = flag
        //btnManual.isEnabled = flag
        
        tiptaxSwitch.isOn = false
        
        if let deviceCapability = deviceCapability {
            signCaptureSwitch.isEnabled = deviceCapability.signature ? flag : false
            MSRSwitch.isEnabled = deviceCapability.paymentMethods.contains(.MSR)
            contactSwitch.isEnabled = deviceCapability.paymentMethods.contains(.contact)
            barcodeSwitch.isEnabled = deviceCapability.paymentMethods.contains(.barCode)
            
            
            tiptaxSwitch.isEnabled = deviceCapability.pinPad
            if !deviceCapability.pinPad {
                tiptaxSwitch.isOn = false
            }
             
        } else
        {
            signCaptureSwitch.isEnabled = false
        }
        
        //signCaptureSwitch.isEnabled = flag
        eventDrTranSwitch.isEnabled = flag
    }
    
    @objc func keyboardWillShowCallback(_ notification: NSNotification) {
        guard traitCollection.userInterfaceIdiom == .phone else { return }
        
        UIView.animate(withDuration: Constant.showOrHideKeyboardTimeDuration) {
            self.stackViewHideForShowingKeyboard?.isHidden = true
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillHideCallback(_ notification: NSNotification) {
        guard traitCollection.userInterfaceIdiom == .phone else { return }
        
        UIView.animate(withDuration: Constant.showOrHideKeyboardTimeDuration) {
            self.stackViewHideForShowingKeyboard?.isHidden = false
            self.view.layoutIfNeeded()
        }
    }
    
}

// MARK: - IConfigurationCallback

extension EMVViewController: IConfigurationCallback {
    
    func onResult(_ status: MTU_StatusCode, data: Data) {
        print("HomeVC onResult status = \(status), Data = \(data)")
    }
    
}
