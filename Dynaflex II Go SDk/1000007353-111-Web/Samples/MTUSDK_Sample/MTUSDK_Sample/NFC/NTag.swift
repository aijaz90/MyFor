//
//  NTag.swift
//  tDynamoScanAndConnect
//
//  Created by Yong Guo on 2/12/24.
//

import Foundation

open class NTag {
    let GET_VERSION = "60"
    let READ = "30"
    let FAST_READ = "3A"
    let WRITE = "A2"
    
    /// send a NFC command and get the response. NTag class need this to contruct.
    ///  @param command NTAG command to send
    ///  @param lastCommand Indicate it is a last command to send. Device will beep and close the communication to tag card once it is last command.
    ///  @returns NFC response
    let sendNfc : ((_ command : String, _ lastCommand : Bool)async throws->(String))
    var userSize : UInt8 = 0
    
    init(sendNfc: @escaping (_: String, _: Bool)async throws -> String) {
        self.sendNfc = sendNfc
    }
    
    public func getVersion() async throws -> Void {
        let _ = try await sendNfc(GET_VERSION, false)
    }
    
    public func getMemorySize()  async throws -> UInt{
        if userSize == 0 {
            let vhex = try await readOne(0)
            userSize = vhex.count > 15 ? vhex[14] : 0
        }
            
        return UInt(userSize) * 8
    }
    
    public func readAll() async throws -> [UInt8] {
        if (userSize == 0) {
            let vhex = try await readOne(0)
            userSize = vhex.count > 15 ? vhex[14] : 0
        }
        
        //let readCount = 8
        let readCount = 255 - 4 // read all in one shot
        
        if (userSize > 0) {
            var result : [UInt8] = []
            let lastBlock = userSize * 2 + 4 - 1
            for start in stride(from: 4, to: lastBlock, by: readCount) {
                let isLastRead = start + UInt8(readCount) > lastBlock
                let endBlock = isLastRead ? lastBlock : start + UInt8(readCount) - 1 ;
                
                let value = try await fastRead(start, endBlock, lastCommand: isLastRead)
                result.append(contentsOf: value)
            }
            return result
        } else {
            return []
        }
    }
    
    public func readNdef() async throws -> [MTNdefRecord] {
        let all = try await readAll()
        
        var result : [MTNdefRecord]  = []
        
        let tlvs = try MTNFCTLV.parse(all)
        for tlv in tlvs {
            result.append(contentsOf: MTNdef.Parse(tlv.Value))
        }
        
        return result
    }
    
    public func writeAll ( _ data : [UInt8]) async throws -> Bool {
        let firstBlock = 4
        let endBlock = (data.count + 3) / 4 + 4 - 1
        if endBlock > userSize * 2 {
            throw MTNFCError(Message: "Data is more than tag maximum size")
        }
        
        var index = 0
        var success = true
        for block in firstBlock..<endBlock {
            success = try await writeOne(UInt8(block), data.suffix(from: index))
            index = index + 4
            if (!success) {
                break
            }
        }
        
        if (success) {
            success = try await writeOne(UInt8(endBlock), data.suffix(from: index), lastCommand: true)
        }
        
        return success
    }
    
    public func writeNdef(_ records : [MTNdefRecord]) async throws -> Bool {
        let data = MTNdef.BuildNDEFMessage(records)
        return try await writeAll(data)
    }
    
    public func readOne(_ block : UInt8, lastCommand : Bool = false) async throws -> [UInt8] {
        let hexBlock = String(format:"%02X", block)
        let vhex = try await sendNfc(READ + hexBlock, lastCommand)
        return vhex.byteArrayFromHexString
    }
    
    public func fastRead( _ startBlock : UInt8, _ endBlock : UInt8, lastCommand : Bool = false) async throws -> [UInt8] {
        let hexStartBlock = String(format:"%02X", startBlock)
        let hexEndBlock = String(format:"%02X", endBlock)
        let vhex = try await sendNfc(FAST_READ + hexStartBlock + hexEndBlock, lastCommand)
        return vhex.byteArrayFromHexString
    }
    
    public func writeOne(_ block : UInt8, _ data : any Sequence<UInt8>, lastCommand : Bool = false) async throws -> Bool {
        let hexStartBlock = String(format:"%02X", block)
        var useData = [UInt8](data)
        if useData.count < 4 {
            useData.append(contentsOf: [0,0,0])
        }
        let hexData = String(format:"%02X%02X%02X%02X", useData[0],useData[1],useData[2],useData[3])
        let _ = try await sendNfc(WRITE + hexStartBlock + hexData, lastCommand)
        return true
    }
}
