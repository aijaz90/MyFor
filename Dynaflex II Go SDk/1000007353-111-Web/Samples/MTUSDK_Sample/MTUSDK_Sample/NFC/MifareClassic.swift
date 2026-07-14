//
//  MifareClassic.swift
//  tDynamoScanAndConnect
//
//  Created by Yong Guo on 3/13/24.
//

import Foundation

public enum MifareClassicKeyType {
    case A
    case B
    
    public func toByte ()-> UInt8 {
        switch(self) {
        case .A:
            return 0
        case .B:
            return 1
        }
    }
}

open class MifareClassic {
    let READ = "30"
    let WRITE = "A0"
    
    /// send a NFC command and get the response. MifareClassic class need this to contruct.
    ///  @param command Mifare classic command to send
    ///  @param lastCommand Indicate it is a last command to send. Device will beep and close the communication to tag card once it is last command.
    ///  @returns NFC response
    let sendNfc : ((_ command : String, _ lastCommand : Bool)async throws->(String))
    var userSize : UInt8 = 0
    
    init(sendNfc: @escaping (_: String, _: Bool)async throws -> String) {
        self.sendNfc = sendNfc
    }
    
    func checkKey(_ key :[UInt8]) throws -> Void {
        if (key.count != 6) {
            throw MTNFCError(Message: "Invalid key size")
        }
    }
    
    func checkBlockData( blockSize : UInt8, data : [UInt8]) throws -> Void {
        if blockSize != UInt8(data.count / 16) {
            throw MTNFCError(Message: "Invalid data size to write")
        }
    }
    
    public func read(sector : UInt8, starBlock : UInt8, endBlock : UInt8, keyType : MifareClassicKeyType, key : [UInt8], lastCommand : Bool = false) async throws -> [UInt8] {
        
        try checkKey(key)
        
        let readCommand = READ + String(format:"%02X%02X%02X%02X", sector,starBlock,endBlock,keyType.toByte()) + HexUtil.toHex(key)
        
        let vhex = try await sendNfc(readCommand, lastCommand)
        
        return vhex.byteArrayFromHexString
    }
    
    public func write(sector : UInt8, starBlock : UInt8, endBlock : UInt8, keyType : MifareClassicKeyType, key : [UInt8], value : [UInt8], lastCommand : Bool = false) async throws -> Bool {
        
        try checkKey(key)
        
        try checkBlockData(blockSize: endBlock - starBlock + 1, data: value)
        
        let writeCommand = WRITE + String(format:"%02X%02X%02X%02X", sector,starBlock,endBlock,keyType.toByte()) + HexUtil.toHex(key) + HexUtil.toHex(value)
        
        let _ = try await sendNfc(writeCommand, lastCommand)
        
        return true
    }
}
