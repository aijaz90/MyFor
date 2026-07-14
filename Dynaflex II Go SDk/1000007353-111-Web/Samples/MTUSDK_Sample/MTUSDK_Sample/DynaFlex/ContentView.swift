//
//  ContentView.swift
//  Shared
//
//  Created by Yong Guo on 5/6/22.
//

import SwiftUI
import MTUSDK

// This code is not using right now
/*
struct ContentView: View {
    @State
    var device : IWrapperDevice?
    
    @State
    var presentFilePicker : Bool = false
    @State
    var pickExcelFile : Bool = false
    @State
    var fileData : Data = Data()
    @State
    var selectKeys : [KeyInfo]?
    @State
    var selectKeyPresented : Bool = false

    
    @AppStorage ("WebSocketAddress")
    var webSocketAddress : String = ""
    
    @State
    var log : String = ""
    
    let rs3 : RS3Client = RS3Client("DEV", "Password#12345", "UQ48014613")
    
    var body: some View {
        
        VStack {
            Text("DynaFlex")
                .padding()
            
            HStack {
                Text("Device address - ws://")
                TextField("Web Socket (IP): ", text: $webSocketAddress).border(.blue)
            }
                
            Button("Get Firmware Hash") {
                /*
                let devices = CoreAPI.getDeviceList(MTU_DeviceType_MMS)
                
                if !devices.isEmpty {
                    self.device = IWrapperDevice((devices.first as? IDevice)!)
                }
                 */
                
                _ = openDevice() {
                    let fwhash = self.device?.device.getConfiguration().getDeviceInfo(MTU_InfoType_FirmwareHash)
                    
                    log += "FW Hash : " + fwhash! + "\n"
                }
            }
            
            Button ("Update Configuration File (EXCEL)") {
                pickExcelFile = true
            }
            
            Button("Update Firmware") {
                presentFilePicker = true
            }
            
            Button("Update Key") {
                rs3.getKey(){ keys in
                    guard (keys != nil) else {
                        log ("Cannot get key from RS3")
                        return
                    }
                    selectKeys = keys
                    selectKeyPresented = true
                }
            }
        }
        #if os(iOS)
        .actionSheet(isPresented: $selectKeyPresented){
            var buttons = selectKeys!.enumerated().map { i, option in
                Alert.Button.destructive(Text(option.keyName!), action: { self.injectKey(option)} )
            }
            buttons.append(.cancel())
            return ActionSheet(title: Text("Inject Key"), message: Text("Click a button with Key ID or Cancel this action"), buttons:
                buttons
            )
        }
        #else
        .sheet(isPresented: $selectKeyPresented){
            KeySelectionView(keys: $selectKeys, action: { key in
                injectKey(key)
                selectKeyPresented = false
            }, cancel: { selectKeyPresented = false })
            /*
            VStack {
                ForEach(selectKeys!, id:\.id) {key in
                    Button(key.keyName!) {
                        self.injectKey(key)
                    }
                }
                Button("Cancel") {
                    selectKeyPresented = false
                }
            }
             */
        }
        #endif
        .fileImporter(isPresented: $presentFilePicker, allowedContentTypes: [.data]) {result in
            do
            {
                let url = try result.get()
                try readFile(url){filename,data in
                    _ = openDevice() {
                        _ = self.device?.configuration.updateFirmware(1, data, {p in log += "progress \(p)\n"}, {s,d in log += "status : \(s) \n"})
                    }
                }
            }
            catch
            {
                print("Unexpected error: \(error).")
            }
        }
        .fileImporter(isPresented: $pickExcelFile, allowedContentTypes: [.data]) {result in
            do
            {
                let url = try result.get()
                try readFile(url){filename,data in
                    updateCfgFile(filename, data)
                }
            }
            catch
            {
                print("Unexpected error: \(error).")
            }
        }
        
        TextEditor(text: $log).border(.blue)
            .multilineTextAlignment(.leading)
    }
    
    func log(_ info:String) {
        log += info + "\n"
    }
    
    func readFile(_ url : URL, _ contentHandler : @escaping(_ filename : String, _ data : Data)->()) throws {

            let filename = url.lastPathComponent
            if url.startAccessingSecurityScopedResource() {
                let data = try Data(contentsOf: url)
                contentHandler(filename, data)
            }

            url.stopAccessingSecurityScopedResource()
    }
    
    func updateCfgFile(_ filename : String, _ data : Data) {
        rs3.Transform(data) {bin in
            guard bin != nil else {
                return
            }
            
            _ = openDevice() {
                for bi in bin! {
                    let fileid = bi.configId
                    let filedata = Data.init(base64Encoded: bi.config!)
                    
                    // use sendFile
                    let success = self.device?.configuration.sendFile(fileid!, filedata!, {p in log += "progress \(p)\n"}, {s,d in log += "status : \(s) \n"})
                    
                    print("send file \(bi.configId) - \(success)")
                }
            }
        }
    }
    
    func injectKey(_ key : KeyInfo)
    {
        log ("select key \(key.keyName)")
        _ = openDevice {
            self.device?.configuration
        }
    }

    func openDevice(close:Bool = true, _ openHandler : ()->()) -> Bool{
        var result : Bool = false
        if self.device == nil || !self.device!.isConnected {
            let wsdevice = CoreAPI.createDevice(MTU_DeviceType_MMS, connection: MTU_ConnectionType_WEBSOCKET, address: "ws://" + webSocketAddress, model: "DynaFlex", name: webSocketAddress, serial: "B62CA86")
            self.device = IWrapperDevice(wsdevice)
            self.device?.event = {t, d in
                onEvent(t, d)
            }
        }
        
        if !device!.isConnected {
            self.device?.device.getControl().open()
        }
        
        if device!.isConnected {
            result = true
            openHandler()
        }

        if (close) {
            self.device?.device.getControl().close()
        }
        
        return result
    }

    func onEvent(_ eventType : MTU_EventType, _ data : IData) {
        switch eventType {
        case MTU_EventType_ConnectionState:
            log( "[Connection State] - \(data.stringValue)" )
        case MTU_EventType_OperationStatus:
            log( "[Operation Status] - \(data.stringValue)" )
        case MTU_EventType_FeatureStatus:
            log ( "[Feature Status] - \(data.stringValue)" )
        case MTU_EventType_DeviceResponse :
            log ("[Device Response] - \(data.byteArray.hexEncodedString())")
        case MTU_EventType_DisplayMessage:
            log ("[Display] - \(data.stringValue)")
        default:
            log ( "event type : \(eventType)\ndata : \(data.byteArray.hexEncodedString())" )
        }

    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(device: nil)
    }
}
*/
