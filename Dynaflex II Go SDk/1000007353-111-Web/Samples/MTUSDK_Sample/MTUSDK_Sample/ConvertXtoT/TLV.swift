//
//  TLV.swift
//  XLSXSample
//
//  Created by Wenbo Ma on 3/22/22.
//

import UIKit
import Foundation


extension Data {
    var ByteArrayToHexString: String {
        self.hexadecimalString.replacingOccurrences(of: "-", with: "")
    }
}

/*
extension Data {
    
    init<T>(fromArray values: [T]) {
        var values = values
        self.init(buffer: UnsafeBufferPointer(start: &values, count: values.count))
    }
    
    func toArray<T>(type: T.Type) -> [T] {
        return self.withUnsafeBytes {
            [T](UnsafeBufferPointer(start: $0, count: self.count/MemoryLayout<T>.stride))
        }
    }
    
    /// Return hexadecimal string representation of NSData bytes
    
    var hexadecimalString: String {
        return self.reduce("") { $0 + String(format: "%02x", $1) }
    }
    
    var ByteArrayToHexString: String {
        self.hexadecimalString.replacingOccurrences(of: "-", with: "")
    }
    
    func toInterger<T>(withData data: NSData, withStartRange startRange: Int, withSizeRange endRange: Int) -> T {
        var d : T = 0 as! T
        (self as NSData).getBytes(&d, range: NSRange(location: startRange, length: endRange))
        return d
    }
}
*/
extension NSData
{/*
    func parseTLVData() -> [AnyHashable : Any]? {
        var parsedTLVList: [AnyHashable : Any] = [:]
        
        let dataLen = Int(self.count)
        
        if dataLen >= 2 {
            // NSData* tlvData = [self subdataWithRange:NSMakeRange(2, self.length - 2)];
            //subdata(in: 2 ..< dataLen-2)
            let tlvData =  self.subdata(with: NSRange(location: 2,length: self.length-2))
            //let tlvData = subdata(in: 2 ..< dataLen-2)
            
            if tlvData != nil {
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
                                map.tag = TLV.toHex(tagBytes!)!
                                map.length = lengthValue
                                map.value = "[Container]"
                                // [parsedTLVList addObject:map];
                                parsedTLVList[map.tag.uppercased()] = map
                                //(iTLV += lengthValue)
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
                                tlvMap.tag = TLV.toHex(tagBytes!)!
                                tlvMap.length = lengthValue
                                
                                
                                if valueBytes != nil {
                                    tlvMap.value = TLV.toHex(valueBytes!)!
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
        }
        return parsedTLVList
    }*/
    
    func parseTLVDataFlat() -> [AnyHashable : Any]? {
        var parsedTLVList: [AnyHashable : Any] = [:]
        
        let dataLen = Int(self.count)
        
        if dataLen >= 2 {
            // NSData* tlvData = [self subdataWithRange:NSMakeRange(2, self.length - 2)];
            //subdata(in: 2 ..< dataLen-2)
            let tlvData =  self.subdata(with: NSRange(location: 2,length: self.length-2))
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
                            map.tag = TLV.toHex(tagBytes!)!
                            map.length = lengthValue
                            map.value = "[Container]"
                            // [parsedTLVList addObject:map];
                            parsedTLVList[map.tag.uppercased()] = map
                            iTLV += lengthValue
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
                            tlvMap.tag = TLV.toHex(tagBytes!)!
                            tlvMap.length = lengthValue
                            
                            
                            if valueBytes != nil {
                                tlvMap.value = TLV.toHex(valueBytes!)!
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
}


class TLV : NSObject{
    fileprivate let MoreTagBytesFlag1: Int = 0x1F
    fileprivate let MoreTagBytesFlag2: Int = 0x80;
    fileprivate let ContructedFlag: Int = 0x20;
    fileprivate let MoreLengthFlag: Int = 0x80;
    fileprivate let OneByteLengthMask: Int = 0x7F;
    fileprivate let MAX_TAG_LENGTH: Int = 50;
    
    fileprivate var first: String = ""
    fileprivate var second: String = ""
    fileprivate var len: Int = 0
    
    class func toHex(_ aData: Data) -> String? {
        return aData.hexadecimalString
        //return HexUtil.toHex(aData, offset: 0, len: UInt(aData?.count ?? 0))
    }
    
    func Tag() -> String {
        return first
    }
    
    func Value() -> String {
        return second
    }
    
    func Len() -> Int {
        return len
    }
    
    func isConstructed() -> Bool {
        let tagByte: Int? = Int(Tag().subString(0, 2)!)//Int(TLV.subString(Tag(), 0, 2)!)
        return ((tagByte! & ContructedFlag) == ContructedFlag)
    }
    
    init(tag: String, value: String, length: Int = -1) {
        first = tag
        second = value
        
        if length < 0 {
            len = (second.count + 1) / 2
        }
        else{
            len = length
        }
    }
    
    class func ToHexString(_ aData: Data, offset aOffset: UInt, len aLen: Int) -> String? {
        var sb = String(repeating: "\0", count: (aData.count) * 2)
        let bytes = [UInt8](aData)

        let max = Int(aOffset) + aLen
        for i in Int(aOffset)..<max {
            let b = bytes[i]
            sb += String(format: "%02X", b)
        }
        return sb
    }
    
    class func ToByteArray(_ strIn: String) -> NSData? {
        
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
    
    func rebuildTLV(originalTlvList: [TLV], tag: String, newValue: String, oldValue: String = "") -> [TLV]? {
        var newtlvList:[TLV] = []
        let tempTlvList:[TLV] = newtlvList
        var content:String = ""
        var prev_constructed_content:String = ""
        var tlvFound: TLV? = nil
        var newTLV_str: String = ""
        
        // Tag does not exist, return null
        if (!isTagValid(tlvList: originalTlvList, tag: tag)){
            return []
        }
        
        // Tag exists but non-unique (i.e. there are multiple occurences of this tag)
        // The caller must also pass in oldValue for the lookup to work
        let bTagUnique: Bool = isTagUnique(tlvList: originalTlvList, tag: tag)
        if (!bTagUnique && oldValue == ""){
            return []
        }
        
        // the algorithm below will reverse the original tlv structure to start from the "bottom" and rebuild the structure
        // and eventually reverse back the structure before returning to the caller
        _ = tempTlvList.reversed()
        
        var bTagFound: Bool = false
        for tlv in tempTlvList {
            if bTagUnique {
                bTagFound = (tag == tlv.first ? true : false)
            }
            else{
                bTagFound = (tag == tlv.first ? true : false) && (oldValue == tlv.second ? true : false)
            }
            
            if bTagFound {
                // Cache the matched TLV to do some nested lookups later
                tlvFound = TLV.init(tag: tlv.first, value: tlv.second)
                
                // Rebuild the tag in question with new value
                let newTLV: TLV = TLV.init(tag: tag, value: newValue)
                newtlvList.append(newTLV)
                newTLV_str = TLV.TLVTag(tag: newTLV.first, value: newTLV.second)
                
                if let constructedAbove = GetImmediateConstructedTLVAbove(tlvList: originalTlvList, tlv: tlv),
                   let constructedBelow = GetImmediateConstructedTLVBelow(tlvList: originalTlvList, tlv: tlv) {
                    
                    if constructedAbove.second.contains(constructedBelow.second) {
                        content = newTLV_str + content
                    } else {
                        content = newTLV_str
                    }
                }
                else {
                    content = newTLV_str + content
                }
            }else{
                if tlv.isConstructed(){
                    if (FindTagOnConstructedTLV(constructedTLV: tlv, tlv: tlvFound!)){
                        // The tlv in question is embedded in this Constructed TLV --> rebuild constructed TLV
                        let item: TLV = TLV.init(tag: tlv.first, value: content)
                        newtlvList.append(item)
                        
                        if(item.second.contains(prev_constructed_content)){
                            content = TLV.TLVTag(tag: item.first, value: item.second)
                        }
                        else{
                            content = TLV.TLVTag(tag: item.first, value: item.second) + prev_constructed_content
                        }
                    }else{
                        newtlvList.append(tlv)
                        
                        if (tlv.second.contains(prev_constructed_content)){
                            content = TLV.TLVTag(tag: tlv.first, value: tlv.second)
                        }
                        else{
                            content = TLV.TLVTag(tag: tlv.first, value: tlv.second) + prev_constructed_content
                        }
                    }
                    
                    prev_constructed_content = content
                    
                    // Reset the running content if this "tlv" is not embedded on any of its parent tag
                    // if true it means we need to continue carry the running content as we need it later
                    // if false it means this constructed tlv ends here --> reset
                    if (!FindTagOnAnyParentConstructedTLV(tlvList: originalTlvList, tlv: tlv)){
                        content = ""
                        prev_constructed_content = ""
                    }
                }
                else{
                    // Unrelated non-constructed tags are intact
                    newtlvList.append(tlv)
                    content = TLV.TLVTag(tag: tlv.first, value: tlv.second)
                }
            }
        }
        // need to reverse the results because we reversed the original
        _ = newtlvList.reversed()
        return newtlvList
    }
    
    func tlvListToString(tlvList:[TLV]) ->String {
        if (tlvList.count == 0) {
            return ""
        }
        
        var content:String = ""
        
        for tlv in tlvList {
            if (tlv.isConstructed()){
                if (content.contains(TLV.TLVTag(tag: tlv.first, value: tlv.second))){
                    content += TLV.TLVTag(tag: tlv.first, value: tlv.second)
                }
            }
        }
        return content
    }
    
    /*
     <summary>
     [PT] 5/27/2020: Use this if all the TLV items in the list are flat, non-nested (i.e. Costructed is False)
     </summary>
     <param name="tlvList"></param>
     <returns></returns>
     */
    class func tlvListToStringFlat(tlvList:[TLV]) ->String {
        if (tlvList.count == 0) {
            return ""
        }
        
        var content:String = ""
        
        for tlv in tlvList {
            content += TLVTag(tag: tlv.first, value: tlv.second)
        }
        return content
    }
    
    /*
    <summary>
    Find constructed TLV immediately above the tlv in question and return the tlv if found; otherwise return null
    </summary>
    <param name="tlvList"></param>
    <param name="tlv"></param>
    <returns></returns>
     */
    func GetImmediateConstructedTLVAbove(tlvList:[TLV], tlv:TLV) ->TLV? {
        if tlvList.count == 0 {
            return nil
        }
        
        var count: Int = 0
        var index: Int = 0
        var construcedTlv:TLV? = nil
        
        for item in tlvList {
            count += 1
            if item.isConstructed(){
                construcedTlv = tlv
                index = count
                continue
            }
            
            if (item.first == item.first && item.second == tlv.second) {
                return (count == index + 1) ? construcedTlv :nil
            }
        }
        return nil
    }
    
    /*
     <summary>
     Find constructed TLV immediately below the tlv in question and return the tlv if found; otherwise return null
     </summary>
     <param name="tlvList"></param>
     <param name="tlv"></param>
     <returns></returns>
     */
    func GetImmediateConstructedTLVBelow(tlvList:[TLV], tlv:TLV) ->TLV? {
        if tlvList.count == 0 {
            return nil
        }
        
        var bCurrentFound:Bool = false
        
        for item in tlvList {
            if (item.first == tlv.first && item.second == tlv.second){
                bCurrentFound = true
                continue
            }
            
            if bCurrentFound {
                return item.isConstructed() ? item : nil
            }
        }
        return nil
    }
    
    private func FindTagOnConstructedTLV(constructedTLV: TLV, tlv: TLV) -> Bool {
//        if (constructedTLV == nil || tlv == nil){
//            return false
//        }
        
        let constructTLV_str:String = TLV.TLVTag(tag: constructedTLV.first, value: constructedTLV.second)
        let tlvFound_str: String = TLV.TLVTag(tag: tlv.first, value: tlv.second)
        
        if (constructTLV_str.contains(tlvFound_str)){
            return true
        }
        return false
    }
    
    /*
    <summary>
    Find out if the tlv in question exists in ANY parent (ABOVE) constructed tlv
    </summary>
    <param name="tlvList"></param>
    <param name="tlv"></param>
    <returns>true or false</returns>
     */
    private func FindTagOnAnyParentConstructedTLV(tlvList:[TLV], tlv: TLV) -> Bool {
        if (tlvList.count == 0) {
            return false
        }
        
        var bConstructedFound: Bool = false
        
        var constructedTLV_str: String = ""
        let tlv_str = TLV.TLVTag(tag: tlv.first, value: tlv.second)
        
        for item in tlvList {
            if (item.isConstructed() && item.first != tlv.first){
                constructedTLV_str = TLV.TLVTag(tag: item.first, value: item.second)
                if (constructedTLV_str.contains(tlv_str)){
                    bConstructedFound = true
                }
            }
            
            if (item.first == tlv.first && item.second == tlv.second){
                return bConstructedFound
            }
        }
        return false
    }
    
    func isTagValid(tlvList:[TLV], tag:String) -> Bool {
        var matches:Int = 0
        for tlv in tlvList {
            if tlv.first == tag {
                matches += 1
            }
        }
        return matches > 0 ? true : false
    }
    
    /*
     <summary>
     Log TLV structure to a file for debugging purpose
     </summary>
     <param name="tlvList"></param>
     <param name="fname">Optional. Default is "dumpTLV.txt"</param>
     */
    func dumpTLV(tlvList:[TLV], fileName: String = "dumpTLV.txt"){
        if tlvList.count == 0 {
            return
        }
        
        //https://blog.csdn.net/Sico2Sico/article/details/79213122
        let fileManager = FileManager.default
        let file = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first
        let path = file! + fileName

        fileManager.createFile(atPath: path, contents:nil, attributes:nil)
        let handle = FileHandle(forWritingAtPath:path)
        
        var i: Int = 0
        for tlv in tlvList {
            let s: String = String(format: "[{%d}] Constructed = {%d}, TAG = {%@}, VALUE = {%@}", i, tlv.isConstructed(), tlv.first, tlv.second)
            handle?.write(s.data(using: String.Encoding.utf8)!)
            i += 1
        }
    }
    
    /*
     <summary>
     Compare 2 TLV list structure and return true if they are identical; otherwise false.
     </summary>
     <param name="L1">List 1</param>
     <param name="L2">List 2</param>
     <returns>true if the lists are the same; otherwise false</returns>
     */
    func CompareTLVLists(L1:[TLV], L2:[TLV]) ->Bool{
        if L1.count != L2.count{
            return false
        }
        
        var i: Int = 0
        for tlv in L1 {
            if (tlv.first == L2[i].first && tlv.second == L2[i].second){
                i += 1
                continue
            }
            else{
                return false
            }
        }
        return true
    }
    
    func getFormattedTagString() ->String {
        let result: String = "[" + first + "] [" + String(len) + "] " + second
        return result
    }
    
    /*
     <summary>
     Copy from Yong's code for Apollo Get/SetItem: MagTek.Core.Model/Models/TLV
     </summary>
     <param name="TagNode"></param>
     <param name="TagData"></param>
     <returns></returns>
     */
    func buildTagString(TagNode: String, TagData: String) -> String {
        var Tag: String = TagData
        
        let NodeTree = TagNode.split(separator: ".").reversed()
        for Node in NodeTree {
            let tlv = TLV.init(tag: String(Node), value: Tag)
            Tag = tlv.ToString()
        }
        return Tag
    }
    
    func isTagUnique(tlvList:[TLV], tag: String) -> Bool {
        var matches = 0
        for tlv in tlvList {
            if tlv.first == tag {
                matches += 1
            }
        }
        
        return matches == 1 ? true :false
    }
    
    class func parseTLVData(data: String) ->[TLV] {
        var result: [TLV] = []
        let tempList:[AnyHashable : Any] = (TLV.ToByteArray(data)!).parseTLVData()!
        for item in tempList {
            let tlv: TLV = TLV.init(tag: ((item.value) as! MTTLV).tag, value: (item.value as! MTTLV).value, length: (item.value as! MTTLV).length)
            result.append(tlv)
        }
        return result
    }
    func getTagValue(tlvList:[TLV],tagString: String) ->String {
        let tag = tagString.uppercased()
        for tlv in tlvList {
            if tag == tlv.first{
                return tlv.second
            }
        }
        return ""
    }
    
    /*
     <summary>
     Copy from Yong's code for Apollo Get/SetItem: MagTek.Core.Model/Models/TLV
     </summary>
     <param name="TLVData"></param>
     <param name="TagNode"></param>
     <returns></returns>
     */
    /*
    func getTagValue(TLVData:[UInt8], TagNode: String) ->[UInt8]{
        var result:[UInt8] = []
        var Data:[UInt8] = []

        let NodePattern = try! NSRegularExpression(pattern: "(?<Name>\\w+)(\\((?<Index>\\d+)\\))?")
        do {
            let NodeTree = TagNode.split(separator: ".")
            for Node in NodeTree {
                
                let matchs = NodePattern.matches(in: String(Node), options: [], range: NSRange(location: 0, length: Node.utf16.count))
                let match = matchs.first
                var name:String = ""
                let range0 = match!.range(at:0)
                if let nameRange = Range(range0,in:String(Node)){
                    name = String(Node[nameRange])
                }
                var index:Int = 0
                let range1 = match!.range(at: 1)
                if let indexRange = Range(range1, in: String(Node)){
                    index = Int(Node[indexRange])!
                }
                
                var newTLVData = TLVData
                let middleData = NSData(bytes: &newTLVData, length: TLVData.count)
                let tempTLV = middleData.parseTLVDataFlat()
                var tlvArray:NSMutableArray = []
                for item in tempTLV!{
                    
                    if (item as TLV).Tag() == name {
                        
                    }
                }
            }
        } catch  {
            
        }
    }*/
    
    class func HexTLVLength(Length:Int) ->String {
        
        if Length >= 0x1000000 {
            return "84" + String(format: "%08X", Length)
        }
        else if (Length >= 0x10000){
            return "83" + String(format: "%06X", Length)
        }
        else if (Length >= 0x100){
            return "82" + String(format: "%04X", Length)
        }
        else if (Length >= 0x80){
            return "81" + String(format: "%02X", Length)
        }
        else{
            return String(format: "%02X", Length)
        }
    }
    
    class func TLVTag(tag: String, value:String) ->String {
        let length = value.count / 2
        return tag + HexTLVLength(Length: length) + value
    }
    
    class func HexStringToByteArray(hex: String) ->[UInt8] {
        var output:[UInt8] = []
        var newHex = hex
        
        //padding
        if (newHex.count % 2 == 1) {
            newHex = "0" + newHex
        }
        
        for i in (0..<(newHex.count/2)) {
            let oneByte: String = newHex.subString(i*2, i*2 + 2)!//TLV.subString(newHex,i*2, i*2 + 2)!
            
            if let data = TLV.getBytesFromHexString(oneByte) {
                output.append(([UInt8](data))[0])
            }
        }
        
        return output
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
    
    func ToString() ->String {
        return first + TLV.HexTLVLength(Length: len) + second
    }
}

//class MTTLV: NSObject {
//    var tag = ""
//    var length = 0
//    var value = ""
//}
