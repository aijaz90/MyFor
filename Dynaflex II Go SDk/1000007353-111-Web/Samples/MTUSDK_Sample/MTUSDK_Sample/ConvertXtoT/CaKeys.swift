//
//  CaKeys.swift
//  ConvertXLSXToTLV
//
//  Created by Wenbo Ma on 4/18/22.
//

import UIKit
import Foundation
import CommonCrypto
import CoreXLSX

class CaKeys : NSObject{
    var bFound: Bool = false
    
    var CakeyList : [CaKey] = []
    
    var SourceFile: String = ""
    var OutFile: String = ""
    var SHA1: String = ""
    var Body: String = ""
    
    var Version: String = ""
    
    var bGenerateOutputFile: Bool = false
    
    init(_SourceFile: String/*, inputCfgName: String, version: String*/){
        super.init()
        
        SourceFile = _SourceFile
        //Version = version
        bGenerateOutputFile = true
        writeLog(lt: LogType.INFO, s: "Cakey Cstor called, sourecefile  Name  is \(SourceFile)")
    }
    
    init(s: String) {
        super.init()
        
        if s.count == 0 {
            print("Input is null or empty")
            return
        }
        
        let dynaFlexFileMarker: String = s.subString(0, 16)!//subString(s, 0, 16)!
        if dynaFlexFileMarker.uppercased() != "4D47544B41503130"{
            print("File Header is not DynaFlex device!")
            return
        }
        
        let remainder = s.subString(0, dynaFlexFileMarker.count)//subString(s, 0, dynaFlexFileMarker.count)
        var content : String = ""
        
        let tlvs: [TLV] = TLV.parseTLVData(data: remainder!)
        for item in tlvs {
            if item.Tag() == "C1" {
                writeLog(lt: LogType.DEBUG, s: "TLVfile(s): Tag = \(item.Tag()), Len = \(item.Len()), Value = \(item.Value())")
            }
            else if item.Tag() == "E3" {
                writeLog(lt: LogType.DEBUG, s: "TLVfile(s): Tag = \(item.Tag()), Len = \(item.Len()), Value = \(item.Value())")
            }
            else if item.Tag() == "CE" {
                writeLog(lt: LogType.DEBUG, s: "TLVfile(s): Tag = \(item.Tag()), Len = \(item.Len()), Value = \(item.Value())")
                content = item.Value() // "AA" + SHA1(20bytes) + Body
                break
            }
        }
        
        if content.count == 0 {
            return
        }
        
        Body = content.subString(0, content.count - 40)!//subString(content, 0, content.count - 40)!
        SHA1 = content.subString(Body.count, content.count)!//subString(content, Body.count, content.count)!
        
        var discarded: Int = 0
        let body_bytes: [UInt8] = HexEncoding.getBytes(hexString: Body, discarded: &discarded)
        
        if discarded > 0 {
            print("Failed to convert Body string to bytes!")
            return
        }
        
        let checksum_bytes: String = byteToSHA1(_data: body_bytes)
        let checksum_str: String = checksum_bytes.replacingOccurrences(of: "-", with: "", options: .literal, range: nil)
        if checksum_str.uppercased() != SHA1{
            print("Calculated SHA1 of content NOT EQUAL Embedded SHA1 checksum!")
            return
        }
        bFound = true
    }
    
    func getVersion() ->String {
       return Version
    }
    
    func getBody() ->String{
        var body: String = ""
        
        if(Body.count == 0 && CakeyList.count > 0) {
            for item in CakeyList {
                body += item.toString()
            }
        }
        else{
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
        
        CakeyList.removeAll()
        CakeyList = buildCakeyList(input: s)
        CalculateChecksum()
        writeLog(lt: LogType.DEBUG, s: "SetBody: new SHA1 = \(SHA1)")
        
        return getBody()
    }
    
    func getFileID() ->Int {
        
        return FileID().EMV_CONFIGURATION_FI_CA_KEYS
        
    }
    
    func getDataWithMagtekHeader() ->String {
        let outString = getFileContent()
        let DynaFlexFileMarker:[UInt8] = [0x4d, 0x47, 0x54, 0x4b, 0x41, 0x50, 0x31, 0x30]
        
        let fileID: String = "00000" + String(getFileID()) + "00"
        
        let C1: TLV = TLV.init(tag:"C1", value: fileID)
        let CE: TLV = TLV.init(tag:"CE", value: outString)
        
        let finalOutString: String = Data(DynaFlexFileMarker).ByteArrayToHexString + C1.ToString() + CE.ToString()
        
        return finalOutString
    }
    
    func getDataWithMagTekHeaderBytes() ->[UInt8] {
        return TLV.HexStringToByteArray(hex: getDataWithMagtekHeader())
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
    
    func getCaKeyList() ->[CaKey] {
        if CakeyList.count == 0 {
            CakeyList = buildCakeyList(input: Body)
        }
        return CakeyList
    }
    
    func hasData() -> Bool {
        return bFound
    }
    
    func getDataBytes() ->[UInt8] {
        let buf:[UInt8] = TLV.HexStringToByteArray(hex: getFileContent())
        return buf
    }
    
    func getData() ->String {
        let outString: String = getFileContent()
        return outString
    }
    
    private func buildCakeyList(input: String) ->[CaKey] {
        writeLog(lt: LogType.INFO, s: "********************************************")
        writeLog(lt: LogType.INFO, s: "BuildCAKeyList entered (to reconstruct CAKey objects based on a input String)")
        
        var cakeyList:[CaKey] = []
        // Example = input = s1 + s2 + s3
        
        if input.count == 0 { return []}
        
        var index: Int = 0
        var remaining = input
        var processed: String = ""
        
        while (remaining.count != 0) {
            let _RID = remaining.subString(0, 10)//subString(remaining, 0, 10)
            
            index = 10
            let _index = remaining.subString(index, index + 2)//subString(remaining, index, index + 2)
            
            index += 2
            let _exponentLength = remaining.subString(index, index + 2)//subString(remaining, index, index + 2)
            
            index += 2
            let _modulusLength = remaining.subString(index, index + 2)//subString(remaining, index, index + 2)
            
            var exponentLengthInt: Int? = 0
            do{
                exponentLengthInt = Int(_exponentLength!)
            }
//            catch{
//                print("Exponent length failed to parse string-->int")
//                return []
//            }
            
            index += 2
            let _exponent = remaining.subString(index, index + exponentLengthInt! * 2)//subString(remaining, index, index + exponentLengthInt! * 2)
            
            var modulusLengthInt: Int? = 0
            do{
                modulusLengthInt = Int(_modulusLength!)
            }
//            catch{
//                print("Modulus length failed to parse string-->int")
//                return []
//            }
            
            index += exponentLengthInt! * 2
            let _modulus = remaining.subString(index, index + modulusLengthInt! * 2)//subString(remaining, index, index + modulusLengthInt! * 2) //// B8048ABC30C90D976336543E3....
            
            // Calculate checksum following the "Value(hex)" column of the CAKey Excel sheet (from top to bottom)
            // There are 4 rows: content for checksum = A000000004 + 05 + B8048ABC30C90D976336543E3 + 03
            let _checkSum = CalculateChecksum(s: _RID! + _index! + _modulus! + _exponent!)
            
            let newKey: CaKey = CaKey()
            newKey.RID = _RID!
            newKey.index = _index!
            newKey.exponentLength = _exponentLength!
            newKey.exponent = _exponent!
            newKey.modulus = _modulus!
            newKey.checkSum = _checkSum
            
            cakeyList.append(newKey)
            
            writeLog(lt: LogType.INFO, s: "(Reconstructed) CAKeyItem = ")
            writeLog(lt: LogType.DEBUG, s: "   RID =  \(newKey.RID)")
            writeLog(lt: LogType.DEBUG, s: "   Index = \(newKey.index)")
            writeLog(lt: LogType.DEBUG, s: "   ExponentLength = \(newKey.exponentLength)")
            writeLog(lt: LogType.DEBUG, s: "   ModulusLength = \(newKey.modulusLength)")
            writeLog(lt: LogType.DEBUG, s: "   Exponent = \(newKey.exponent)")
            writeLog(lt: LogType.DEBUG, s: "   Modulus = \(newKey.modulus)")
            writeLog(lt: LogType.DEBUG, s: "   CheckSum = \(newKey.checkSum)")
            writeLog(lt: LogType.DEBUG, s: "   --> ToString() = \(newKey.toString())")
            
            processed += newKey.toString()
            
            remaining = input.subString(processed.count, input.count)!//subString(input, processed.count, input.count)!
        }
        return cakeyList
    }
    
    private func addCakeyItem( item: CaKey) {
//        if item == nil {
//            writeLog(lt: LogType.DEBUG, s: "AddCAKeyItem: Item is null. Nothing to add")
//            return
//        }
        
        writeLog(lt: LogType.INFO, s: "AddCAKeyItem = ")
        writeLog(lt: LogType.DEBUG, s: "   RID =  \(item.RID)")
        writeLog(lt: LogType.DEBUG, s: "   Index = \(item.index)")
        writeLog(lt: LogType.DEBUG, s: "   ExponentLength = \(item.exponentLength)")
        writeLog(lt: LogType.DEBUG, s: "   ModulusLength = \(item.modulusLength)")
        writeLog(lt: LogType.DEBUG, s: "   Exponent = \(item.exponent)")
        writeLog(lt: LogType.DEBUG, s: "   Modulus = \(item.modulus)")
        writeLog(lt: LogType.DEBUG, s: "   CheckSum = \(item.checkSum)")
        
        CakeyList.append(item)
        CalculateChecksum()
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
    
    func CalculateChecksum(s: String) ->String {
        
        let body: String = s
        
        var discarded: Int = 0
        let body_bytes: [UInt8] = HexEncoding.getBytes(hexString: body, discarded: &discarded)
        
        if discarded > 0 {
            print("Failed to convert Boday string to bytes!")
        }
        
        var checksum_str: String = ""
        let hashString: String = byteToSHA1(_data: body_bytes)
        checksum_str = hashString.replacingOccurrences(of: "-", with: "", options: .literal, range: nil)
        checksum_str = checksum_str.uppercased()
                
        return checksum_str
    }
    
    func RunAndGenerateOutputFile() -> [UInt8]{
        var sDesc: String = ""
        var sTagContent: String = ""
        var lTagLen: String = ""
        var sTagValue: String = ""
        var sTagValueNoSpace: String = ""
        var bOkayToStartParsing: Bool = false
        var sRow: String = ""
        
        var rowCount: Int = 0
        guard let path = Bundle.main.path(forResource: SourceFile,ofType: "xlsx") else {
            print("Do not find path!!!")
            return []
        }
        
        guard let file = XLSXFile(filepath: path) else {
          fatalError("XLSX file at \(path) is corrupted or does not exist")
        }
        
        do {
            let shared = try file.parseSharedStrings()
            for wbk in try file.parseWorkbooks() {
              for (name, path) in try file.parseWorksheetPathsAndNames(workbook: wbk) {
                  if let sCurrSection = name {
                      if (sCurrSection.uppercased().contains("CAKEY")){
                          
                          bFound = true // At least 1 tab is found --> Will create a binary TLV file
                          
                          let iSlotNum: Int = getIntFromString(str: sCurrSection)
                          writeLog(lt: LogType.INFO, s: "ENTRYPOINT. Slot = \(iSlotNum)")
                          
                          var dicProc: [String:String] = [:]
                          var titleRow: Int = 0
                          
                          let worksheet = try file.parseWorksheet(at: path)
                          for row in worksheet.data?.rows ?? [] {
                            for c in row.cells {
                                
                                let contentNumber:String = c.reference.description.trimmingCharacters(in: .whitespaces)
                                let sTag: String = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                //filter empty
                                if (sTag.contains("https") || sTag.contains("Reference:")
                                    || sTag.contains("AIDDelimiter") || sTag.contains("Delimiter")
                                    || sTag.contains("configuration")){
                                    continue
                                }
                                
                                if (sTag.uppercased() != "TAG" && bOkayToStartParsing == false){
                                    continue
                                }
                                if (sTag.uppercased() == "TAG"){ // Get the title row
                                    let contentIndex = contentNumber.subString(1, contentNumber.count)!//subString(contentNumber, 1, contentNumber.count)!
                                    titleRow = Int(contentIndex)!
                                    
                                    bOkayToStartParsing = true;
                                    continue
                                }
                                // filter title
                                let contentIndex = contentNumber.subString(1, contentNumber.count)!//subString(contentNumber, 1, contentNumber.count)!
                                if Int(contentIndex)! <= titleRow {
                                    continue
                                }
                                
                                // Store description if available
                                if (contentNumber.hasPrefix("E")){
                                    let contentIndex = contentNumber.subString(1, contentNumber.count)!//subString(contentNumber, 1, contentNumber.count)!
                                    if Int(contentIndex)! > titleRow {
                                        let temp1: String = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                        let temp2 = temp1.replacingOccurrences(of: "\n", with: " ")
                                        sDesc = temp2.replacingOccurrences(of: "\r", with: " ")
#if DEBUG
                                        print("Desc: \(sDesc)")
#endif
                                        
                                        //if sDesc == "Other TLVs"{
                                        //    sTag = ""
                                        //}
                                    }
                                }
                                
                                //Do not memory MaxLeng and description
                                if !(contentNumber.hasPrefix("A") || contentNumber.hasPrefix("B") || contentNumber.hasPrefix("C")){
                                        continue
                                }
                                
                                do{
                                    if contentNumber.hasPrefix("A"){
                                        if sTag.count > 2{
                                            //if TLV.subString(sTag, 0, 2)?.uppercased() == "0X"
                                            if sTag.subString(0, 2)?.uppercased() == "0X"
                                            {
                                                sTagContent = sTag.subString(2, sTag.count)!//subString(sTag, 2, sTag.count)!
                                                sRow = contentNumber.subString(1, contentNumber.count)!//subString(contentNumber, 1, contentNumber.count)!
#if DEBUG
                                                print("Row: \(sRow)")
#endif
                                                dicProc[contentNumber] = sTagContent
                                                rowCount += 1
                                            }
                                        }
                                    }
                                }
//                                catch{
//                                    writeLog(lt: LogType.ERROR, s: "Tag does not have expected format (i.e. 0xDF7E)")
//                                }
                                
                                // TagValue
                                if (contentNumber.hasPrefix("B")){
                                    
                                    if sTag.count > 0 {
                                        sTagValue = sTag
                                        sTagValueNoSpace = sTagValue.replacingOccurrences(of: " ", with: "", options: [.regularExpression])
                                        dicProc[contentNumber] = sTagValueNoSpace
                                    }
                                }
                                
                                // TagLen
                                if (contentNumber.hasPrefix("C")){
                                    let contentIndex = contentNumber.subString(1, contentNumber.count)!//subString(contentNumber, 1, contentNumber.count)!
                                    
                                    if Int(contentIndex)! > titleRow {
                                        let temp1: String = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                        if temp1.count > 0 {
                                            
                                            lTagLen = temp1
                                            dicProc[contentNumber] = lTagLen
                                        }
                                    }
                                }
                             }
                          }
                          
                          var _RID:            String  = ""
                          var _index:          String  = ""
                          var _exponentLength: String  = ""
                          var _modulusLength:  String  = ""
                          var _exponent:       String  = ""
                          var _modulus:        String  = ""
                          var _checkSum:       String  = ""
                          
                          // Create object and add it to collection
                           for i in (titleRow + 1)..<(rowCount + titleRow + 2) {
                               let value: String = dicProc["B" + String(i)] ?? ""
                               if value.count == 0 { continue } // This code is very important,if NOT this code, process time rise more than 30 times
                               
                               let tag: String = dicProc["A" + String(i)] ?? ""
                               
                               var len: String = ""
                               if tag.count > 0 {
                                   len = dicProc["C" + String(i)]!
                               }
                               
                               if value.count != 0 {
                                   switch tag {
                                   case "DFDF79":
                                       _RID = value
                                       break
                                       
                                   case "DFDF7A":
                                       _index = value
                                       break
                                       
                                   case "DFDF7B":
                                       _modulus = value
                                       _modulusLength = len
                                       break
                                       
                                   case "DFDF7C":
                                       _exponent = value
                                       _exponentLength = len
                                       
                                       if _exponentLength.count == 1 {
                                           _exponentLength = "0" +  _exponentLength
                                       }
                                       break
                                       
                                   case "DFDF7D":
                                       _checkSum = value
                                       break
                                       
                                   default:
                                       break
                                   }
                               }
                               
                               if (!(_RID.count == 0 || _index.count == 0 || _modulus.count == 0 || _modulusLength.count == 0 || _exponent.count == 0 || _exponentLength.count == 0 || _checkSum.count == 0)){
                                   let cakey: CaKey = CaKey()
                                   cakey.RID            = _RID
                                   cakey.index          = _index
                                   cakey.exponentLength = _exponentLength
                                   cakey.modulusLength  = _modulusLength
                                   cakey.exponent       = _exponent
                                   cakey.modulus        = _modulus
                                   cakey.checkSum       = _checkSum
                                   
                                   addCakeyItem(item: cakey)
                               }
                           }
                      }
                  }
              }
                if bFound {
                  // End of all tables. Write to file
                  return generateOutputFile()
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return []
    }
    
    func generateOutputFile() -> [UInt8] {
        writeLog(lt: LogType.INFO, s: "GenerateOutputFile(): ")
        DumpTLVFile()
        
        let outBuf: [UInt8] = TLV.HexStringToByteArray(hex: getFileContent())
        return outBuf
    }
    
    func DumpTLVFile(){
        let body: String = getBody()
        
        writeLog(lt: LogType.INFO, s: "--------------- DUMP TLV File:  ---------------")
        writeLog(lt: LogType.INFO, s: "Body = ")
        writeLog(lt: LogType.DEBUG, s: body)
        writeLog(lt: LogType.INFO, s: "SHA1 = ")
        writeLog(lt: LogType.DEBUG, s: SHA1)
        
        for iCakey in CakeyList {
            writeLog(lt: LogType.INFO, s: "{")
            writeLog(lt: LogType.DEBUG, s: "   RID =  \(iCakey.RID)")
            writeLog(lt: LogType.DEBUG, s: "   Index = \(iCakey.index)")
            writeLog(lt: LogType.DEBUG, s: "   ExponentLength = \(iCakey.exponentLength)")
            writeLog(lt: LogType.DEBUG, s: "   ModulusLength = \(iCakey.modulusLength)")
            writeLog(lt: LogType.DEBUG, s: "   Exponent = \(iCakey.exponent)")
            writeLog(lt: LogType.DEBUG, s: "   Modulus = \(iCakey.modulus)")
            writeLog(lt: LogType.DEBUG, s: "   CheckSum = \(iCakey.checkSum)")
            writeLog(lt: LogType.INFO, s: "}")
        }
        writeLog(lt: LogType.INFO, s: "--------------- END DUMP TLV File  ---------------")
    }
    
    func getFileContent() ->String {
        let body: String = getBody()
        let hexString: String = body + SHA1
        
        return hexString
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
    
    func timeStamp() -> Int{
        let  now =  NSDate()
        let  timeInterval: TimeInterval  = now.timeIntervalSince1970
        let  timeStamp =  Int(timeInterval)
        
        return timeStamp
    }
    
    func getIntFromString(str: String) -> Int {
        let numbers = str.split(omittingEmptySubsequences: true) { !"0123456789".contains(String($0))}
            .map {Int(String($0))!}
            //.filter {$0 != nil}
            .sorted {$0 > $1}
        return numbers[0]
    }
}

class CaKey: NSObject {
    var RID : String = ""
    var index : String = ""
    var exponentLength : String = ""
    var modulusLength : String = ""
    var exponent : String = ""
    var modulus : String = ""
    var checkSum : String = ""
    
    func toString() ->String {
        return RID + index + exponentLength + modulusLength + exponent + modulus
    }
    
    func isEqual(_ rhs: CaKey?) -> Bool {
        if (RID == rhs?.RID && exponentLength == rhs?.exponentLength && modulusLength == rhs?.modulusLength && exponent == rhs?.exponent && modulus == rhs?.modulus && checkSum == rhs?.checkSum) {
            return true
        }
        else {
            return false
        }
    }
}
