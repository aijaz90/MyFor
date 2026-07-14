//
//  MTNFCTLV.swift
//  tDynamoScanAndConnect
//
//  Created by Yong Guo on 2/21/24.
//

import Foundation

public class MTNFCTLV {
    public let Tag : UInt8
    public let Value : [UInt8]
    
    init(Tag: UInt8, Value: [UInt8]) {
        self.Tag = Tag
        self.Value = Value
    }
    
    static func parse(_ data : [UInt8]) throws -> [MTNFCTLV] {
        var index = 0
        var result : [MTNFCTLV] = []
        
        while (index < data.count) {
            let tag = data[index]
            index = index + 1
            
            if tag == 0xFE { // terminator
                break
            }
            
            let length1 = data[index]
            index = index + 1
            
            var length : Int = Int(length1)
            if (length1 == 0xFF) {
                length = Int(data[index]) * 256 + Int(data[index + 1])
                index = index + 2
            }
            let valueEndIndex = index + length
            
            let value = [UInt8] (data[index..<valueEndIndex])
            index = valueEndIndex
            result.append(MTNFCTLV(Tag: tag, Value: value))
        }
        
        return result
    }
}
