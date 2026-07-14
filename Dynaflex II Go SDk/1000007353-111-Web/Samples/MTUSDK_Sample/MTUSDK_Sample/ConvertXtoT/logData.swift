//
//  logData.swift
//  ConvertXLSXToTLV
//
//  Created by Wenbo Ma on 3/28/22.
//

import Foundation

public enum LogType: UInt {
    case INFO = 0
    case DEBUG
    case WARNING
    case ERROR
    case PROGRESS
}

public class logData : NSObject {
    public var logType: LogType
    public var log: String
    
    init(lt: LogType, s: String){
        logType = lt
        log = s
    }
}
