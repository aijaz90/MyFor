//
//  Properties.swift
//  ConvertXLSXToTLV
//
//  Created by Wenbo Ma on 3/31/22.
//

import UIKit
import Foundation
import CoreXLSX

class Properties : NSObject{
    var propertyList: [Property] = []
    var bFound: Bool = false
    var dicProperties: [String:String] = [:]
    
    var sourceFile: String = ""
    var bGenerateOutputFile: Bool = false
    
    init(inputFile: String) {
        super.init()
        
        sourceFile = inputFile
        bGenerateOutputFile = false
        writeLog(lt: LogType.INFO, s: "PROPERTIES Cstor called. SourceFile = \(sourceFile)")
    }
    
    func isOutputFilrGenerated() -> Bool {
        return bGenerateOutputFile
    }
    
    func hasData() ->Bool {
        return bFound
    }
    
    func getPropertyCount() ->Int {
        return propertyList.count
    }
    
    func getProperty(index: Int) -> Property {
        if (propertyList.count == 0){
            print("Empty list")
        }
        if (index > propertyList.count - 1){
            print("PropertyList (zero-based) has \(propertyList.count) items")
        }
        return propertyList[index]
    }
    
    func Run(){
        var iTagCount: Int = 0
        
        guard let path = Bundle.main.path(forResource: sourceFile,ofType: "xlsx") else {
            print("Do not find path!!!")
            return
        }
        
        guard let file = XLSXFile(filepath: path) else {
           fatalError("XLSX file at \(path) is corrupted or does not exist")
        }
        
        do {
            let shared = try file.parseSharedStrings()
            for wbk in try file.parseWorkbooks() {
                  for (name, path) in try file.parseWorksheetPathsAndNames(workbook: wbk) {
                     if let sCurrSection = name {
                         if (sCurrSection.uppercased().contains("PROPERTIES")){
                             bFound = true;   // At least 1 tab is found

                             var _Tag: String = "";
                             var _Cmd: String = "";
                             var _OID: String = "";
                             var _Value: String = "";
                             var _Length: String = "";
                             var _MaxLength: String = "";
                             var _Description: String = "";
                             
                             // Get the title row
                             var titleRow: Int = 0
                             
                             let worksheet = try file.parseWorksheet(at: path)
                             for row in worksheet.data?.rows ?? [] {
                                 for c in row.cells {
                                     let contentNumber:String = c.reference.description.trimmingCharacters(in: .whitespaces)
                                     let sTag: String = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                     
                                     if (sTag.uppercased() == "TAG"){
                                         let contentIndex = contentNumber.subString(1, contentNumber.count)!//subString(contentNumber, 1, contentNumber.count)!
                                         titleRow = Int(contentIndex)!
                                         continue
                                     }
                                     
                                     //filter empty and commite
                                     if (sTag.count == 0 || sTag.contains("https") || sTag.contains("Reference:")
                                         || sTag.contains("AIDDelimiter") || sTag.contains("Delimiter")
                                         || sTag.contains("configuration")){
                                         continue
                                     }
                                     
                                     // filter title
                                     let index = contentNumber.index(contentNumber.startIndex, offsetBy: 1)
                                     let contentIndex = String(contentNumber[index])
                                     if Int(contentIndex)! <= titleRow {
                                         continue
                                     }
                                     
                                     // Tag
                                     if (contentNumber.hasPrefix("A")) {
                                         let index = contentNumber.index(contentNumber.startIndex, offsetBy: 1)
                                         let contentIndex = String(contentNumber[index])
                                         if Int(contentIndex)! > titleRow {
                                             _Tag = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                         }
                                     }
                                     
                                     // Comand
                                     if (contentNumber.hasPrefix("B")) {
                                         let index = contentNumber.index(contentNumber.startIndex, offsetBy: 1)
                                         let contentIndex = String(contentNumber[index])
                                         if Int(contentIndex)! > titleRow {
                                             _Cmd = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                         }
                                     }
                                     
                                     // OID
                                     if (contentNumber.hasPrefix("C")) {
                                         let index = contentNumber.index(contentNumber.startIndex, offsetBy: 1)
                                         let contentIndex = String(contentNumber[index])
                                         if Int(contentIndex)! > titleRow {
                                             _OID = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                         }
                                     }
                                     
                                     // Value(hex)
                                     if (contentNumber.hasPrefix("D")) {
                                         let index = contentNumber.index(contentNumber.startIndex, offsetBy: 1)
                                         let contentIndex = String(contentNumber[index])
                                         if Int(contentIndex)! > titleRow {
                                             _Value = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                         }
                                     }
                                     
                                     // Length
                                     if (contentNumber.hasPrefix("E")) {
                                         let index = contentNumber.index(contentNumber.startIndex, offsetBy: 1)
                                         let contentIndex = String(contentNumber[index])
                                         if Int(contentIndex)! > titleRow {
                                             _Length = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                         }
                                     }
                                     
                                     // MaxLength
                                     if (contentNumber.hasPrefix("F")) {
                                         let index = contentNumber.index(contentNumber.startIndex, offsetBy: 1)
                                         let contentIndex = String(contentNumber[index])
                                         if Int(contentIndex)! > titleRow {
                                             _MaxLength = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                         }
                                     }
                                     
                                     // Discription
                                     if (contentNumber.hasPrefix("G")) {
                                         let index = contentNumber.index(contentNumber.startIndex, offsetBy: 1)
                                         let contentIndex = String(contentNumber[index])
                                         if Int(contentIndex)! > titleRow {
                                             _Description = (c.stringValue(shared!) ?? "").trimmingCharacters(in: .whitespaces)
                                         }
                                     }
                                     
                                     if (_Length != "" && _MaxLength != "" && _Description != ""){
                                         if iTagCount % 7 == 0 {
                                             let _oid = OID.init(s: _OID)
                                             let prop: Property = Property.init(_tag: _Tag, _cmd: _Cmd, _oid: _oid, _value: _Value, _len: _Length, _maxLen: _MaxLength, _des: _Description)
                                             addPropertyItem(item: prop)
                                         }
                                         iTagCount += 1
                                     }
                                 }
                             }
                         }
                     }
                 }
            }
        }catch{
            print(error.localizedDescription)
        }
    }
    
    private func addPropertyItem(item: Property) {
//        if (item == nil) {
//            writeLog(lt: LogType.DEBUG, s: "AddPropertyItem: Item is null. Nothing to add")
//            return
//        }
        
        dicProperties[item.tag] = item.value
        writeLog(lt: LogType.INFO, s: "\n**************Display Item Begin***************")
        writeLog(lt: LogType.INFO, s: "AddPropertyItem = ")
        writeLog(lt: LogType.DEBUG, s: "   Tag = \(item.tag)")
        writeLog(lt: LogType.DEBUG, s: "   Command  = \(item.cmd)")
        //writeLog(lt: LogType.DEBUG, s: "   OID  = \(item.oid)")
        writeLog(lt: LogType.DEBUG, s: "   OID_FORMAT  = \(item.oid.OID_Formated)")
        writeLog(lt: LogType.DEBUG, s: "   Value  = \(item.value)")
        writeLog(lt: LogType.DEBUG, s: "   Length  = \(item.len)")
        writeLog(lt: LogType.DEBUG, s: "   MaxLength  = \(item.maxLen)")
        writeLog(lt: LogType.DEBUG, s: "   Description  = \(item.des)")
        writeLog(lt: LogType.INFO, s: "**************Display Item End*****************")
        propertyList.append(item)
        
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

class Property: NSObject{
    var tag: String = ""
    var cmd: String = ""
    var oid: OID
    var value: String = ""
    var len: String = ""
    var maxLen: String = ""
    var des: String = ""
    
    init(_tag: String, _cmd: String, _oid:OID, _value: String, _len: String, _maxLen: String, _des: String){
        tag = _tag
        cmd = _cmd
        oid = _oid
        value = _value
        len = _len
        maxLen = _maxLen
        des = _des
    }
}

class OID : NSObject {
    var E1: String = ""
    var E2: String = ""
    var E3: String = ""
    var E4: String = ""
    var E5: String = ""
    
    var Function: String = ""
    var OID_Formated: String = ""
    var OID_Original: String = ""
    
    init(s: String) {
        super.init()
        
        OID_Original = s
        if(s.count == 0){
            print("OID field is null or empty")
        }
        if(s.count != 12) {
            print("OID field NOT 12 numbers")
        }
        else{
            Function = trimString(s: s, from: 0, to: 2)
            E1 = trimString(s: s, from: 2, to: 4)
            E2 = trimString(s: s, from: 4, to: 6)
            E3 = trimString(s: s, from: 6, to: 8)
            E4 = trimString(s: s, from: 8, to: 10)
            E5 = trimString(s: s, from: 10, to: 12)
            
            OID_Formated = String(format: "E%@.E%@.E%@.E%@.C%@", E1,E2,E3,E4,E5)
        }
    }
    
    func trimString(s:String, from: Int, to: Int) ->String{
        var result: String = ""
        let middle: String = s.subString(from, to)!//subString(s, from, to)!
        if middle.hasPrefix("0"){
            let index = middle.index(middle.startIndex, offsetBy: 1)
            result = String(middle[index])
        } else {
            result = middle
        }
        return result
    }
    
    func properToString() -> String {
        return  String(format: "0%@0%@0%@0%@0%@0%@", Function,E1,E2,E3,E4,E5)
    }
}
