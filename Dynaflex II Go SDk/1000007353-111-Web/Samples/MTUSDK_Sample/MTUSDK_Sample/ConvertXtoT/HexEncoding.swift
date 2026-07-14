//
//  HexEncoding.swift
//  ConvertXLSXToTLV
//
//  Created by Wenbo Ma on 3/25/22.
//

import UIKit
import Foundation

extension String {
    func charAtIndex(index: Int) ->Character {
        let position = self.index(self.startIndex, offsetBy: index)
        let c:Character = self[position]
        return c
    }
}

class HexEncoding : NSObject{
    
    class func getByteCount(hexString: String) ->Int{
        var numHexChars: Int = 0
        
        for char in hexString {
            if isHexDigit(c: char) {
                numHexChars += 1
                }
            }
        
        // if odd number of characters, discard last character
        if (numHexChars % 2 != 0) {
            numHexChars -= 1
        }
        
        return numHexChars / 2
    }
    
    class func getBytes(hexString: String, discarded: inout Int) ->[UInt8]{
        var discarded: Int = 0
        var newString: String = ""
        var c:Character
        
        for i in 0..<hexString.count {
            c = hexString.charAtIndex(index: i)
            if(isHexDigit(c: c)) {
                newString.append(c)
            }
            else{
                discarded += 1
            }
        }
        
        if newString.count % 2 != 0 {
            discarded += 1
            newString = newString.subString(0, newString.count - 1)!//subString(newString, 0, newString.count - 1)!
        }
        
        var bytes:[UInt8] = []
        var j: Int = 0
        for _ in 0..<(newString.count / 2) {
            var hex: String = ""
            hex.append(newString.charAtIndex(index: j))
            hex.append(newString.charAtIndex(index: j + 1))
            bytes.append(HexToByte(hex: hex))
            j += 2
        }
        
        return bytes
    }
    
    class func ToString(bytes:[UInt8]) -> String {
        var hexString: String = ""
        for i in 0..<bytes.count {
            hexString += String(format: "%02X", bytes[i])
        }
        return hexString
    }
    
    class func inHexFormat(hexString: String) -> Bool {
        var hexFormat = true
        for digit in hexString {
            if (isHexDigit(c: digit)){
                hexFormat = false
                break
            }
        }
        return hexFormat
    }
    
    class func isHexDigit(c: Character) -> Bool {
        /*var numChar: Int32 = 0
         let numA:Int32 = Int32(String("A"))!
         let num1:Int32 = Int32(String("0"))!
         
         let mc:Character = Character(String(c).uppercased())
         numChar = Int32(String(mc))!
         if (numChar >= numA && numChar <= (numA + 6)){
         return true
         }
         if (numChar >= num1 && numChar <= (num1 + 10)){
         return true
         }
         return false*/
        let reg = "^[A-F0-9]+$"
        let pre = NSPredicate(format: "SELF MATCHES %@", reg)
        if pre.evaluate(with: String(c)) {
            return true
        } else {
            return false
        }
    }
    
    class func HexToByte(hex:String) ->UInt8 {
        if (hex.count > 2 || hex.count <= 0) {
            print("hex must be 1 or 2 characters in length")
        }
        
        guard let chars = hex.cString(using: String.Encoding.utf8) else { return 0 }
        
        var byteChars: [CChar] = [0, 0, 0]
        var wholeByte: CUnsignedLong = 0
        byteChars[0] = chars[0]
        byteChars[1] = chars[1]
        wholeByte = strtoul(byteChars, nil, 16)
        
        return UInt8(wholeByte)
    }
    /*
    func Ascii2Bin(asciiData: String) ->[UInt8] {
        
    }
    
    func Bin2Ascii(binData: [UInt8]) ->String {
        
    }
    */
    
}
