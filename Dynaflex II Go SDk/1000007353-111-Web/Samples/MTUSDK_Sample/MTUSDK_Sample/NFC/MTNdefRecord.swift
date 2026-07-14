//
//  MTNdefRecord.swift
//  tDynamoScanAndConnect
//
//  Created by Yong Guo on 2/8/24.
//

import Foundation


open class MTNdefRecord {
    public static var TNF_EMPTY: UInt8 = 0
    public static var TNF_WELL_KNOWN: UInt8 = 1
    public static var TNF_MIME_MEDIA: UInt8 = 2
    public static var TNF_ABSOLUTE_URI: UInt8 = 3
    public static var TNF_EXTERNAL_TYPE: UInt8 = 4
    public static var TNF_UNKNOWN: UInt8 = 5
    public static var TNF_UNCHANGED: UInt8 = 6
    public static var TNF_RESERVED: UInt8 = 7
    public static var RTD_TEXT: [UInt8] = [84]
    public static var RTD_URI: [UInt8] = [85]
    public static var RTD_SMART_POSTER: [UInt8] = [83, 112]
    public static var URI_MAP: [String] = ["", "http://www.", "https://www.", "http://", "https://", "tel:", "mailto:", "ftp://anonymous:anonymous@", "ftp://ftp.", "ftps://", "sftp://", "smb://", "nfs://", "ftp://", "dav://", "news:", "telnet://", "imap:", "rtsp://", "urn:", "pop:", "sip:", "sips:", "tftp:", "btspp://", "btl2cap://", "btgoep://", "tcpobex://", "irdaobex://", "file://", "urn:epc:id:", "urn:epc:tag:", "urn:epc:pat:", "urn:epc:raw:", "urn:epc:", "urn:nfc:"]
    public var TNF: UInt8 = 0
    public var `Type`: [UInt8]?
    public var ID: [UInt8]?
    public var Payload: [UInt8]?

    public static func createTextRecord(_ textPayload: [UInt8]) -> MTNdefRecord! {
        return MTNdefRecord(MTNdefRecord.TNF_WELL_KNOWN, MTNdefRecord.RTD_TEXT, nil, textPayload)
    }
    
    public static func createTextRecord(_ textPayload : String) -> MTNdefRecord {
        var textBytes : [UInt8] = [2,0x65, 0x6E] // en
        textBytes.append(contentsOf: textPayload.data(using: .ascii)!.toArray(type: UInt8.self))
        return createTextRecord(textBytes)
    }

    public static func createUriRecord(_ uriPayload: [UInt8]) -> MTNdefRecord! {
        return MTNdefRecord(MTNdefRecord.TNF_WELL_KNOWN, MTNdefRecord.RTD_URI, nil, uriPayload)
    }
    
    public static func createUriRecord(_ uriPayload : String) -> MTNdefRecord {
        var textBytes = uriPayload.data(using: .utf8)!.toArray(type: UInt8.self)
        textBytes.append(0) // NULL terminator
        return createUriRecord(textBytes)
    }

    public static func createMimeRecord(_ mimeType: [UInt8], _ mimePayload: [UInt8]) -> MTNdefRecord! {
        return MTNdefRecord(MTNdefRecord.TNF_MIME_MEDIA, mimeType, nil, mimePayload)
    }

    public static func createAbsoluteUriRecord(_ uri: [UInt8]) -> MTNdefRecord! {
        return MTNdefRecord(MTNdefRecord.TNF_ABSOLUTE_URI, uri, nil, nil)
    }

    public static func createExternalRecord(_ extType: [UInt8], _ extPayload: [UInt8]) -> MTNdefRecord! {
        return MTNdefRecord(MTNdefRecord.TNF_EXTERNAL_TYPE, extType, nil, extPayload)
    }

    public init() {
        TNF = 0
        Type = nil
        ID = nil
        Payload = nil
    }

    public init(_ tnf: UInt8, _ type: [UInt8]?, _ id: [UInt8]?, _ payload: [UInt8]?) {
        TNF = tnf
        Type = type
        ID = id
        Payload = payload
    }

    public func toBytes() -> [UInt8] {
        var recordBytes: [UInt8] = []

        var b0: UInt8 = TNF
        b0 = b0 | 16
        if ID != nil {
            b0 = b0 | 8
        }
        if let Payload = self.Payload {
            recordBytes.append(b0)
            recordBytes.append(1)
            recordBytes.append(UInt8(Payload.count) )
            
            if let recordType = self.Type {
                recordBytes.append(contentsOf: recordType)
            }

            recordBytes.append(contentsOf: Payload)
        }
        return recordBytes
    }

    public func isRtdType(_ typeName: [UInt8]) -> Bool {
        var result: Bool = false
        // if (TNF == TNF_WELL_KNOWN) // Well Known Types
        guard let recordType = self.Type else
        {
            return false
        }
        if recordType.count == typeName.count && recordType.count > 0 {
            result = true
            for i in 0 ... typeName.count - 1 {
                if recordType[i] != typeName[i] {
                    result = false
                }
            }
        
        }
        return result
    }

    public func isUri() -> Bool {
        return isRtdType(MTNdefRecord.RTD_URI)
    }

    public func isText() -> Bool {
        return isRtdType(MTNdefRecord.RTD_TEXT)
    }

    public func isWellKnownType() -> Bool {
        return TNF == MTNdefRecord.TNF_WELL_KNOWN
    }

    public func isMimeType() -> Bool {
        return TNF == MTNdefRecord.TNF_MIME_MEDIA
    }

    public func isAbsoluteUriType() -> Bool {
        return TNF == MTNdefRecord.TNF_ABSOLUTE_URI
    }

    public func isExternalType() -> Bool {
        return TNF == MTNdefRecord.TNF_EXTERNAL_TYPE
    }

    public func getUriString() -> String! {
        var uriString: String = ""
        if isUri() {
            uriString = ""
            if let Payload = self.Payload {
                var uriPrefix: UInt8 = Payload[0]
                if (uriPrefix >= 0) && (uriPrefix <= 35) {
                    uriString = MTNdefRecord.URI_MAP[Int(uriPrefix)]
                }
                var len: Int = Payload.count - 1
                if len > 0 {
                    uriString = uriString + String(bytes: Payload, encoding: .utf8)!
                }
            }
        } else {
            if isAbsoluteUriType() {
                if let recordType = self.Type {
                    uriString = String(cString: recordType)
                }
            }
        }
        return uriString
    }

    public func getTextString() -> String! {
        var textString: String = ""
        guard let Payload = self.Payload else { return "" }
        if isText() {

            var len = Payload.count
            var i = 0
            if len > 0 {
                var utf8: Bool = (Payload[0] & 0x80) == 0
                var lenLang = Payload[0] & 63
                i = i + 1
                len = len - 1
                if len >= lenLang {
                    var langBytes: [UInt8] = []
                    langBytes.append(contentsOf: Payload.prefix(Int(lenLang) + i).suffix(from: i))
                    i = i + Int(lenLang)
                    len = len - Int(lenLang)
                }
                    
                if len > 0 {
                    var textBytes: [UInt8] = []
                    textBytes.append(contentsOf: Payload.suffix(from: i).prefix(len))
                        
                    if utf8 {
                        textString = String(bytes: textBytes, encoding: .utf8)!
                    } else {
                        textString = String(bytes: textBytes, encoding: .unicode)!
                    }
                }
            }
        } else {
            if isMimeType() {
                textString = String(cString: Payload)
            } else {
                if isExternalType() {
                    textString = String(cString: Payload)
                }
            }
        }
        return textString
    }
}
