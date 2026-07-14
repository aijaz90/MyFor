//
//  MTNFCError.swift
//  tDynamoScanAndConnect
//
//  Created by Yong Guo on 2/12/24.
//

import Foundation

open class MTNFCError : Error
{
    let Message : String
    
    var localizedDescription: String {return Message}
    var description: String { return Message }
    
    init(Message: String) {
        self.Message = Message
    }
}
