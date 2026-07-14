//
//  TLVfileWithDelimiters.swift
//  ConvertXLSXToTLV
//
//  Created by Wenbo Ma on 4/7/22.
//

import UIKit
import Foundation
import CommonCrypto

/// <summary>
/// This class is inherited by PROCESSING and ENTRY POINT classes
/// </summary>

class TLVfileWithDelmiters : NSObject{
    var SourceFile: String = ""
    var OutFile: String = ""
    var bHasData: Bool = false
    
    var Version: String = ""
    var SHA1: String = ""
    var TLVList: [TLV] = []
    var TempTLVList: [TLV] = []
    var DF0E_tlv:TLV? = nil
    var otherTLVS: String = ""
    
    var Body: String = ""
    
    var bGenerateOutputFile: Bool = false
    
    init(_SourceFile: String, _Version: UInt8){
        super.init()
        
        Version = String(format: "%02X", _Version)
        SourceFile = _SourceFile
        
        writeLog(lt: LogType.INFO, s: "Base Cstor called. Version = \(Version), SourceFile = \(SourceFile)")
    }
    
    init(s: String) {
        super.init()
        
        if s.count == 0 {
            print("Input is null or empty")
        }
        
        let DynaFlexFileMarker: String = s.subString(0, 16)!//subString(s, 0, 16)!
        if (DynaFlexFileMarker.uppercased() != "4D47544B41503130") {
            print("File Header is not DynaFlex device!")
        }
        
        let remainder = s.subString(16, s.count)!//subString(s, 16, s.count)!
        var content: String = ""
        
        let tlvs: [TLV] = TLV.parseTLVData(data: remainder)
        for tlv in tlvs {
            if tlv.Tag() == "C1"{
                writeLog(lt: LogType.DEBUG, s: "TLVfile(s): Tag = \(tlv.Tag()), Len = \(tlv.Len()), Value = \(tlv.Value())")
            }
            else if tlv.Tag() == "E3"{
                writeLog(lt: LogType.DEBUG, s: "TLVfile(s): Tag = \(tlv.Tag()), Len = \(tlv.Len()), Value = \(tlv.Value())")
            }
            else if tlv.Tag() == "CE"{
                writeLog(lt: LogType.DEBUG, s: "TLVfile(s): Tag = \(tlv.Tag()), Len = \(tlv.Len()), Value = \(tlv.Value())")
                content = tlv.Value()
                break
            }
        }
        
        if content.count == 0 { return }
        
        Version = content.subString(0, 2)!//subString(content, 0, 2)!
        
        if content == "AA" { return }
        
        SHA1 = content.subString(2, 40)!//subString(content, 2, 40)!
        Body = content.subString(42,content.count)!//subString(content, 42, content.count)!
        
        var discarded: Int = 0
        let body_bytes: [UInt8] = HexEncoding.getBytes(hexString: Body, discarded: &discarded)
        
        if discarded > 0 {
            print("Failed to convert Body string to bytes!")
        }
        
        let hashString: String = byteToSHA1(_data: body_bytes)
        let checksum_str: String = hashString.replacingOccurrences(of: "-", with: "", options: .literal, range: nil)
        if checksum_str.uppercased() != SHA1 {
            print("Calculated SHA1 of content NOT EQUAL Embedded SHA1 checksum!")
        }
        bHasData = true
    }
    
    func getVersion() ->String {
        return Version
    }
    
    func getBody() ->String {
        
        var body: String = ""
        
        if (body.count == 0 && TLVList.count > 0) {
            body = TLV.tlvListToStringFlat(tlvList: TLVList)
        }
        else {
            body = Body
        }
        return body
    }
    
    func setBody(s: String) ->String {
        
        writeLog(lt: LogType.DEBUG, s: "SetBody: new body = \(s)")
        
        if s.count == 0 {
            print("SetBody: Input string null or empty!")
            return ""
        }
        
        Body = ""
        
        // this includes all Constructed and non-constructed tags.
        // We only need those constructed with "FF37" because the other ones are already embedded in the parent/constructed
        let tlvs: [TLV] = TLV.parseTLVData(data: s)
        var constructed_tlv:[TLV] = []
        for tlv in tlvs {
            // Note that "FF36" is a constructed but used as a Excel sheet/tab delimiter which is included in the final "FF37".
            // Therefore we will skip the individual "FF36" as well
            if (tlv.isConstructed()) {
                constructed_tlv.append(tlv)
            }
        }
        
        TLVList = constructed_tlv
        let body: String = TLV.tlvListToStringFlat(tlvList: TLVList)
        
        CalculateChecksum()
        
        writeLog(lt: LogType.DEBUG, s: "SetBody: new SHA1 = \(SHA1)")
        
        return body
    }
    
    func getOutputFile() -> String {
        return OutFile
    }
    
    func getHashValue() -> String {
        return SHA1
    }
    
    func isOutputFileGenerated() -> Bool {
        return bGenerateOutputFile
    }
    
    /// <summary>
    /// Add a new tag to the Body (Temp tag list). Handle special Tag (such as DF0E, DF0F) and delimeter (such as FF33, FF35). Calculate checksum of FINAL body after when adding delimeter.
    /// </summary>
    /// <param name="i"></param>
    func addTLVItem(tlv: TLV) {
//        if tlv == nil {
//            writeLog(lt: LogType.DEBUG, s: "AddTLVItem: Item is null. Nothing to add")
//            return
//        }
        
        if tlv.Tag().uppercased() == "FF33"{ // "Processing" delimeter
            let body: String = TLV.tlvListToStringFlat(tlvList: TempTLVList)
            let tlv_delimiterTag: TLV = TLV.init(tag: "FF33", value: body + otherTLVS)
            TLVList.append(tlv_delimiterTag)
            
            writeLog(lt: LogType.DEBUG, s: "AddTLVItem: Tag (Delimiter) = \(tlv_delimiterTag.Tag()), Len = \(tlv_delimiterTag.Len()), Value = \(tlv_delimiterTag.Value())")
            
            // Reset internal data, getting ready for the next tab (e.g. ProcessingXX)
            TempTLVList.removeAll()
            otherTLVS = ""
            CalculateChecksum()
        }
        else if tlv.Tag().uppercased() == "DF0E" {
            // Entry Point 3-byte ID TLV (kernel, contactless AID, transaction type)
            DF0E_tlv = TLV.init(tag: "DF0E", value: tlv.Value())
        }
        else if tlv.Tag().uppercased() == "" {
            otherTLVS = tlv.Value()
            writeLog(lt: LogType.DEBUG, s: "AddTLVItem: Tag (Delimiter) = \(tlv.Tag()), Len = \(tlv.Len()), Value = \(tlv.Value())")
        }
        else if tlv.Tag().uppercased() == "FF35"{ // "Entry Point" delimeter
            let sDF0E = DF0E_tlv?.ToString()
            
            let body: String = TLV.tlvListToStringFlat(tlvList: TempTLVList)
            let DF0F_tlv = TLV.init(tag: "DF0F", value: body + otherTLVS)
            let sDF0F = DF0F_tlv.ToString()
            
            let tlv_delimiterTag: TLV = TLV.init(tag: "FF35", value: sDF0E! + sDF0F)
            TLVList.append(tlv_delimiterTag)
            
            writeLog(lt: LogType.DEBUG, s: "AddTLVItem: Tag (Delimiter) = \(tlv_delimiterTag.Tag()), Len = \(tlv_delimiterTag.Len()), Value = \(tlv_delimiterTag.Value())")
            
            // Reset internal data, getting ready for the next tab (e.g. EntryPointXX)
            TempTLVList.removeAll()
            otherTLVS = ""
            
            CalculateChecksum()
        }
        else {
            // This section is for both PROCESSING and ENTRY POINT classes
            if (tlv.Len() == 0 || tlv.Value() == "EMPTY") {
                return
            }
            writeLog(lt: LogType.DEBUG, s: "AddTLVItem: Tag (Delimiter) = \(tlv.Tag()), Len = \(tlv.Len()), Value = \(tlv.Value())")
            TempTLVList.append(tlv)
        }
    }
    
    func CalculateChecksum() {
        
        let body: String = TLV.tlvListToStringFlat(tlvList: TLVList)
        
        var discarded: Int = 0
        let body_bytes: [UInt8] = HexEncoding.getBytes(hexString: body, discarded: &discarded)
        
        if discarded > 0 {
            print("Failed to convert Boday string to bytes!")
        }
        
        let hashString: String = byteToSHA1(_data: body_bytes)
        let checksum_str: String = hashString.replacingOccurrences(of: "-", with: "", options: .literal, range: nil)
        SHA1 = checksum_str.uppercased()
    }
    
    func getTLVFileContent() -> String {
        var body: String = ""
        
        if (body.count == 0 && TLVList.count > 0) {
            body = TLV.tlvListToStringFlat(tlvList: TLVList)
        }
        else{
            body = Body
        }
        
        let hexString: String = Version + SHA1 + body
        
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
        writeLog(lt: LogType.INFO, s: "GenerateOutputFile(): ")
        writeLog(lt: LogType.DEBUG, s: outFile)
        
        DumpTLVFile(outFile: outFile)
        
        let outBuf:[UInt8] = TLV.HexStringToByteArray(hex: getTLVFileContent())
        return outBuf
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
    
    func byteToSHA1(_data:[UInt8]) -> String {
        let data = Data(_data)
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joined()
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
}
