//
//  MTUSDK_SampleTests.swift
//  MTUSDK_SampleTests
//
//  Created by Yong Guo on 11/19/21.
//

import XCTest
import MTUSDK
//@testable import MTUSDK_Sample

class MTUSDK_SampleTests: XCTestCase, IEventSubscriber {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func onEvent(_ eventType: MTU_EventType, data: IData!) {
        print(eventType)
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    
    func testMSRTransaction() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        
        let device = CoreAPI.createDevice(MTU_DeviceType_MMS, connection:MTU_ConnectionType_WEBSOCKET, //address:@"ws://192.168.0.105:8889/Device/USB/0/"
                                        address:"ws://192.168.0.105:8889/Device/USB/0/",
                                          model:"DynaFlex", name:"10.57.10.195", serial:"B123456");
        
//        device.eventDelegate = self;
        
        let info = device!.getConnectionInfo()
        let devCtrl = device!.getControl()
        var success = devCtrl!.open()
        
        print("open device result: \(success)")
        
        let tran : ITransaction = ITransaction.amount("1.0", timeout: 30, for: [.MSR])
        success = device!.start(tran)
        
        sleep(10);
        
        devCtrl!.close()
    }

    func testGetASN1Notation()
    {
        let cfg1 = ConfigurationInfo.initWithASN1Oid("1.2.1.1.2.1", hexValue: "01")
        XCTAssert(cfg1?.configType == 1)
        if let oidAndValue = cfg1?.oidAndValue {
            print(oidAndValue)
        }
        
        let device = CoreAPI.createDevice(MTU_DeviceType_MMS, connection:MTU_ConnectionType_WEBSOCKET, //address:@"ws://192.168.0.105:8889/Device/USB/0/"
                                        address:"ws://192.168.0.105:8889/Device/USB/0/",
                                          model:"DynaFlex", name:"10.57.10.195", serial:"B123456");
        
//        device.eventDelegate = self;
        
        let cfg = device!.getConfiguration()!
        let data = IData(hex: "e208e206e304e102cc00")
        cfg.getConfigInfo(1, data: data.byteArray);
        
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}


