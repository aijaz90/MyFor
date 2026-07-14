//
//  APDU.swift
//  iDynamo6Swift
//
//  Created by Yong Guo on 4/12/24.
//

import Foundation

public struct APDU
{
    let CLA : UInt8
    let INS : UInt8
    let P1 : UInt8
    let P2 : UInt8
    let Data : [UInt8]?
    let Le : UInt32
    
    init(CLA: UInt8, INS: UInt8, P1: UInt8 = 0, P2: UInt8 = 0, Data: [UInt8]? = nil, Le: UInt32 = 0) {
        self.CLA = CLA
        self.INS = INS
        self.P1 = P1
        self.P2 = P2
        self.Data = Data
        self.Le = Le
    }
    
    var Bytes : [UInt8] {
        var result = [CLA, INS, P1, P2]
        var hasLc = false
        if let data = Data {
            if data.count > 0 {
                hasLc = true
                if (data.count > 255) {
                    result.append(0)
                    result.append(UInt8((data.count >> 8)))
                    result.append(UInt8((data.count % 256)))
                } else {
                    result.append(UInt8((data.count % 256)))
                }
            }
        }
        
        if Le > 0 {
            if Le < 256 {
                result.append(UInt8(Le))
            } else if Le == 256 {
                result.append(0)
            } else if (Le < 65536){
                if !hasLc {
                    result.append(0)
                }
                result.append(UInt8((Le >> 8)))
                result.append(UInt8((Le % 256)))
            } else  {
                if !hasLc {
                    result.append(0)
                }
                result.append(0)
                result.append(0)
            }
        }
        
        return result
    }
}

struct RAPDU {
    let Raw : [UInt8]
    
    var SW1 : UInt8 {
        return Raw[Raw.count-2]
    }
    var SW2 : UInt8 {
        return Raw[Raw.count-1]
    }
    var Nr : [UInt8]? {
        if (Raw.count > 2) {
            return [UInt8]( Raw.prefix(Raw.count - 2))
        } else {
            return nil
        }
    }
    
    init(Raw: [UInt8]) {
        self.Raw = Raw
    }

}
