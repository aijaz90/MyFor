//
//  SelectDeviceViewController.swift
//  MTUSDK_Sample
//
//  Created by Harry Zhang on 6/29/23.
//

import CoreBluetooth
import CoreData
import UIKit
import MTUSDK

protocol SelectDeviceViewControllerDelegate: AnyObject {
    func didSelectedReader(_ viewController: SelectDeviceViewController, device: IDevice?)
}

class SelectDeviceViewController: UIViewController {
    
    // MARK: - Public properties
    
    var currentSelectedDevice: IDevice?
    var currentSelectedDeviceAddress: String?
    var isSelectingDynaFlexIIGo = false
    
    var backgroundManagementQueue: DispatchQueue? = nil
    weak var delegate: SelectDeviceViewControllerDelegate?
    
    // MARK: - Private properties
    
    @IBOutlet private var segmentControlConnectionType: UISegmentedControl!
    @IBOutlet private var tableViewDeviceAddressList: UITableView!
    @IBOutlet private var addIpOrRescanButton: UIButton!
    @IBOutlet weak var noEAAccessoryPosterView: UIView!
    @IBOutlet private var autoReconnectButton: UISwitch!
    @IBOutlet private var logText: UITextView!
    
    static public var autoReconnectDevice: Bool = false
    
    private var foundDevices: [IDevice] = []
    
    private let mtusdkShared = CoreAPI.shared()
    
    // Model -- for WebSocket and BLE devices
    private var deviceAddressList = [String]()
    
    // for WebSocket only devices
    private var iPAddressList = [NSManagedObject]()
    
    private enum Constant {
        static let cellIdentificer = "CellIdentificer"
        static let emptyAddressList = "IP list is empty, Please click [Add IP] button to add new IP address."
        static let notIpAddress = "This is not an IP address, Please check and input again."
        static let duplicateIpAddress = "We have this IP address in the list already, Please add a unique one."
        static let placeholderIP = "wss(ws)://10.57.18.104"
        
        static let maximumWebSocketAddressCount = 9
    }
    
    // MARK: - VC Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        loadDevices()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { context in
            let keyWindow = UIApplication.shared.mainKeyWindow
            guard let statusBarFrame = keyWindow?.windowScene?.statusBarManager?.statusBarFrame else { return }
            UIApplication.shared.statusBarView?.frame = statusBarFrame
        }
    }
    
    func log(_ info : String) {
        DispatchQueue.main.async {
            self.logText.text = self.logText.text + "\n" + info
            let range = NSRange(location: self.logText.text.count, length: 0)
            self.logText.scrollRangeToVisible(range)
        }
    }
    
    // MARK: - Actions
    
    @IBAction func connectionTypeValueChanged(_ sender: UISegmentedControl) {
        UserDefaults.standard.set(sender.selectedSegmentIndex, forKey: UserDefaultsKey.currentSelectedConnectionType)
        UserDefaults.standard.synchronize()
        
        loadDevices()
    }
    
    @IBAction func autoReconnectSwitchChanged(_ sender: UISwitch) {
        SelectDeviceViewController.autoReconnectDevice = sender.isOn
    }
    
    @IBAction func addIPOrRescanTapped() {
        switch segmentControlConnectionType.selectedSegmentIndex {
        case DeviceConnectionType.kLightning:
            break
        case DeviceConnectionType.kWebSocket:
            addNewIpAddress()
            break
        case DeviceConnectionType.kBLE:
            if !hasBluetoothPermission {
                requestBluetoothPermission()
            }
            
            mtusdkShared.stopScanningForPeripherals()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.loadBLEDevices()
            }
            break
        case DeviceConnectionType.kMQTT:
            // scan for MQTT
            mtusdkShared.stopDiscover()
            loadMQTTDevices()
        default:
            break
        }
    }
    
}

// MARK: - UITableViewDataSource

extension SelectDeviceViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return deviceAddressList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constant.cellIdentificer, for: indexPath)
        let devList = deviceAddressList
        if indexPath.row >= devList.count {
            cell.textLabel?.text = ""
        } else {
            cell.textLabel?.text = devList[indexPath.row]
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch segmentControlConnectionType.selectedSegmentIndex {
        case DeviceConnectionType.kWebSocket:
            return true
        default:
            return false
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch segmentControlConnectionType.selectedSegmentIndex {
        case DeviceConnectionType.kWebSocket:
            if editingStyle == .delete {
                tableView.beginUpdates()
                
                deleteIpAddressFromCoreDataWithRow(at: indexPath.row)
                deviceAddressList.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
                
                tableView.endUpdates()
            }
        default:
            break
        }
    }
    
}

// MARK: - UITableViewDelegate

extension SelectDeviceViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        currentSelectedDeviceAddress = deviceAddressList[indexPath.row]
        isSelectingDynaFlexIIGo = false
        
        switch segmentControlConnectionType.selectedSegmentIndex {
        case DeviceConnectionType.kLightning:
            isSelectingDynaFlexIIGo = true
            //mtusdkShared.turnEAAccessoryConnectionNotificationsOff()
            currentSelectedDevice = (foundDevices.count > indexPath.row) ? foundDevices[indexPath.row] : nil
            
        case DeviceConnectionType.kWebSocket:
            /*backgroundManagementQueue?.async { [weak self] in
                guard let weakSelf = self else { return }
                weakSelf.currentSelectedDevice = weakSelf.createWebSocketDevice()
            } */
            currentSelectedDevice = createWebSocketDevice()
        case DeviceConnectionType.kBLE:
            isSelectingDynaFlexIIGo = true
            mtusdkShared.stopScanningForPeripherals()
            currentSelectedDevice = (foundDevices.count > indexPath.row) ? foundDevices[indexPath.row] : nil
        case DeviceConnectionType.kMQTT:
            // for MQTT
            mtusdkShared.stopDiscover()
            currentSelectedDevice = (foundDevices.count > indexPath.row) ? foundDevices[indexPath.row] : nil
        default:
            currentSelectedDevice = nil
        }
        
        // Use delegate instead of segue
        //performSegue(withIdentifier: Segue.unwindToOpenDeviceVCSegue, sender: nil)
        delegate?.didSelectedReader(self, device: currentSelectedDevice)
    }
    
}


// MARK: - Private helpers

private extension SelectDeviceViewController {
    
    var hasBluetoothPermission: Bool {
        if #available(iOS 13.1, *) {
            return CBCentralManager.authorization == .allowedAlways
        }
        return true
    }
    
    func requestBluetoothPermission() {
        guard !hasBluetoothPermission else { return }
        
        let alert = UIAlertController(
            title: "Enable Bluetooth",
            message: "Go to Settings and Enable Bluetooth to scan BLE card Readers (You may have already enabled it). If you are the first time enable it, please click the Rescan button to find Readers.",
            preferredStyle: .alert
        )
        
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (_) -> Void in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            if UIApplication.shared.canOpenURL(settingsURL) { UIApplication.shared.open(settingsURL) }
        }
        
        let cancelAction = UIAlertAction(title: "OK", style: .default)
        
        alert.addAction(settingsAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    func setupUI() {
        navigationController?.navigationBar.backgroundColor = .darkGray
        navigationController?.navigationBar.tintColor = .white
        segmentControlConnectionType.selectedSegmentTintColor = .systemBlue
        segmentControlConnectionType.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : UIColor.white], for: .selected)
        
        //navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(closeSelectDeviceVC))
        
        let previousConnectionType = UserDefaults.standard.integer(forKey: UserDefaultsKey.currentSelectedConnectionType)
        segmentControlConnectionType.selectedSegmentIndex = previousConnectionType
        
        tableViewDeviceAddressList.dataSource = self
        tableViewDeviceAddressList.delegate = self
        tableViewDeviceAddressList.register(UITableViewCell.self, forCellReuseIdentifier: Constant.cellIdentificer)
        
        let settingsIcon = UIImage(named: "settings")
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: settingsIcon, style: .plain, target: self, action: #selector(navigateToSettingsView))
        if #available(iOS 16.0, *) {
            navigationItem.rightBarButtonItem?.isHidden = true
        } else {
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
        
        autoReconnectButton.isOn = SelectDeviceViewController.autoReconnectDevice
    }
    
    @objc func navigateToSettingsView() {
        if ( segmentControlConnectionType.selectedSegmentIndex == DeviceConnectionType.kMQTT) {
            settingMQTT()
        }
    }
    
    func settingMQTT() {
        print("MQTT settings")
        
        let storyboard = UIStoryboard(name: "MQTTSettingsView", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MQTTSettingsView")
        
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func refreshUI(connectionType: MTU_ConnectionType) {
        DispatchQueue.main.async {
            if connectionType == MTU_ConnectionType_EXTERNAL_ACCESSORY && self.deviceAddressList.isEmpty {
                self.noEAAccessoryPosterView.isHidden = false
            } else {
                self.noEAAccessoryPosterView.isHidden = true
            }
            
            self.tableViewDeviceAddressList.reloadData()
        }
    }
    
    func createWebSocketDevice() -> IDevice? {
        guard let currentSelectedDeviceAddress = currentSelectedDeviceAddress else { return nil }
        
        let clientCert = Bundle.main.url(forResource: "client", withExtension: "p12")!
        let certData = try! Data(contentsOf: clientCert)
        
        if currentSelectedDeviceAddress.protocolCheck("wss") {
            return CoreAPI.createDevice(
                MTU_DeviceType_MMS,
                connection: MTU_ConnectionType_WEBSOCKET,
                address: currentSelectedDeviceAddress,
                model:"DynaFlex",
                name: currentSelectedDeviceAddress,
                serial:"B123456",
                cert: CertificateInfo(format: "PKCS12", data: certData, password: "password")
            )
        }
        else if currentSelectedDeviceAddress.protocolCheck("ws") {
            return CoreAPI.createDevice(
                MTU_DeviceType_MMS,
                connection: MTU_ConnectionType_WEBSOCKET,
                address: currentSelectedDeviceAddress,
                model:"DynaFlex",
                name: currentSelectedDeviceAddress,
                serial:"B123456"
            )
        }
        
        return nil
    }
    
    @objc func closeSelectDeviceVC() {
        //performSegue(withIdentifier: Segue.unwindToOpenDeviceVCSegue, sender: nil)
        navigationController?.popViewController(animated: true)
    }
    
    func loadDevices() {
        // First, stop scan (if need)
        mtusdkShared.stopDiscover()
        
        switch segmentControlConnectionType.selectedSegmentIndex {
        case DeviceConnectionType.kLightning:
            addIpOrRescanButton.isHidden = true
            autoReconnectButton.isEnabled = true
            loadEADevice()
            
        case DeviceConnectionType.kWebSocket:
            autoReconnectButton.isEnabled = false
            noEAAccessoryPosterView.isHidden = true
            addIpOrRescanButton.isHidden = false
            addIpOrRescanButton.setTitle("Add IP", for: .normal)
            loadWebSocketDevices()
        case DeviceConnectionType.kBLE:
            if !hasBluetoothPermission {
                requestBluetoothPermission()
            }
            autoReconnectButton.isEnabled = true
            noEAAccessoryPosterView.isHidden = true
            addIpOrRescanButton.isHidden = false
            addIpOrRescanButton.setTitle("Rescan", for: .normal)
            loadBLEDevices()
        case DeviceConnectionType.kMQTT:
            // for MQTT
            noEAAccessoryPosterView.isHidden = true
            autoReconnectButton.isEnabled = false
            addIpOrRescanButton.isHidden = false
            addIpOrRescanButton.setTitle("Rescan", for: .normal)
            loadMQTTDevices()
        default:
            break
        }
    }
    
    func loadWebSocketDevices() {
        cleanDevices()
        
        fetchWebSocketDevicesFromCoreData()
        
        if !iPAddressList.isEmpty {
            for i in 0..<iPAddressList.count {
                if let iPAddress = iPAddressList[i].value(forKey: CoreDataEntityAttributeKey.ipAddress) as? String {
                    deviceAddressList.append(iPAddress)
                }
            }
            
            tableViewDeviceAddressList.reloadData()
        }
        else {
            tableViewDeviceAddressList.reloadData()
            warningAlert(Constant.emptyAddressList)
        }
    }
    
    func cleanDevices() {
        
        if #available(iOS 16.0, *) {
            navigationItem.rightBarButtonItem?.isHidden = true
        } else {
            navigationItem.rightBarButtonItem?.isEnabled = false
        }
        
        deviceAddressList.removeAll()
        tableViewDeviceAddressList.reloadData()
        foundDevices = []
    }
    
    func loadBLEDevices() {
        cleanDevices()
        
        log("Start discovering Bluetooth LE ...")
        
        mtusdkShared.setDeviceType(MTU_DeviceType_MMS, andConnectionType: MTU_ConnectionType_BLUETOOTH_LE_EMV)
        mtusdkShared.mtuSDKDelegate = self
        mtusdkShared.startScanningForPeripherals()
    }
    
    func loadEADevice() {
        let supportedEAProtocolStrings = getSupportedEAProtocolStrings()
        guard !supportedEAProtocolStrings.isEmpty else {
            warningAlert(MTUConstant.noEAProtocolStrings)
            return
        }
        
        cleanDevices()
        
        let alert = UIAlertController(
            title: MTUConstant.selectEAProtocolStringTitle,
            message: MTUConstant.selectEAProtocolStringMsg,
            preferredStyle: .actionSheet
        )
        
        for protocolString in supportedEAProtocolStrings {
            let protocolStringAction = UIAlertAction(title: protocolString, style: .default) { _ in
                self.loadLightningDevice(eaProtocolString: protocolString)
            }
            alert.addAction(protocolStringAction)
        }
        
        let cancelAction = UIAlertAction(title: MTUConstant.cancelButtonTitle, style: .cancel)
        alert.addAction(cancelAction)
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.segmentControlConnectionType
        }
        
        log("Pick accessory type ...")
        
        present(alert, animated: true)
    }
    
    func loadMQTTDevices() {
        cleanDevices()
        
        if #available(iOS 16.0, *) {
            navigationItem.rightBarButtonItem?.isHidden = false
        } else {
            navigationItem.rightBarButtonItem?.isEnabled = true
        }
        
        MQTTSettings.shared.setup()
        
        log("Start discovering MQTT ...")
        
        mtusdkShared.setDeviceType(MTU_DeviceType_MMS, andConnectionType: MTU_ConnectionType_MQTT)
        mtusdkShared.mtuSDKDelegate = self
        mtusdkShared.startDiscover()
    }
    
    func loadLightningDevice(eaProtocolString: String = MTUConstant.dynaFlex2GoProtocolString) {
        //cleanDevices()
        
        mtusdkShared.setDeviceType(MTU_DeviceType_MMS, andConnectionType: MTU_ConnectionType_EXTERNAL_ACCESSORY)
        mtusdkShared.setupEADeviceProtocolString(eaProtocolString)
        /*
#if DYNAFLEX2GO
        mtusdkShared.setupEADeviceProtocolString(MTUConstant.dynaFlex2GoProtocolString)
#elseif DYNAPROX
        mtusdkShared.setupEADeviceProtocolString(MTUConstant.dynaproxProtocolString)
#else
        mtusdkShared.setupEADeviceProtocolString(MTUConstant.dynaFlex2GoProtocolString) // DF2GO By default
#endif
        */
        log("Start discovering accesory ...")
        
        mtusdkShared.mtuSDKDelegate = self
        mtusdkShared.turnEAAccessoryConnectionNotificationsOn()
        mtusdkShared.showConnectedEAAccessoryIfAny()
    }
    
    // Add a WebSocket IP address
    func addNewIpAddress() {
        var inputTF = UITextField()
        
        let alert = UIAlertController(title: "Add New IP", message: "", preferredStyle: .alert)
        
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            guard let inputIP = inputTF.text else { return }
            
            if inputIP.protocolCheck("ws") || inputIP.protocolCheck("wss") {
                // why only keep 9 IP address at most
                if self.deviceAddressList.count > Constant.maximumWebSocketAddressCount {
                    self.deleteIPFromCoreData()
                    self.deviceAddressList.removeFirst()
                }
                
                self.addIpAddressToCoreData(inputIP)
                
                self.loadWebSocketDevices()
            }
            else {
                self.warningAlert(Constant.notIpAddress)
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in }
        
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        
        alert.addTextField { (textField) in
            inputTF = textField
            inputTF.placeholder = Constant.placeholderIP
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    func addIpAddressToCoreData(_ iPAddress: String) {
        guard !isDuplicateIpAddress(iPAddress) else {
            warningAlert(Constant.duplicateIpAddress)
            return
        }
        
        guard let managedContext = AppDelegate.managedContext else { return }
        
        let entity = NSEntityDescription.entity(forEntityName: "IPLIST", in: managedContext)!
        let managedObject = NSManagedObject(entity: entity, insertInto: managedContext)
        managedObject.setValue(iPAddress, forKey: CoreDataEntityAttributeKey.ipAddress)
        
        if managedContext.hasChanges {
            do {
                try managedContext.save()
                iPAddressList.append(managedObject)
            } catch let error as NSError {
                print("Could not save the IP address: \(error.localizedDescription)")
            }
        }
    }
    
    // Delete the first IP address by default
    func deleteIPFromCoreData() {
        guard let managedContext = AppDelegate.managedContext else { return }
        
        managedContext.delete(iPAddressList[0])
        
        if managedContext.hasChanges {
            do {
                try managedContext.save()
                iPAddressList.removeFirst()
            } catch let error as NSError {
                print("Could not save: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteIpAddressFromCoreDataWithRow(at row: Int) {
        guard let managedContext = AppDelegate.managedContext else { return }
        
        for i in 0..<iPAddressList.count {
            if let iPAddress = iPAddressList[i].value(forKey: CoreDataEntityAttributeKey.ipAddress) as? String,
               iPAddress == deviceAddressList[row] {
                managedContext.delete(iPAddressList[i])
                break
            }
        }
        
        if managedContext.hasChanges {
            do {
                try managedContext.save()
                iPAddressList.remove(at: row)
            }
            catch let error as NSError {
                print("Could not save: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchWebSocketDevicesFromCoreData() {
        guard let managedContext = AppDelegate.managedContext else { return }
        
        do {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "IPLIST")
            iPAddressList = try managedContext.fetch(fetchRequest)
        } catch let error as NSError {
            print("Could not fetch: \(error.localizedDescription)")
        }
    }
    
    func isDuplicateIpAddress(_ iPAddress: String) -> Bool {
        for i in 0..<iPAddressList.count {
            if let value = iPAddressList[i].value(forKey: "iPAddress") as? String {
                if value == iPAddress { return true }
            }
        }
        return false
    }
    
    func getSupportedEAProtocolStrings() -> [String] {
        var supportedProtocolStrings = [String]()
        
        if let infoDict = Bundle.main.infoDictionary,
           let protocolStrings = infoDict["UISupportedExternalAccessoryProtocols"] as? [String] {
            supportedProtocolStrings = protocolStrings
        }
        
        return supportedProtocolStrings
    }
    
}

// MARK: - MTUSDKDelegate

extension SelectDeviceViewController: MTUSDKDelegate {
    
    func onDeviceList(_ instance: Any, with connectionType: MTU_ConnectionType, deviceList: [IDevice]) {
        self.debugPrintLog("App - The connectionType: \(connectionType), and found [IDevice] array: \(deviceList)")
        
        
            deviceAddressList = []
            for aDevice in deviceList {
                if (connectionType == MTU_ConnectionType_EXTERNAL_ACCESSORY) {
                    if let deviceInfo = aDevice.getInfo() {
                        deviceAddressList.append(deviceInfo.deviceName + " - " + deviceInfo.deviceSerialNumber)
                    } else {
                        deviceAddressList.append(aDevice.deviceName)
                    }
                } else {
                    deviceAddressList.append(aDevice.deviceName)
                }
            }
            foundDevices = deviceList
            
            refreshUI(connectionType: connectionType)
    }
    
    func didSystemUpdate(_ state : SystemState) {
        let stateString : [SystemState : String] = [
            .unknown:"Initial or undefined state",
            .bluetoothLEResetting: "Bluetooth is currently resetting",
            .bluetoothLEUnsupported : "Device doesn't support Bluetooth LE",
            .bluetoothLEUnauthorized  : "App lacks Bluetooth permissions",
            .bluetoothLEPoweredOff : "Bluetooth is turned off",
            .bluetoothLEPoweredOn  : "Bluetooth is ready to use",
            .networkOff : "Network connectivity is unavailable",
            .networkOn : "Network connectivity is available",
            .serverNotReachable : "Cannot connect to remote server",
            .rejectedByServer : "Server rejected the connection",
            .tlsAuthenticationFailed  : "TLS/SSL authentication failed",
            .protocolError  : "Protocol-level communication error",
            .serverConnected  : "Successfully connected to server"
        ]
        if let info = stateString[state] {
            log("System State : \(info)")
        }  else {
            log ("Invalid system state")
        }
    }
}
