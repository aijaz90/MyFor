//
//  IWrapperDevice.swift
//  MTUSDK_MacSample
//
//  Created by Yong Guo on 5/19/22.
//

import Foundation
import MTUSDK

open class IWrapperDeviceConfiguration: NSObject, IConfigurationCallback {
    
    let device: IDevice
    let configuration: IDeviceConfiguration?
    
    var progress: (_ Progress: Int32) -> Void = { p in }
    var result: (_ status: MTU_StatusCode, _ data: Data) -> Void = { s, d in }
    var caculateMac: ((_ macType: UInt8, _ data: Data) -> IResult) = { macType, data in
        var r = IResult()
        r.status = MTU_StatusCode_Unavailable
        return r
    }
    
    init (_ dev: IDevice) {
        self.device = dev
        self.configuration = device.getConfiguration()
        super.init()
    }
    
    // MARK: - IConfigurationCallback
    
    public func onProgress(_ progressValue: Int32) {
        progress(progressValue)
    }
    
    // Completed
    public func onResult(_ status: MTU_StatusCode, data: Data) {
        result(status, data)
        
        // reset callback
        progress = {p in}
        result = {s,d in}
        caculateMac = {macType,data in
            let r = IResult()
            r.status = MTU_StatusCode_Unavailable
            return r
        }
    }
    
    public func onCalculateMAC(_ macType: UInt8, data: Data) -> IResult {
        return caculateMac(macType,data)
    }
    
    // MARK: - Public APIs
    
    func sendFile(
        _ fileID: Data,
        _ data: Data,
        _ progress: @escaping (_ Progress: Int32) -> Void,
        _ result: @escaping (_ status: MTU_StatusCode, _ data: Data) -> Void
    ) -> Int32 {
        guard let deviceConfiguration = self.configuration else { return -1 }
        self.progress = progress
        self.result = result
        return deviceConfiguration.sendFile(fileID, data: data, callback: self)
    }
    
    func sendFile(
        _ fileHexID: String,
        _ data: Data,
        _ progress: @escaping (_ Progress: Int32) -> Void,
        _ result: @escaping (_ status: MTU_StatusCode, _ data: Data) -> Void
    ) -> Int32 {
        guard let deviceConfiguration = self.configuration else { return -1 }
        self.progress = progress
        self.result = result
        return deviceConfiguration.sendFile(Data(hexString: fileHexID)!, data: data, callback: self)
    }
    
    func updateFirmware(
        _ firmwareType: ushort,
        _ data: Data,
        _ progress: @escaping (_ Progress: Int32) -> Void,
        _ result: @escaping (_ status: MTU_StatusCode, _ data: Data) -> Void
    ) -> Int32 {
        guard let deviceConfiguration = self.configuration else { return -1 }
        self.progress = progress
        self.result = result
        return deviceConfiguration.updateFirmware(firmwareType, data: data, callback: self)
    }
    
    func injectkey(
        _ token: Data,
        _ result: @escaping (_ status: MTU_StatusCode, _ data: Data) -> Void
    ) -> Int32 {
        guard let deviceConfiguration = self.configuration else { return -1 }
        
        self.result = result
        
        // Returns 0 if the asynchronous update operation started. Otherwise, returns a non 0 value.
        let retValue = deviceConfiguration.updateKeyInfo(0, data: token, callback: self)
        if retValue == 0 {
            result(MTU_StatusCode_Success, token)
        } else {
            result(MTU_StatusCode_Error, Data())
        }
        return retValue
    }
    
    func getChallengeToken(_ hexId: String) -> String {
        guard let deviceConfiguration = self.configuration else { return "" }
        
        // TODO: Put this call in a background thread when use it
        // Thread running at QOS_CLASS_USER_INTERACTIVE waiting on a lower QoS thread running at QOS_CLASS_DEFAULT. Investigate ways to avoid priority inversions

        // This function retrieves a challenge token from the device. A challenge token consists of a random nonce or timestamp. A challenge token must be used within the time allowed by the device (generally 5 minutes) after issued. Only one token can be active at a time. Attempts to use a token for requests other than the one specified will cause the token to be revoked/erased.
        let token = deviceConfiguration.getChallengeToken(Data(hexString: hexId)!)
        return token.hexEncodedString()
    }
    
}


open class IWrapperDeviceControl {
    
    let deviceCtrl: IDeviceControl?
    
    init(_ dev: IDevice) {
        deviceCtrl = dev.getControl()
    }
    
    func sendCommandSync(_ command: String) -> String {
        guard let deviceControl = self.deviceCtrl else { return "" }
        
        let response = deviceControl.sendSync(IData(hex: command))
        if response.status == MTU_StatusCode_Success {
            return response.data.byteArray.hexEncodedString()
        }
        return ""
    }
    
    func reset() -> Bool {
        guard let deviceControl = self.deviceCtrl else { return false }
        return deviceControl.deviceReset()
    }
}


open class IWrapperDevice: NSObject, IEventSubscriber {
    
    let device: IDevice
    let configuration: IWrapperDeviceConfiguration
    var event: (_ eventType: MTU_EventType, _ data: IData) -> Void = { eventType, data in }
    
    var resetBarCodeDataHandler: Bool = true
    var barcodeDataArrived: (_ barcodeData: BarCodeData) -> Void = { b in }
    
    // MARK: - Life cycle
    
    init(_ dev: IDevice) {
        device = dev
        configuration = IWrapperDeviceConfiguration(dev)
        super.init()
        
        device.subscribeAll(self)
    }
    
    deinit {
        device.unsubscribeAll(self)
    }
    
    // MARK: - Public APIs
    
    var isConnected: Bool {
        return device.getConnectionState() == MTU_ConnectionState_Connected
    }
    
    var serialNumber: String {
        guard let deviceConfiguration = configuration.configuration else { return "" }
        // TODO: Put this call in a background thread when use it
        // Thread running at QOS_CLASS_USER_INTERACTIVE waiting on a lower QoS thread running at QOS_CLASS_DEFAULT. Investigate ways to avoid priority inversions
        return deviceConfiguration.getDeviceInfo(MTU_InfoType_DeviceSerialNumber)
    }
    
    func scanBarCode(
        _ timeout: UInt8,
        _ Encrypt: Bool = true,
        _ bcHandler: @escaping (_ barcodeData: BarCodeData) -> Void
    ) -> Bool {
        resetBarCodeDataHandler = timeout != 0
        barcodeDataArrived = bcHandler
        if let deviceControl = self.device.getControl() {
            return deviceControl.startBarCodeReader(timeout, mode: Encrypt ? 1 : 0)
        }
        return false
    }
    
    
    // MARK: - IEventSubscriber
    
    public func onEvent(
        _ eventType: MTU_EventType,
        data: IData!
    ) {
        event(eventType, data)
        
        if (eventType == MTU_EventType_BarCodeData) {
            let bcdata = BarCodeDataBuilder.getBarCodeData(MTU_DeviceType_MMS, data: data.byteArray)
            barcodeDataArrived(bcdata!)
            if resetBarCodeDataHandler {
                barcodeDataArrived = { b in }
            }
        }
    }
    
}
