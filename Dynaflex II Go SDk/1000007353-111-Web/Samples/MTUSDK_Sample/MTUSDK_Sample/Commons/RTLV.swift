//
//  RTLV.swift
//  ReaderConfig
//
//  Created by Wenbo Ma on 6/20/22.
//  Copyright © 2022 MagTek. All rights reserved.
//

import Foundation

open class RTLV {
    
    static fileprivate let MoreTagBytesFlag1: UInt8 = 0x1F
    static fileprivate let MoreTagBytesFlag2: UInt8 = 0x80
    static fileprivate let ContructedFlag: UInt8 = 0x20
    static fileprivate let MoreLengthFlag: UInt8 = 0x80
    static fileprivate let OneByteLengthMask: UInt8 = 0x7F
    static fileprivate let MAX_TAG_LENGTH: Int = 50
    
    private let bTag : Data
    private let bValue : Data
    var tag : String {
        return bTag.hexEncodedString().uppercased()
    }
    var value : String {
        return bValue.hexEncodedString().uppercased()
    }
    var length : Int  {
        return value.count
    }
    
    init(tag:Data, value:Data) {
        self.bTag = tag
        self.bValue = value
    }
    
    init (tag:String, value:String) {
        self.bTag = Data(hexString: tag)!
        self.bValue = Data(hexString: value)!
    }
    
    var isConstructed : Bool {
        return RTLV.IsTagContructed(firstByte: bTag.first!)
    }
    
    static func HexTLVLength(Length:Int) ->String {
        switch (Length) {
        case 0..<0x80:
            return String(format: "%02X", Length)
        case 80..<0x100:
            return String(format: "81%02X", Length)
        case 0x100..<0x10000:
            return String(format: "82%04X", Length)
        case 0x10000..<0x1000000:
            return String(format: "83%06X", Length)
        default:
            return String(format: "84%08X", Length)
        }
    }
    
    static func IsTagContructed (firstByte : UInt8) -> Bool {
        return ((firstByte & ContructedFlag) == ContructedFlag)
    }
    
    static func getTagValue(tlvList:[RTLV],tagString: String) ->String {
        let tag = tagString.uppercased()
        for tlv in tlvList {
            if tag == tlv.tag {
                return tlv.value
            }
        }
        return ""
    }
    
    func toString() ->String {
        return tag + RTLV.HexTLVLength(Length: length) + value
    }
    
    static func parse(data : Data, recursive : Bool = true) throws ->[RTLV] {
        var iTlv = data.indices.lowerBound
        var result : [RTLV] = []
        
        print("parse TLV data - \(data.hexEncodedString())")
        
        func getByte() throws ->UInt8 {
            guard iTlv < data.count else {
                throw "Reach the end of data, but parsing is not finished"
            }
            let byte = data[iTlv]
            iTlv += 1
            return byte
        }
        
        while (iTlv < data.indices.upperBound) {
            // get tag
            var tagData : Data = Data()
            
            var moreTagByte = false
            repeat {
                let byte = try getByte()
                if (byte == 0 && tagData.isEmpty) {
                    break
                }
                tagData.append(byte)
                moreTagByte = tagData.count == 1 ? ((byte & MoreTagBytesFlag1) == MoreTagBytesFlag1) : ((byte & MoreTagBytesFlag2) == MoreTagBytesFlag2)
            } while moreTagByte
            
            if (tagData.isEmpty) {
                break
            }
            // get tag length
            var tagLength = 0
            let byte = try getByte()
            if (byte & MoreLengthFlag) == MoreLengthFlag {
                var length = Int(byte & OneByteLengthMask)
                repeat {
                    let lengthByte = try getByte()
                    tagLength = tagLength * 256 + Int(lengthByte)
                    length -= 1
                } while length > 0
            } else {
                tagLength = Int(byte)
            }
            
            // get tag value
            guard iTlv + tagLength <= data.indices.upperBound else {
                throw "tag data is exceed, more data needed"
            }
            let tagValue : Data = Data( data[iTlv..<iTlv+tagLength] )
            iTlv += tagLength
            
            result.append(RTLV(tag: tagData, value: tagValue))
            if (recursive && IsTagContructed(firstByte: tagData.first!)) {
                result.append(contentsOf: try parse(data: tagValue))
            }
        }
        return result
    }
    
    static func parse(data : String, recursive : Bool = true) throws ->[RTLV] {
        return try parse(data: Data(hexString: data)!, recursive: recursive)
    }
}

