//
//  TLVfile.swift
//  XLSXSample
//
//  Created by Wenbo Ma on 3/22/22.
//

import UIKit
import Foundation
import CommonCrypto

class TLVfile : NSObject{
    var SourceFile: String = ""
    var OutFile: String = ""
    
    var bHasData: Bool = false
    
    var Version: String = ""
    var SHA1: String = ""
    
    var TLVList:[TLV] = []
    
    init(_SourceFile: String, _Version: UInt8){
        Version = String(format: "%02X", _Version)
        print("initVersion = \(Version)")
        SourceFile = _SourceFile
    }
    
    func AddTLVItem(tlv: TLV) {
//        if (tlv == nil) {
//            print("AddTLVItem: Item is null. Nothing to add")
//            return
//        }
        
        if tlv.Len() == 0{
            return
        }
        
        print("AddTLVItem: Tag = {\(tlv.Tag())}, Len = {\(tlv.Len())}, Value = {\(tlv.Value())}")
        TLVList.append(tlv)
    }
    
    func CalculateChecksum(_body: String) {
        //let body: String = TLV.tlvListToStringFlat(tlvList: TLVList)
        if _body.count == 0 {
            return 
        }
        
        var discarded: Int = 0
        let body_bytes: [UInt8] = HexEncoding.getBytes(hexString: _body, discarded: &discarded)
        
        if discarded > 0 {
            print("Failed to convert Boday string to bytes!")
        }
        
        let hashString: String = byteToSHA1(_data: body_bytes)
        let checksum_str: String = hashString.replacingOccurrences(of: "-", with: "", options: .literal, range: nil)
        SHA1 = checksum_str.uppercased()
    }
    
    func byteToSHA1(_data:[UInt8]) -> String {
        let data = Data(_data)
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
    }
    
    func getTLVFileContent() -> String {
        let body: String = TLV.tlvListToStringFlat(tlvList: TLVList)
        
        if body.count == 0 {
            return ""
        }
        
        CalculateChecksum(_body: body)
        let hexString = Version + SHA1 + body
        
        writeLog(lt: LogType.INFO, s: "Version = ")
        writeLog(lt: LogType.DEBUG, s: Version)
        writeLog(lt: LogType.INFO, s: "SHA1 = ")
        writeLog(lt: LogType.DEBUG, s: SHA1)
        writeLog(lt: LogType.INFO, s: "Body = ")
        writeLog(lt: LogType.DEBUG, s: body)
        
        writeLog(lt: LogType.INFO, s: "getTLVFileContent() = ")
        writeLog(lt: LogType.DEBUG, s: hexString)
        
        return hexString
    }
    
    func generateOutputFile(outFile: String) -> [UInt8] {
        let outBuf:[UInt8] = TLV.HexStringToByteArray(hex: getTLVFileContent())
        if outBuf.count == 0 {  return []  }
        writeLog(lt: LogType.INFO, s: "GenerateOutputFile(): ")
        writeLog(lt: LogType.DEBUG, s: outFile)
        /*
         let localPath: NSString = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first! as NSString
         let filePath = localPath.appendingPathComponent(outFile)
         let fileManager = FileManager.default
         if fileManager.fileExists(atPath: filePath) {
         do{
         try fileManager.removeItem(atPath: filePath)
         print("Success to remove file.")
         sleep(1000)
         }catch{
         print("Failed to remove file.")
         }
         }*/
        
        /*
         fileManager.createFile(atPath: filePath, contents: nil, attributes: nil)
         let fileHandle = FileHandle(forWritingAtPath: filePath)!
         fileHandle.seekToEndOfFile()
         do{
         try fileHandle.write(contentsOf: outBuf)
         }catch{
         print("Failed to write file.")
         }*/
        DumpTLVFile(outFile: outFile)
        
        return outBuf
    }
    
    func DumpTLVFile(outFile:String){
        writeLog(lt: LogType.INFO, s: "--------------- DUMP TLV File: \(outFile)  ---------------")
        writeLog(lt: LogType.INFO, s: "Version = ")
        writeLog(lt: LogType.DEBUG, s: Version)
        writeLog(lt: LogType.INFO, s: "SHA1 = ")
        writeLog(lt: LogType.DEBUG, s: SHA1)
        
        for tlv in TLVList {
            let info: String = String(format: "Tag = %@, Len = %d, Value = %@", tlv.Tag(), tlv.Len(), tlv.Value())
            writeLog(lt: LogType.DEBUG, s: info)
        }
        writeLog(lt: LogType.INFO, s: "--------------- END DUMP TLV File  ---------------")
    }
    
    func writeLog(lt : LogType, s: String){
        if s != "\n" {
            if lt == LogType.INFO || lt == LogType.DEBUG{
                print(s)
            }
            else {
                print("Error is \(s)")
            }
        }
    }
}
