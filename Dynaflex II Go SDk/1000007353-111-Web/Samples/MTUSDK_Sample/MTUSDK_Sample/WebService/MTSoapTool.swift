//
//  MTSoapTool.swift
//  QwickPAY-V2
//
//  Created by Marijan Vukcevich on 4/12/16.
//  Copyright © 2016 MagTek. All rights reserved.
//

import UIKit
import Foundation


enum XMLArraysEnum: String{
    case additionalDataCase = "AdditionalRequestData"
    case transInputDetailsCase = "TransactionInputDetails"
    
    static let allCases = [additionalDataCase,transInputDetailsCase]
}

enum XMLReceiptEnum: String{
    case additionalItemsCase = "AdditionalTransactionItems"
    
    static let allCases = [additionalItemsCase]
}

enum ExReceiptEMVLabels: String {
    // case tidLabel = "TID"
    case creditCardType = "Card Type"
    case cardEntryMethod = "Card Entry Method"
    case aidLabel = "AID"
    case iadLabel = "IAD"
    case appPrefferedName = "Application Preferred Name"
    case appLabel = "Application Label"
    case offModeLabel = "Authorization Mode"
    case tvrLabel = "TVR"
    // case arcLabel = "ARC"
    case tsiLabel = "TSI"
    
    // static let allEmvLabels = [tidLabel, cardEntryMethod, aidLabel, iadLabel, appPrefferedName, appLabel, tvrLabel, arcLabel, tsiLabel]
    static let allEmvLabels = [creditCardType, cardEntryMethod, aidLabel, iadLabel, appPrefferedName, appLabel, offModeLabel, tvrLabel, tsiLabel]
    static let allEmvHistroyLabels = [cardEntryMethod, aidLabel, iadLabel, appPrefferedName, appLabel, offModeLabel, tvrLabel, tsiLabel]
}


protocol MTSoapToolDelegate {
    func connectionGotError(_ error:NSError)
}

class MTSoapTool : NSObject, XMLParserDelegate {
    
    var delegate:MTSoapToolDelegate?
    // var taskCompletionHandler:(_ someParameter:NSDictionary, _ rs: Int) -> Void = { _,_ in }
    var completionHandler:(_ someParameter:NSDictionary, _ rs: Int) -> Void = { _,_ in }
    
    fileprivate var theConnection: URLSession?
    
    fileprivate var functionName: NSString?
    fileprivate var soapUrl: NSString?
    
    fileprivate var tags: Array<Any>?
    fileprivate var vars: Array<Any>?
    fileprivate var excludeInputTag: Bool = false
    
    
    override init() {
        self.theConnection = URLSession(configuration: URLSessionConfiguration.default)
    }
    
    func startSoapTool(_ status:Int) {
        
        let url:URL = URL(string: soapUrl! as String)!
        
        print(#line, #function, "DEBUG:startSoapTool-url: \(url)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 45 //From docs: "...The default timeout interval is 60 seconds. ..."
        request.cachePolicy = NSURLRequest.CachePolicy.useProtocolCachePolicy
        
        request.setValue("text/xml", forHTTPHeaderField: "Content-Type")
        request.setValue("utf-8", forHTTPHeaderField: "charset")
        request.setValue("tr", forHTTPHeaderField: "Lang")
        request.setValue(NSString(format: "http://www.magensa.net/%@",functionName!) as String, forHTTPHeaderField:"SOAPAction")
        request.setValue("Mac OS X; WebServicesCore.framework (1.0.0)", forHTTPHeaderField: "User-Agent")
        
        request.httpMethod = "POST"
        
        var log = String()
        
        log.append("<?xml version=\"1.0\" encoding=\"utf-8\"?><soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n<soap:Body>")
        
        if(status == 1) {
            log.append(String(format:"\n<%@ xmlns=\"http://www.magensa.net/\">",functionName!))
            if(!excludeInputTag)
            {
                log.append(String(format:"\n<%@_Input>",functionName!))
            }
        } else {
            log.append(String(format:"\n<%@ xmlns=\"http://www.magensa.net/\"/>",functionName!))
        }
        
        let strResult = buildTagsVars(status: status, functionName: functionName! as String, tags: tags, vars: vars)
        log.append(strResult)
        
        if (status == 1) {
            if(!excludeInputTag)
            {
                log.append(String(format:"\n</%@_Input>",functionName!))
            }
            log.append(String(format:"\n</%@>\n</soap:Body>\n</soap:Envelope>",functionName!))
        } else {
            log.append(String(format:"\n</soap:Body>\n</soap:Envelope>"))
        }
        
        print(#line, #function, "[DBG-startSoapTool(_:)-log]: \(log)")
        
        request.httpBody = log.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSSS"
        print(#line, #function, "Begin Request at \(formatter.string(from: Date()))");
        
        let task = self.theConnection!.dataTask(with: request as URLRequest) { (data, response, error) in
            
            print(#line, #function, "Get Response at \(formatter.string(from: Date()))");
            
            if let response = response {
                print("Response: \(response)")
            }
            
            guard let resData:Data = data, error == nil else {
                
                //  print(#line, #function, "dbg-data_request()- error", data!)
                print("dbg-data_request()- error: \(String(describing: error))")
                // print("dbg-data_request()- error.code: \(String(describing: error?._code))")
                //For testing purposes only - since we are passing the error message via delegate call
                if (error! as NSError).domain == NSURLErrorDomain && (error! as NSError).code == NSURLErrorNotConnectedToInternet {
                    print("Debug: Not Connected ")
                } else if (error! as NSError).code == NSURLErrorNetworkConnectionLost {
                    print("Debug: Network Connection Lost ")
                }
                
                //Note: need to go back to main queue for UI update
                DispatchQueue.main.async {
                    self.delegate?.connectionGotError(error! as NSError)
                }
                return
            }
            
            let returnDict = NSDictionary(xmlData:resData)
            
            if let _ = returnDict?.value(forKeyPath: "soap:Body.GetImage10Response") {
                //Not needed to print out -- get image response to debug console.
            } else {
                print(#line, #function, "[dbg(startSoapTool(_:)--returnDict]:", returnDict!)
            }
            
            //Note: need to go back to main queue for UI update
            DispatchQueue.main.async {
                self.completionHandler(returnDict!, 0);
            }
        }
        
        task.resume()
    }
    
    func buildTagsVars(status:Int, functionName:String, tags:[Any]?, vars:[Any]?) -> String {
        
        var strResult = ""
        
        for i in 0 ..< tags!.count {
            
            if(status == 1) {
                
                if (functionName == "GetTransactionReceipt10") {
                    //Note: ONLY for Receipt function
                    if (vars![i] is Dictionary<String, String>) {
                        
                        for ar in XMLReceiptEnum.allCases.enumerated() {
                            var tempStrResult = ""
                            if((tags![i] as! String) == ar.element.rawValue) {
                                if ((vars![i] as AnyObject).count != 0) {
                                    tempStrResult += ("<" + (tags![i] as! String) + ">")
                                    
                                    // for (_, v) in (vars![i] as! Dictionary<String, String>).enumerated() {
                                    if (vars![i] is Dictionary<String, String>) {
                                        let dictEmv = vars![i] as! Dictionary<String, String>
                                        //print(#line, #function, "dbg-dictEmv:", dictEmv)
                                        
                                        
                                        for (_, v) in ExReceiptEMVLabels.allEmvLabels.enumerated() {
                                            tempStrResult += "<ReceiptKVP>"
                                            if(dictEmv[v.rawValue] != nil)
                                            {
                                                let encodeValue = String(format:"%@", encodeToHexadecimal(dictEmv[v.rawValue]!))
                                                tempStrResult += "<Key>" + v.rawValue + ":" + "</Key>" + "<Value>" + encodeValue + "</Value>"
                                            }
                                            tempStrResult += "</ReceiptKVP>"
                                            
                                        }
                                    }
                                    
                                    tempStrResult += "</" + (tags![i] as! String) + ">"
                                } else {
                                    tempStrResult += "<" + (tags![i] as! String) + "><ReceiptKVP></ReceiptKVP>" + "</" + (tags![i] as! String) + ">"
                                }
                                
                            }
                            strResult += tempStrResult
                        }
                        
                    } else {
                        strResult += NSString(format:"<%@>%@</%@>", tags![i] as! String, encodeToHexadecimal(vars![i] as! String), tags![i] as! String) as String
                    }
                    
                    
                } else {
                    
                    //NOTE: For other web service functions
                    
                    if (vars![i] is Dictionary<String, String>) {
                        
                        for ar in XMLArraysEnum.allCases.enumerated() {
                            var tempStrResult = ""
                            if((tags![i] as! String) == ar.element.rawValue) {
                                if ((vars![i] as AnyObject).count != 0) {
                                    tempStrResult += ("<" + (tags![i] as! String) + ">")
                                    for (_, v) in (vars![i] as! Dictionary<String, String>).enumerated() {
                                        tempStrResult += "<KeyValuePair>"
                                        let encodeValue = String(format:"%@", encodeToHexadecimal(v.value as String))
                                        tempStrResult += "<Key>" + v.key + "</Key>" + "<Value>" + encodeValue + "</Value>"
                                        tempStrResult += "</KeyValuePair>"
                                    }
                                    tempStrResult += "</" + (tags![i] as! String) + ">"
                                } else {
                                    tempStrResult += "<" + (tags![i] as! String) + "><KeyValuePair></KeyValuePair>" + "</" + (tags![i] as! String) + ">"
                                }
                                
                            }
                            strResult += tempStrResult
                        }
                        
                    } else {
                        strResult += NSString(format:"<%@>%@</%@>", tags![i] as! String, encodeToHexadecimal(vars![i] as! String), tags![i] as! String) as String
                    }
                    
                } //end else - functionName
                
            }
        }
        
        return strResult
    }
    
    func callSoapServiceWithParameters(_ functionNameIn:NSString, tagsIn:Array<Any>, varsIn:Array<Any>, wsdlURLIn:NSString, excludeInput:Bool, handler:@escaping ((NSDictionary, Int)->Void)) {
        excludeInputTag = excludeInput;
        self.callSoapServiceWithParameters(functionNameIn, tagsIn:tagsIn, varsIn:varsIn, wsdlURLIn:wsdlURLIn, handler:handler)
    }
    
    func callSoapServiceWithParameters(_ functionNameIn:NSString, tagsIn:Array<Any>, varsIn:Array<Any>, wsdlURLIn:NSString, handler:@escaping ((NSDictionary, Int)->Void)) {
        
        completionHandler = handler;
        functionName =     functionNameIn;
        soapUrl      =     wsdlURLIn;
        tags         =     tagsIn;
        vars         =     varsIn;
        
        self.startSoapTool(1)
    }
    
    func parserDidEndDocument(_ parser:XMLParser) {
        
    }
    
    // XML reserved characters - encode as hexadecimal character references
    func encodeToHexadecimal(_ url:String) -> String {
        if(url.contains("FileObject")) {
            return url
        }
        
        let escapeChars = NSArray(objects:"&", "<", ">")
        
        let replaceChars = NSArray(objects: "&#x26;", "&#x60;", "&#x62;")
        
        let len = escapeChars.count
        
        let temp = url.mutableCopy()
        
        
        for i in 0..<len {
            // (temp as AnyObject).replaceOccurrences(of: escapeChars.object(at: i) as! String, with:replaceChars.object(at: i) as! String, options:.literal, range:NSMakeRange(0, temp.length))
            let target = escapeChars.object(at: i) as! String
            let destination = replaceChars.object(at: i) as! String
            let rang = NSMakeRange(0, (temp as! NSString).length)
            _ = (temp as AnyObject).replaceOccurrences(of: target, with: destination, options: .literal, range: rang)
        }
        
        let out = temp
        
        return out as! String
    }
    
}
