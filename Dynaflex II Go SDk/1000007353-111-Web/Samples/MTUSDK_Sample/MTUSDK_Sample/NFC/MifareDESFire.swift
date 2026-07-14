//
//  MifareDESFire.swift
//  iDynamo6Swift
//
//  Created by Yong Guo on 4/12/24.
//

import Foundation


open class MifareDESFire{
    let GET_VERSION = "60"
    let MORE_DATA = "AF"
    
    /// send a NFC command and get the response. MifareClassic class need this to contruct.
    ///  @param command Mifare classic command to send
    ///  @param lastCommand Indicate it is a last command to send. Device will beep and close the communication to tag card once it is last command.
    ///  @returns NFC response
    let sendNfc : ((_ command : String, _ lastCommand : Bool)async throws->(String))
    
    init(sendNfc: @escaping (_: String, _: Bool)async throws -> String) {
        self.sendNfc = sendNfc
    }
    
    func sendAPDU (_ apdu : APDU, lastCommand : Bool = false) async throws -> RAPDU {
        let cmd = apdu.Bytes
        let response = try await sendNfc(HexUtil.toHex(cmd), lastCommand)
        let rapdu = RAPDU(Raw: response.byteArrayFromHexString)
        return rapdu
    }
    
    func nativeToApdu (_ command : String) -> APDU {
        let cmdAndData = command.byteArrayFromHexString
        let INS = cmdAndData[0]
        let Data = [UInt8](cmdAndData[1...])
        return APDU(CLA: 0x90, INS: INS, Data: Data, Le: 256)
    }
    
    func sendNativeCommand (_ command : String) async throws -> (UInt8, String)
    {
        var cmd = nativeToApdu(command)
        var moreCommand = true
        var response = ""
        var resultCode : UInt8 = 0
        while moreCommand {
            let rapdu = try await sendAPDU(cmd)
            if rapdu.SW1 == 0x91 && rapdu.SW2 == 0xAF {
                cmd = APDU(CLA: 0x90, INS: 0xAF, Le: 256)
            } else {
                moreCommand = false
            }
            
            resultCode = rapdu.SW2
            if let rdata = rapdu.Nr {
                response.append(HexUtil.toHex(rdata))
            }
        }
        
        return (resultCode, response)
    }
    
    func getVesion () async throws -> String
    {
        let (code, version) = try await sendNativeCommand(GET_VERSION)
        
        if code != 0 {
            throw MTNFCError(Message: "Mifare DESFire error \(code)")
        }
        
        return version
    }
}
