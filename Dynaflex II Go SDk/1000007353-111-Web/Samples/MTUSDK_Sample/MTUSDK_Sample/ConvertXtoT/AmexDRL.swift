//
//  AmexDRL.swift
//  ConvertXLSXToTLV
//
//  Created by Wenbo Ma on 4/7/22.
//

import UIKit
import Foundation
import CoreXLSX

class AmexDRL: TLVfileWithDelmitersDRL {
    
    init(sourceFile: String, inputCfgName: String, version: String, destinationFolder : String, _version: UInt8 = 0xAA){
        super.init(_SourceFile: sourceFile, _Version: _version)
        
        let outFileName: String = inputCfgName + "_00000" + String(getFileID()) + "00_" + String(HashAlgo().SHA1) + String(format:"%08X", timeStamp()) + "." + version
        
        bGenerateOutputFile = true;
        
        writeLog(lt: LogType.INFO, s: "AMEX DRL Cstor called. Version = \(String(format:"%02X", _version)), OutFile = \(outFileName)")
    }
    
    init(sourceFile: String, _version: UInt8 = 0xAA) {
        super.init(_SourceFile: sourceFile, _Version: _version)
        
        SourceFile = sourceFile
        
        bGenerateOutputFile = true;
        
        writeLog(lt: LogType.INFO, s: "AMEX DRL Cstor called. Version = \(String(format:"%02X", _version))")
    }
    
    func getFileID() ->Int {
        
        return FileID().EMV_CONFIGURATION_FI_AMEX_DRL_SET
        
    }
    
    func getDataWithMagtekHeader() ->String {
        let outString = getTLVFileContent()
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
    
    func hasData() -> Bool {
        return bFound
    }
    
    func getDataBytes() ->[UInt8] {
        let buf:[UInt8] = TLV.HexStringToByteArray(hex:getTLVFileContent())
        return buf
    }
    
    func getData() ->String {
        let outString: String = getTLVFileContent()
        return outString
    }
    
    func RunAndGenerateOutputFile() -> [UInt8]{
        var sDesc: String = ""
        var sTagContent: String = ""
        var sTagLen: String = ""
        var lTagLen: Int = 0
        var sTagValue: String = ""
        var sTagValueNoSpace: String = ""
        var bOkayToStartParsing: Bool = false
        var sRow: String = ""
        
        var sTagIndex: String = ""
        var sValue: String = ""
        var sLength: Int = 0
        
        var iTagCount: Int = 0
        
        var iSlotNumCount: Int = 0
        
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
                      if (sCurrSection.uppercased().contains("AMEXDRL_EMPTY")){
                           bFound = true
                           break;
                      }
                      
                      if (sCurrSection.uppercased().contains("AMEXDRL")){
                          
                          bFound = true
                          
                          let iSlotNum: Int = getIntFromString(str: sCurrSection)
                          iSlotNumCount += 1
                          
                          writeLog(lt: LogType.INFO, s: "Amex DRL. Slot = \(iSlotNum)")
                          
                          if ( iSlotNumCount > 3){//When  iSlotNumCount > 3, happend error
                              iTagCount = 2
                          }
                          
                          
                          var titleRow: Int = 0
                          let worksheet = try file.parseWorksheet(at: path)
                          for row in worksheet.data?.rows ?? [] {
                            for c in row.cells {
                               
                                let contentNumber:String = c.reference.description.trimmingCharacters(in: .whitespaces)
                                var sTag: String = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                
                                //filter empty
                                if (sTag.count == 0 || sTag.contains("https") || sTag.contains("Reference:")
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
                                        
                                        if sDesc == "Other TLVs"{
                                            sTag = ""
                                        }
                                    }
                                }
                                
                                //Do not memory MaxLeng and description
                                if !(contentNumber.hasPrefix("A") || contentNumber.hasPrefix("B") || contentNumber.hasPrefix("C")){
                                    continue
                                }
                                
                                do{
                                    if contentNumber.hasPrefix("A"){
                                        //if TLV.subString(sTag, 0, 2)?.uppercased() == "0X"
                                        if sTag.subString(0, 2)?.uppercased() == "0X"
                                        {
                                            sTagContent = sTag.subString(2, sTag.count)!//subString(sTag, 2, sTag.count)!
                                            
                                            sRow = contentNumber.subString(1, contentNumber.count)!//subString(contentNumber, 1, contentNumber.count)!
                                        }
                                    }
                                }
//                                catch{
//                                    writeLog(lt: LogType.ERROR, s: "Tag does not have expected format (i.e. 0xDF7E)")
//                                }
                                
                                // TagValue
                                if (contentNumber.hasPrefix("B")){
//                                    if sRow == subString(contentNumber, 1, contentNumber.count)! {
                                    if sRow == contentNumber.subString( 1, contentNumber.count)! {
                                        sTagValue = sTag
                                        sTagValueNoSpace = sTagValue.replacingOccurrences(of: " ", with: "", options: [.regularExpression])
                                    }
                                }
                                
                                // TagLen
                                if (contentNumber.hasPrefix("C")){
                                    let contentIndex = contentNumber.subString(1, contentNumber.count)!//subString(contentNumber, 1, contentNumber.count)!
                                    
                                    if sRow != contentIndex{
                                        continue
                                    }
                                    
                                    if Int(contentIndex)! > titleRow {
                                        let temp1: String = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                        //let data = Data(temp1.utf8)
                                        //let hexValue = data.map{ String(format:"%02x", $0) }.joined()
                                        lTagLen = Int(temp1, radix: 16)!
                                        
                                        if (lTagLen == 0x83FFFFFF) {
                                            sTagLen = "83FFFFFF"
                                        }
                                        else if (lTagLen > 0x7f) {
                                            sTagLen = "82" + String(format: "%04X", lTagLen).paddingToLeft(upTo: 4, using: "0")
                                        }
                                        else {
                                            sTagLen = "82" + String(format: "%02X", lTagLen).paddingToLeft(upTo: 2, using: "0")
                                        }
                                        
#if DEBUG
                                        print("TagLen: \(sTagLen)")
#endif
                                    }
                                }
                                
                                if sTagValueNoSpace.contains("DF") {
                                    sTag = ""
                                }
                                
                                if (sRow != "") {
                                    sTagIndex = sTagContent
                                    
                                    if sTagValueNoSpace != "" {
                                        sValue = sTagValueNoSpace
                                    }
                                    
                                    if UInt(lTagLen) != 0 {
                                        sLength = Int(lTagLen)
                                    }
                                    
                                    if (sValue != "" && lTagLen != 0) {
                                        
                                        if iSlotNumCount > 2 {
                                            if (iTagCount - 1) % 3 == 0 {
                                                let tlv_Tag: TLV = TLV.init(tag: sTagIndex, value: sValue, length: sLength)
                                                addTLVItem(tlv: tlv_Tag)
                                            }
                                        }
                                        else{
                                            if iTagCount % 3 == 0 {//iSlotNumCount
                                                let tlv_Tag: TLV = TLV.init(tag: sTagIndex, value: sValue, length: sLength)
                                                addTLVItem(tlv: tlv_Tag)
                                            }
                                        }
                                        iTagCount += 1
                                    }
                                }
                                if  (TempTLVList.count > 2 && TempTLVList.count % 3 == 0) {
                                    let tlv_FF36: TLV = TLV.init(tag: "FF36", value: "")
                                    addTLVItem(tlv: tlv_FF36)
                                }
                             }
                          }
                      }
                   }
                }
                if bFound {
                    if TLVList.count > 0 {
                        let tlv_FF37: TLV = TLV.init(tag: "FF37", value: "")
                        addTLVItem(tlv: tlv_FF37)
                    }
                    
                  return generateOutputFile(outFile: OutFile)
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        return []
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

class FileID: NSObject {
    let EMV_CONFIGURATION_FI_TERMINAL: Int       = 0
    let EMV_CONFIGURATION_FI_PROCESSING: Int     = 1
    let EMV_CONFIGURATION_FI_ENTRY_POINT: Int    = 2
    let EMV_CONFIGURATION_FI_CA_KEYS: Int        = 3
    let EMV_CONFIGURATION_FI_VISA_DRL_SET: Int   = 4
    let EMV_CONFIGURATION_FI_AMEX_DRL_SET: Int   = 5
}

class HashAlgo: NSObject {
    let SHA1: Int = 4
}
