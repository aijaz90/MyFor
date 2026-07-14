//
//  TLVfileWithDelmitersDRL.swift
//  ConvertXLSXToTLV
//
//  Created by Wenbo Ma on 4/4/22.
//

import UIKit
import Foundation
import CommonCrypto

/// <summary>
/// This class is derived by VisaDRL and AmexDRL. Each type uses FF36 as (Excel) tab/page delimeter, and FF37 as a single final delimeter. There is 20-byte SHA1 after Version byte AA, following FF37 tag (which may contain several FF36 tags).
/// Same pattern for both Visa and Amex
/// </summary>
class TLVfileWithDelmitersDRL : NSObject{
    var SourceFile: String = ""
    var OutFile: String = ""
    var bFound: Bool = false
    
    var Version: String = ""
    var SHA1: String = ""
    
    var TLVList: [TLV] = []
    var TempTLVList: [TLV] = []

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
        Body = content.subString(42, content.count)!//subString(content, 42, content.count)!
        
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
        bFound = true
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
            if (tlv.isConstructed() && tlv.Tag() == "FF37") {
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
    
    // <summary>
    // Add a new tag to the Body (Temp tag list). Handle delimiter such as FF36. Calculate checksum of FINAL body after when adding final delimeter FF37.
    // </summary>
    // <param name="i"></param>
    
    func addTLVItem(tlv: TLV) {
//        if tlv == nil {
//            writeLog(lt: LogType.DEBUG, s: "AddTLVItem: Item is null. Nothing to add")
//            return
//        }
        
        if tlv.Tag().uppercased() == "FF36"{ // "DRL" tab/page delimeter
            let body: String = TLV.tlvListToStringFlat(tlvList: TempTLVList)
            let tlv_delimiterTag: TLV = TLV.init(tag: "FF36", value: body)
            TLVList.append(tlv_delimiterTag)
            
            writeLog(lt: LogType.DEBUG, s: "AddTLVItem: Tag (Delimiter) = \(tlv_delimiterTag.Tag()), Len = \(tlv_delimiterTag.Len()), Value = \(tlv_delimiterTag.Value())")
            
            TempTLVList.removeAll()
        }
        else if tlv.Tag().uppercased() == "FF37"{ // "DRL" final delimeter (may contain several FF36)
            let body: String = TLV.tlvListToStringFlat(tlvList: TLVList)
            let tlv_delimiterTag: TLV = TLV.init(tag: "FF37", value: body)
            
            TLVList.removeAll()
            TLVList.append(tlv_delimiterTag)
            
            writeLog(lt: LogType.DEBUG, s: "AddTLVItem: Tag (Delimiter) = \(tlv_delimiterTag.Tag()), Len = \(tlv_delimiterTag.Len()), Value = \(tlv_delimiterTag.Value())")
            CalculateChecksum()
        }
        else {
            if tlv.Len() == 0 { return }
            writeLog(lt: LogType.DEBUG, s: "AddTLVItem: Tag (Delimiter) = \(tlv.Tag()), Len = \(tlv.Len()), Value = \(tlv.Value())")
            TempTLVList.append(tlv)
        }
    }
    
    func CalculateChecksum() {
        
        let body: String = getBody()
        
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
        let body:String = getBody()
        
        if body.count == 0 && SHA1.count == 0 { return "" }
        
        let hexString: String = Version + SHA1 + body
        
        return hexString
    }
    
    func generateOutputFile(outFile:String)->[UInt8] {
        writeLog(lt: LogType.INFO, s: "GenerateOutputFile(): ")
        writeLog(lt: LogType.DEBUG, s: outFile)
        
        DumpTLVFile(outFile: outFile)
        
        let outBuf: [UInt8] = TLV.HexStringToByteArray(hex: getTLVFileContent())
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
    
    
    func writeLog(lt: LogType, s logString: String) {
        if logString != "\n" {
            if lt == LogType.INFO || lt == LogType.DEBUG {
                print(logString)
            }
            else {
                print("Error is \(logString)")
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
}















