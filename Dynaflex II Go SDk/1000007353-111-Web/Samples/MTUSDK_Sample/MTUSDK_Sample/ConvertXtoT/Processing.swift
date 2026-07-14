//
//  Processing.swift
//  ConvertXLSXToTLV
//
//  Created by Wenbo Ma on 4/8/22.
//

import UIKit
import Foundation
import CoreXLSX

class Processing: TLVfileWithDelmiters {
    
    init(sourceFile: String, inputCfgName: String, version: String, destinationFolder : String, _version: UInt8 = 0xAA){
        super.init(_SourceFile: sourceFile, _Version: _version)
        
        OutFile = inputCfgName + "_00000" + String(getFileID()) + "00_" + String(HashAlgo().SHA1) + String(format:"%08X", timeStamp()) + "." + version
        
        bGenerateOutputFile = true;
        
        writeLog(lt: LogType.INFO, s: "PROCESSING Cstor called. Version = \(String(format:"%02X", _version)), OutFile = \(OutFile)")
    }
    
    init(sourceFile: String, _version: UInt8 = 0xAA) {
        super.init(_SourceFile: sourceFile, _Version: _version)
        
        SourceFile = sourceFile
        
        bGenerateOutputFile = true;
        
        writeLog(lt: LogType.INFO, s: "APROCESSING Cstor called. Version = \(String(format:"%02X", _version))")
    }
    
    func getFileID() ->Int {
        
        return FileID().EMV_CONFIGURATION_FI_PROCESSING
        
    }
    
    func hasData() -> Bool {
        return bHasData
    }
    
    func getDataBytes() ->[UInt8] {
        let buf:[UInt8] = TLV.HexStringToByteArray(hex:getTLVFileContent())
        return buf
    }
    
    func getData() ->String {
        let outString: String = getTLVFileContent()
        return outString
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
    
    func RunAndGenerateOutputFile() -> [UInt8]{
        var sDesc: String = ""
        var sTagContent: String = ""
        var sTagLen: String = ""
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
                      if (sCurrSection.uppercased().contains("ROCESSING")){
                          
                          bHasData = true
                          
                          let iSlotNum: Int = getIntFromString(str: sCurrSection)
                          
                          writeLog(lt: LogType.INFO, s: "ROCESSING. Slot = \(iSlotNum)")
                          
                          var dicProc: [String:String] = [:]
                          var titleRow: Int = 0
                          
                          let worksheet = try file.parseWorksheet(at: path)
                          for row in worksheet.data?.rows ?? [] {
                            for c in row.cells {
                                
                                let contentNumber:String = c.reference.description.trimmingCharacters(in: .whitespaces)
                                var sTag: String = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
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
                                            
                                            if (Int(lTagLen, radix: 16) == 0x83FFFFFF){
                                                sTagLen = "83FFFFFF"
                                            }
                                            else if (Int(lTagLen, radix: 16)! > 0x7f) {
                                                sTagLen = "82" + String(format: "%04X", lTagLen).paddingToLeft(upTo: 4, using: "0")
                                            }
                                            else {
                                                sTagLen = "82" + String(format: "%02X", lTagLen).paddingToLeft(upTo: 2, using: "0")
                                            }
#if DEBUG
                                            print("TagLen: \(sTagLen)")
#endif
                                            
                                            dicProc[contentNumber] = lTagLen
                                        }
                                    }
                                }
                             }
                          }
                          // Create TLV object and add it to collection
                           for i in (titleRow + 1)..<(rowCount + titleRow + 2) {
                               let tag: String = dicProc["A" + String(i)] ?? ""
                               let value: String = dicProc["B" + String(i)] ?? ""
                               var len: Int = 0
                               if tag.count > 0 {
                                   len = Int(dicProc["C" + String(i)]!) ?? 0
                               }
                               
                               if value.count > 0 {
                                   if tag.count > 0 {
                                       let tlv_Tag: TLV = TLV.init(tag: tag, value: value, length: len)
                                       addTLVItem(tlv: tlv_Tag)
                                   }
                                   else{
                                       let tlv_Tag: TLV = TLV.init(tag: "", value: value, length:0)
                                       addTLVItem(tlv: tlv_Tag)
                                   }
                               }
                           }
                          
                          // End of each table, add Delimeter TLV tag
                          let tlv_FF33: TLV = TLV.init(tag: "FF33", value: "")
                          addTLVItem(tlv: tlv_FF33)
                      }
                  }
              }
                if bHasData {
                  // End of all tables. Write to file
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
