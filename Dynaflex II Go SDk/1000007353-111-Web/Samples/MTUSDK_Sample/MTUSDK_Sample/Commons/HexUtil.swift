//
//  HexUtil.swift
//  MTSCRADemo-Swift
//
//  Created by   on 09/08/19.
//  Copyright © 2019 MagTek. All rights reserved.
//

import UIKit
import Foundation

extension UIColor {

    convenience init(hex: Int) {

        let components = (
            R: CGFloat((hex >> 16) & 0xff) / 255,
            G: CGFloat((hex >> 08) & 0xff) / 255,
            B: CGFloat((hex >> 00) & 0xff) / 255
        )

        self.init(red: components.R, green: components.G, blue: components.B, alpha: 1)

    }
}

extension String
{
    var stripped: String {
        let okayChars = Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890~!@#$%^&*()-=_+`{}|[]\\;':\"<>?,./")
        return self.filter {okayChars.contains($0) }
    }
    
    public var byteArrayFromHexString:[UInt8] {
        return HexUtil.getByteArrayFromHexString(self)
    }
    
    public var dataFromHexString:Data {
        if let data = HexUtil.getBytesFromHexString(self) {
            return Data(data)
        } else {
            return Data()
        }
    }
    
    public var stringFromHexString:String{
        
        let pattern = "(0x)?([0-9a-f]{2})"
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let nsString = self as NSString
        let matches = regex.matches(in: self, options: [], range: NSMakeRange(0, nsString.length))
        let characters = matches.map {
            Character(UnicodeScalar(UInt32(nsString.substring(with: $0.range(at: 2)), radix: 16)!)!)
        }
        return String(characters)    }
  
    func indexDistance(of string: String) -> Int? {
        guard let index = range(of: string)?.lowerBound else { return nil }
        return distance(from: startIndex, to: index)
    }
    
    func index(of string: String, options: String.CompareOptions = []) -> Index? {
        return range(of: string, options: options)?.lowerBound
    }
    
    func split(withMaxLen length:Int) -> [String] {
        
        var startIndex = self.startIndex
        var results = [Substring]()
        
        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }
        
        return results.map { String($0) }
    }

    func get(
        auth: String,
        completionHandler: @escaping (_ data: Data?, _ success: Bool) -> Void
    ) {
        let request = NSMutableURLRequest(url: NSURL(string: self)! as URL)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let authString = Data(auth.utf8).base64EncodedString()
        let authValue = "Basic \(authString)"
        request.addValue(authValue, forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            guard error == nil, data != nil else {
                // Get auth error: The request timed out.
                print("Get auth error: \(error!.localizedDescription)")
                completionHandler(nil, false)
                return
            }
            
#if DEBUG
            let responseString = String(data: data!, encoding: .utf8) ?? "NA"
            print("Get auth response: \(responseString)")
#endif
            
            completionHandler(data, true)
        }
        
        task.resume()
    }
    
    var isNumber: Bool {
        let characters = CharacterSet.decimalDigits.inverted
        return !self.isEmpty && rangeOfCharacter(from: characters) == nil
    }
}


extension Data {
    
    init?(hexString: String) {
        let length = hexString.count / 2
        var data = Data(capacity: length)
        for i in 0 ..< length {
            let j = hexString.index(hexString.startIndex, offsetBy: i * 2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var byte = UInt8(bytes, radix: 16) {
                data.append(&byte, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }
    
    // Convert values: [T] to Data
    init<T>(fromArray values: [T]) {
        // let $0: UnsafeRawBufferPointer
        self = values.withUnsafeBytes { Data($0) }
    }
    
    
    func toArray<T>(type: T.Type) -> [T] {
        return self.withUnsafeBytes {
            [T](UnsafeBufferPointer(start: $0, count: self.count/MemoryLayout<T>.stride))
        }
    }
    
    var toASCIIString: String {
        return String(decoding: self, as: UTF8.self)
    }
    
    /// Return hexadecimal string representation of NSData bytes
    var hexadecimalString: String {
        return self.reduce("") { $0 + String(format: "%02X", $1) }
    }
    
    /*
    func toInterger<T>(withData data: NSData, withStartRange startRange: Int, withSizeRange endRange: Int) -> T {
        var d : T = 0 as! T
        // Warning: Forming 'UnsafeMutableRawPointer' to a variable of type 'T'; this is likely incorrect because 'T' may contain an object reference.
        (self as NSData).getBytes(&d, range: NSRange(location: startRange, length: endRange))
        return d
    }
    */
    
    func split(withMaxLen length:Int) -> [Data] {
        var startIndex = self.startIndex
        var results = [Data]()
        
        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }
        
        return results.map { Data($0) }
    }
    
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }

    func postJsonTo(
        url: String,
        auth: String,
        completionHandler: @escaping (_ data: Data?, _ success: Bool) -> Void
    ) {
#if DEBUG
        print("Post JSON to Server URL String: \(url)")
#endif
        guard let urlObject = URL(string: url) else { return }
        
        let request = NSMutableURLRequest(url: urlObject)
        request.httpMethod = "POST"
        request.httpBody = self
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let authString = Data(auth.utf8).base64EncodedString()
        let authValue = "Basic \(authString)"
        request.addValue(authValue, forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { data, response, error -> Void in
            if (error != nil) {
                completionHandler(nil, false)
            } else {
#if DEBUG
                let responseString = String(data: data!, encoding: .utf8) ?? "N/A"
                print("Post JSON to server's response: \(responseString)")
#endif
                completionHandler(data, true)
            }
        })
        
        task.resume()
    }
}

extension NSData
{
    func parseTLVData() -> [AnyHashable : Any]? {
        var parsedTLVList: [AnyHashable : Any] = [:]
        
        let dataLen = Int(self.count)
        
        if dataLen >= 2 {
            // NSData* tlvData = [self subdataWithRange:NSMakeRange(2, self.length - 2)];
            //subdata(in: 2 ..< dataLen-2)
            let tlvData =  self.subdata(with: NSRange(location: 2, length: self.length - 2))
            //let tlvData = subdata(in: 2 ..< dataLen-2)
            
            var iTLV: Int
            var iTag: Int
            var iLen: Int
            var bTag: Bool
            var bMoreTagBytes: Bool
            var bConstructedTag: Bool
            var ByteValue: UInt8
            var lengthValue: Int
            
            var tagBytes: Data? = nil
            
            let MoreTagBytesFlag1 : UInt8 = 0x1f
            let MoreTagBytesFlag2 : UInt8 = 0x80
            let ConstructedFlag : UInt8 = 0x20
            let MoreLengthFlag : UInt8 = 0x80
            let OneByteLengthMask : UInt8 = 0x7f
            // var TagBuffer = [UInt8](repeating: nil, count: 50)
            var TagBuffer = [UInt8] (repeating: 0, count: 50)
            //var TagBuffer : [UInt8][50] = []
            
            bTag = true
            iTLV = 0
            
            while iTLV < tlvData.count {
                let bytePtr = [UInt8](tlvData) //UInt8(tlvData.bytes)
                ByteValue = bytePtr[iTLV]
                
                if bTag {
                    // Get Tag
                    iTag = 0
                    bMoreTagBytes = true
                    
                    while bMoreTagBytes && (iTLV < tlvData.count) {
                        let bytePtr = [UInt8](tlvData) //UInt8(tlvData.bytes)
                        ByteValue = bytePtr[iTLV]
                        iTLV += 1
                        
                        TagBuffer[iTag] = ByteValue
                        
                        if iTag == 0 {
                            bMoreTagBytes = (ByteValue & MoreTagBytesFlag1) == MoreTagBytesFlag1
                        } else {
                            bMoreTagBytes = (ByteValue & MoreTagBytesFlag2) == MoreTagBytesFlag2
                        }
                        
                        iTag += 1
                    }
                    
                    tagBytes = Data()
                    tagBytes?.append(&TagBuffer, count: iTag)
                    // tagBytes.append(&TagBuffer, length: iTag)
                    bTag = false
                } else {
                    lengthValue = 0
                    
                    if (ByteValue & MoreLengthFlag) == MoreLengthFlag {
                        let nLengthBytes = Int(ByteValue & OneByteLengthMask)
                        
                        iTLV += 1
                        iLen = 0
                        
                        while (iLen < nLengthBytes) && (iTLV < tlvData.count) {
                            let bytePtr = [UInt8](tlvData) //UInt8(tlvData.bytes)
                            ByteValue = bytePtr[iTLV]
                            iTLV += 1
                            lengthValue = Int((lengthValue & 0x000000ff) << 8) + Int(ByteValue & 0x000000ff)
                            iLen += 1
                        }
                    } else {
                        lengthValue = Int(ByteValue & OneByteLengthMask)
                        iTLV += 1
                    }
                    
                    if tagBytes != nil && (memcmp((tagBytes! as NSData).bytes, "00", tagBytes!.count) != 0) {
                        let bytePtr = [UInt8](tagBytes!) //UInt8(tagBytes!.bytes())
                        let tagByte = Int(bytePtr[0])
                        
                        bConstructedTag = (tagByte & Int(ConstructedFlag)) == Int(ConstructedFlag)
                        //bConstructedTag = true
                        if bConstructedTag {
                            let map = MTTLV()
                            map.tag = HexUtil.toHex(tagBytes!)!
                            map.length = lengthValue
                            map.value = "[Container]"
                            // [parsedTLVList addObject:map];
                            parsedTLVList[map.tag.uppercased()] = map
                            //parsedTLVList.setObject(map, forKeyedSubscript: map?.tag)
                        } else {
                            // Primitive
                            var endIndex = iTLV + lengthValue
                            
                            if endIndex > tlvData.count {
                                endIndex = Int(tlvData.count)
                            }
                            
                            var valueBytes: Data? = nil
                            let len = endIndex - iTLV
                            if len > 0 {
                                valueBytes = Data()
                                
                                
                                let range =  NSRange(location: iTLV, length: len)
                                let subData = tlvData.subdata(in: Range<Data.Index>(range)!)
                                // let subData = tlvData.subdata(in: range)
                                valueBytes = subData
                                // valueBytes?.append(subData, count: len)
                                //                                    valueBytes?.append(subData, count: len)
                                //let subData = tlvData.subdata(in: NSRange(location: iTLV, length: len))
                                // valueBytes?.append(subData.bytes, count: len)
                            }
                            
                            let tlvMap = MTTLV()
                            tlvMap.tag = HexUtil.toHex(tagBytes!)!
                            tlvMap.length = lengthValue
                            
                            
                            if valueBytes != nil {
                                tlvMap.value = HexUtil.toHex(valueBytes!)!
                            } else {
                                tlvMap.value = ""
                            }
                            parsedTLVList[tlvMap.tag.uppercased()] = tlvMap
                            
                            
                            // [parsedTLVList addObject:tlvMap];
                            // parsedTLVList.setObject(tlvMap, forKeyedSubscript: tlvMap?.tag)
                            iTLV += lengthValue
                        }
                    }
                    
                    bTag = true
                    
                }
                
            }
        }
        return parsedTLVList
    }
    
    func parseTLVDataWithNoLength() -> [AnyHashable : Any]? {
        let len = length
        var lengthByte = [UInt16] (repeating: 0, count: 2)

// var lengthByte = [UInt8] (repeating: 0, count: 2)
//        lengthByte[1] = UInt8(len)
//        lengthByte[0] = UInt8(len>>8)
        lengthByte[1] = UInt16(len)
        lengthByte[0] = UInt16(len>>8)
        let tempData = NSMutableData()
        tempData.append(&lengthByte[0], length: 1)
        tempData.append(&lengthByte[1], length: 1)
        tempData.append(self as Data)
        return tempData.parseTLVData()
    }
    
}

open class KeyValueStringEncoder {
    
    open func encode<T>(_ value: T) throws -> String where T : Encodable {
        let mirror = Mirror(reflecting: value)
        var values: [String] = []
        
        for child in mirror.children {
            if ((child.label?.isEmpty) != nil){
                throw "Invalid field in \(T.Type.self)"
            }
            
            values.append("\(String(describing: child.label))=\(child.value)")
        }
        
        if values.isEmpty {
            return ""
        } else {
            let allString = values.joined(separator: "&").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            return allString!
        }
    }
}

class HexUtil: NSObject {
    
    class func toHex(_ byteArray : [UInt8]) -> String {
        return byteArray.reduce("") { $0 + String(format: "%02x", $1) }
    }
    
    class func toHex(_ aData: Data) -> String? {
        return aData.hexadecimalString
        //return HexUtil.toHex(aData, offset: 0, len: UInt(aData?.count ?? 0))
    }

    class func getBytesFromHexString(_ strIn: String) -> NSData? {
        
        guard let chars = strIn.cString(using: String.Encoding.utf8) else { return nil}
        var i = 0
        let length = strIn.count
        
        let data = NSMutableData(capacity: length/2)
        var byteChars: [CChar] = [0, 0, 0]
        
        var wholeByte: CUnsignedLong = 0
        
        while i < length {
            byteChars[0] = chars[i]
            i+=1
            byteChars[1] = chars[i]
            i+=1
            wholeByte = strtoul(byteChars, nil, 16)
            data?.append(&wholeByte, length: 1)
        }
        
        return data
    }
    
    class func getByteArrayFromHexString(_ strIn: String) -> [UInt8] {
        
        return Data( getBytesFromHexString(strIn)!).toArray(type: UInt8.self)
    }

    class func toHex(_ aData: Data, offset aOffset: UInt, len aLen: Int) -> String? {
        var sb = String(repeating: "\0", count: (aData.count) * 2)
        let bytes = [UInt8](aData)

        let max = Int(aOffset) + aLen
        for i in Int(aOffset)..<max {
            let b = bytes[i]
            sb += String(format: "%02X", b)
        }
        return sb
    }
}

class MTTLV: NSObject {
    var tag = ""
    var length = 0
    var value = ""
}

extension Dictionary {
    
    func getTLV(_ key: String)-> MTTLV?{
        
        if let dictionaryRef : [String:AnyObject] = self as? [String:AnyObject]
        {
            return dictionaryRef[key] as? MTTLV
        }
        else
        {
            return MTTLV()
        }
    }
    
//    func getTLV(_ key: String?) -> MTTLV? {
//        return self[key ?? ""] as? MTTLV
//    }
    
    // Dump TLV data objects to string
    func dumpTags() -> String? {
        var dump = ""
        for tlvTag in keys {
            let tlv = getTLV(tlvTag as! String)
            if let tag = tlv?.tag, let length = tlv?.length, let value = tlv?.value {
                dump = "\(dump)[\(tag)] [\(length)] \(value)\r\n"
            }
        }
        return dump
    }
}

struct AppsTLVTags {
    static let tlv5F20   = "5F20"
    static let tlvDFDF4D = "DFDF4D"
    static let tlvDFDF33 = "DFDF33"
    
    static let tlvDFDF56 = "DFDF56"
    static let tlvDFDF57 = "DFDF57"
    static let tlvDFDF59 = "DFDF59"
    
    static let tlvDFDF1A = "DFDF1A"
    static let tlvDFDF25 = "DFDF25"
    
    static let tlvDFDF58 = "DFDF58" //Number Of Padded bytes
    
    //Note: if adding new TLV gat add it to array as well!
    
    static let allAppsTLVTags = [
        tlv5F20,
        tlvDFDF4D,
        tlvDFDF56,
        tlvDFDF57,
        tlvDFDF59,
      //  tlvDFDF1A,
        tlvDFDF25
    ]
}

class Regex {
    let internalExpression: NSRegularExpression
    let pattern: String
    
    init(_ pattern: String) {
        self.pattern = pattern
        self.internalExpression = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }
    
    func test(_ input: String) -> Bool {
        // Returns an array containing all the matches of the regular expression in the string.
        let matches = internalExpression.matches(in: input, options: [], range: NSMakeRange(0, input.count))
        return matches.count > 0
    }
}
