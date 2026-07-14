//
//  MTNdef.swift
//  tDynamoScanAndConnect
//
//  Created by Yong Guo on 2/8/24.
//

import Foundation

open class MTNdef {
    public static func getNDEFMessages(_ tlvString: String) -> [String] {
        var results: [String] = []
        var tagData: [UInt8] = HexUtil.getByteArrayFromHexString(tlvString)
        var offset: Int = 0
        while offset < tagData.count {
            var tag: UInt8 = tagData[offset]
            if tag == 3 {
                var len: Int = 0
                if offset < tagData.count {
                    len = Int(tagData[offset] & 255)
                    if len == 255 {
                        if (offset + 1) < tagData.count {
                            len = Int((tagData[offset] & 255) << 8)
                            len = len | Int(tagData[offset]) & 255
                        }
                    }
                }
                if len > 0 {
                    if (offset + len) < tagData.count {
                        let msgBytes = tagData.prefix(offset + len).suffix(len)
                        results.append (Data(msgBytes).hexadecimalString)
                    }
                    offset = offset + len
                }
            } else {
                if tag == 254 {
                    break
                }
            }
        }
        return results
    }

    public static func Parse(_ data: [UInt8]) -> [MTNdefRecord] {
        var records: [MTNdefRecord] = []
        var chunkStream: [UInt8]? = nil
        var record: MTNdefRecord! = nil

        var i: Int = 0
        while i < data.count {
            if record == nil {
                record = MTNdefRecord()
            }
            var flag: UInt8 = data[i]
            var be: Bool = (flag & 128) != 0
            var me: Bool = (flag & 64) != 0
            var cf: Bool = (flag & 32) != 0
            var sr: Bool = (flag & 16) != 0
            var il: Bool = (flag & 8) != 0
            record.TNF = flag & 7
            var headerLen: Int = 1
            headerLen = headerLen + (sr ? 1 : 4)
            headerLen = headerLen + (il ? 1 : 0)
            var typeLen: UInt = 0
            var payloadLen: UInt = 0
            if (i + headerLen) < data.count {
                i = i + 1
                typeLen = UInt(data[i])
                i = i + 1
                if sr {
                    payloadLen = UInt(data[i])
                    i = i + 1
                } else {
                    payloadLen = payloadLen | UInt((data[i] << 24))
                    payloadLen = payloadLen | (UInt(data[i+1]) << 16)
                    payloadLen = payloadLen | UInt((data[i+2] << 8))
                    payloadLen = payloadLen | (UInt(data[i+3]) << 0)
                    i = i + 4
                }
            }
            var idLen: UInt = 0
            if il && (i < data.count) {
                idLen = UInt(data[i])
                i = i + 1
            }
            var totalLen: UInt = typeLen + payloadLen + idLen
            if i + Int(totalLen) <= data.count {
                if typeLen > 0 {
                    record.Type = data.prefix(Int(typeLen) + i).suffix(Int(typeLen))
                    i = i + Int(typeLen)
                }
                if idLen > 0 {
                    record.ID = data.prefix(Int(idLen) + i).suffix(Int(idLen))
                    i = i + Int(idLen)
                }
                if payloadLen > 0 {
                    var payload: [UInt8] = data.prefix(Int(payloadLen) + i).suffix(Int(payloadLen))
                    i = i + Int(payloadLen)
                    if cf {
                        if chunkStream == nil {
                            chunkStream = []
                        }
                        chunkStream?.append(contentsOf: payload)
                    } else {
                        if chunkStream != nil {
                            chunkStream?.append(contentsOf: payload)
                            record.Payload = chunkStream!
                            chunkStream = nil
                        } else {
                            record.Payload = payload
                        }
                    }
                }
            }
            else {
                break;
            }
            if !cf {
                records.append(record)
                record = nil
                if me {
                    break
                }
            }
        }
        return records
    }

    public static func BuildNDEFMessage(_ records: [MTNdefRecord], endMeesage : Bool = true) -> [UInt8] {
        var messageBytes: [UInt8] = []
        var recordsStream: [UInt8] = []
        var n: Int = records.count
        for i in 0 ... n - 1 {
            var record: MTNdefRecord! = records[i]
            var recordBytes: [UInt8] = record.toBytes()
            if i == 0 {
                recordBytes[0] = recordBytes[0] | 128
                //  MB
            } else {
                if i == (n - 1) {
                    recordBytes[0] = recordBytes[0] | 64
                    //  ME
                }
            }
            recordsStream.append(contentsOf: recordBytes)
        }
        var recordsArray: [UInt8] = recordsStream
        if recordsArray != nil {
            var len: Int = recordsArray.count
            if len < 255 {
                messageBytes = []
                messageBytes.append(3)
                //  NDEF Tag
                messageBytes.append(UInt8(len & 255))
                messageBytes.append(contentsOf: recordsArray)

            } else {
                messageBytes = []
                messageBytes.append(3)
                //  NDEF Tag
                messageBytes.append( 255)
                messageBytes.append(UInt8((len >> 8) & 255) )
                messageBytes.append(UInt8(len & 255))
                messageBytes.append(contentsOf: recordsArray)
            }
        }
        if (endMeesage) {
            messageBytes.append(0xFE)
        }
            
        return messageBytes
    }
}
