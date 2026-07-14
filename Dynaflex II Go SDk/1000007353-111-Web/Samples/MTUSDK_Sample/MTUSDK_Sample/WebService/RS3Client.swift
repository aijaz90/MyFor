//
//  RS3Client.swift
//  RS3
//
//  Created by Yong Guo on 5/20/22.
//

import Foundation

struct Authentication: Codable {
    
    let CustomerCode: String
    let Password: String
    let Username: String
    
    init(_ username: String, _ password: String, _ customercode: String) {
        Username = username
        Password = password
        CustomerCode = customercode
    }
    
    func toString() -> String {
        return "\(CustomerCode)/\(Username):\(Password)"
    }
}

struct KeyInfo: Codable {
    var id: Int
    var keyName: String?
    var description: String?
    var keySlotNamePrefix: String?
    var ksi: String?
    var `protocol`: String?
    var hsm: String?
    var derivedKeyType: String?
    var keyTypeRestrictionBitmask: String?
    var dukptDataTypeRestrictionBitmask: String?
    var dateCreated: String
    var dateModified: String
}

extension KeyInfo {
    var keyInfo: String {
        let keyName = keyName ?? "NA"
        let description = description ?? "NA"
        let keySlotNamePrefix = keySlotNamePrefix ?? "NA"
        let ksi = ksi ?? "NA"
        let usingProtocol = `protocol` ?? "NA"
        let hsm = hsm ?? "NA"
        let derivedKeyType = derivedKeyType ?? "NA"
        let keyTypeRestrictionBitmask = keyTypeRestrictionBitmask ?? "NA"
        let dukptDataTypeRestrictionBitmask = dukptDataTypeRestrictionBitmask ?? "NA"
        
        return "id: \(id), keyName: \(keyName), description: \(description), keySlotNamePrefix: \(keySlotNamePrefix), ksi: \(ksi), usingProtocol: \(usingProtocol), hsm: \(hsm), derivedKeyType: \(derivedKeyType), keyTypeRestrictionBitmask: \(keyTypeRestrictionBitmask), dukptDataTypeRestrictionBitmask: \(dukptDataTypeRestrictionBitmask), dateCreated: \(dateCreated), dateModified: \(dateModified)"
    }
}

struct GetKeyListResponse : Codable {
    var magTranID    :String?
    var customerTransactionID    :String?

    var keys : [KeyInfo]?
}

struct TransformEMVConfigRequest: Codable {
    let `protocol`: String
    let fileBase64: String
    let isLegacyExcel: Bool
    
    init(_ fileData: Data, _ isLegacy: Bool = false) {
        self.protocol = "MMS"
        self.isLegacyExcel = isLegacy
        self.fileBase64 = fileData.base64EncodedString()
    }
}

extension TransformEMVConfigRequest: CustomStringConvertible {
    var description: String {
        return "{ protocol: \(self.protocol),\nisLegacyExcel: \(self.isLegacyExcel),\nfileBase64: \(self.fileBase64) }\n"
    }
}

struct EMVConfigBin : Codable{
    let configId : String?
    let hashId : String?
    let timeStamp : String?
    let config : String?
}

struct TransformEMVConfigResponse : Codable{
    let magTranID : String?
    let customerTransactionID  :  String?
    let configName :String?
    let version   : String?
    let bins : [EMVConfigBin]?
}

struct KeyTokenRequest : Codable {
    let `protocol`: String
    let productName: String
    let keyDerivationData: String
    let keyRestriction: String
    let transportKeyID: String
    let deviceChallenge: String
    let deviceSN: String
    let keySlotID: String
    let currentKSN: String
    let targetKSI: String
}

struct KeyTokenResponse : Codable {
    let magTranID: String?
    let customerTransactionID: String?
    let updateToken: String?
    let isRawCommand: Bool?
    let code : String?
    let message : String?
}

// HTTP Network Client
class RS3Client {
    
    let auth: Authentication
    let billing = "123456"
    //let url = "https://devgw.magensa.dev/RemoteServicesV3/"  // DEV URL
    let url = "https://rsgw.magensa.net/rs3/"  // Prod URL
    
    var onError: (_ errorInfo: String) -> Void = { info in }
    
    init(_ username: String, _ password: String, _ customerId: String) {
        auth = Authentication(username, password, customerId)
    }
    
    func get<RequestType:Encodable, ResponseType :Decodable> (_ type:ResponseType.Type, _ resource : String, _ request :RequestType, _ completeHandler : @escaping(_ success : Bool, _ response : ResponseType?) -> ()) {
        
        do
        {
            let requestParam = try KeyValueStringEncoder().encode(request)
            let fullurl = url + resource + "?" + requestParam
            fullurl.get(auth: auth.toString()) {
                data, success in
                if (success) {
                    do
                    {
                        let obj = try JSONDecoder().decode(ResponseType.self, from: data!)
                        completeHandler(true, obj)
                    }catch {
                        completeHandler(false, nil)
                    }
                } else {
                    completeHandler(false, nil)
                }
            }
        }
        catch
        {
            completeHandler(false, nil)
        }
    }
    
    func get<ResponseType: Decodable>(
        _ type: ResponseType.Type,
        _ resource: String,
        _ completionHandler: @escaping (_ success: Bool, _ response: ResponseType?) -> Void
    ) {
        let fullURL = url + resource
#if DEBUG
        print("Get full URL: \(fullURL)")
#endif
        fullURL.get(auth: auth.toString()) { data, success in
            guard success == true, data != nil else {
                completionHandler(false, nil)
                return
            }
            
            do
            {
                let obj = try JSONDecoder().decode(ResponseType.self, from: data!)
                completionHandler(true, obj)
            } catch {
                completionHandler(false, nil)
            }
        }
    }
    
    func post<RequestType: Encodable, ResponseType: Decodable>(
        _ type: ResponseType.Type,
        _ urlString: String,
        _ request: RequestType,
        _ completionHandler: @escaping (_ success: Bool, _ response: ResponseType?) -> Void
    ) {
        do {
            let data = try JSONEncoder().encode(request)
            // encoder.dataEncodingStrategy = .base64  // by default, same with .deferredToData // 1/5 failed, 4/5 ok
            
#if DEBUG
            print("The request object:\n\(request)")
            
//            // This output string no escaping characters, like /JmWPGqz0kvgcjo94yb4Ar5MyqDB5rNvsNAPrlTf1/
//            let dataToModel = try JSONDecoder().decode(TransformEMVConfigRequest.self, from: data)
//            print("JSON decode Data To Model:\n\(dataToModel)")
//            
//            // This output string with escaping characters, like \/JmWPGqz0kvgcjo94yb4Ar5MyqDB5rNvsNAPrlTf1\/
//            let allDataString = String(data: data, encoding: .utf8)
//            print("Post request data to server:\n\(allDataString ?? "NA")")
            
//            if let splits = allDataString?.split(withMaxLen: 4096) {
//                for slice in splits { print(slice) }
//            }
#endif
            data.postJsonTo(url: urlString, auth: auth.toString(), completionHandler: { data, success in
                guard success else {
                    self.onError("Failed to post request to URL: \(urlString)")
                    completionHandler(false, nil)
                    return
                }
                
                do {
                    let obj = try JSONDecoder().decode(ResponseType.self, from: data!)
                    completionHandler(true, obj)
                } catch {
#if DEBUG
                    print ("Decoding data error: \(error.localizedDescription)")
#endif
                    self.onError(error.localizedDescription)
                    completionHandler(false, nil)
                }
            })
        } catch {
            self.onError("get exception in post request: \(error)")
            completionHandler(false, nil)
        }
    }
    
    func getKey(_ completionHandler: @escaping (_ keys: [KeyInfo]?) -> Void) {
        get(GetKeyListResponse.self, "api/Key") { success, response in
            guard success == true, let response = response else {
                completionHandler(nil)
                return
            }
            
            completionHandler(response.keys)
        }
    }
    
    func transform(
        _ fileData: Data,
        _ completionHandler: @escaping (_ bins: [EMVConfigBin]?) -> Void
    ) {
        let urlString = self.url + "api/EmvConfig/transform"
#if DEBUG
        print("Full URL String: \(urlString)")
#endif
        post(TransformEMVConfigResponse.self, urlString, TransformEMVConfigRequest(fileData)) { success, response in
            guard success else {
                completionHandler(nil)
                return
            }
            
            guard let bins = response?.bins else {
                completionHandler(nil)
                return
            }
            
            completionHandler(bins)
        }
    }
    
    func getKeyToken(
        _ targetSlot: String,
        _ key: KeyInfo,
        _ transportKeyInfo: [String: String],
        _ challenge: String,
        _ ksn: String,
        _ completionHandler: @escaping (_ token: String?) -> Void
    ) {
        let keyRequest = KeyTokenRequest(
            protocol: "MMS",
            productName: "DYNAFLEX",
            keyDerivationData: transportKeyInfo["derivationData"]!,
            keyRestriction: key.dukptDataTypeRestrictionBitmask!,
            transportKeyID: transportKeyInfo["keyID"]!,
            deviceChallenge: challenge,
            deviceSN: ksn,
            keySlotID: targetSlot,
            currentKSN: key.ksi! + ksn + "E00000",
            targetKSI: key.ksi!
        )
        
        let fullURL = "\(url)api/Key/token"
        post(KeyTokenResponse.self, fullURL, keyRequest) { [weak self] success, response in
            guard let weakSelf = self else { return }
            
            guard success else {
                weakSelf.onError("failed to call api -> api/Key/token ")
                completionHandler(nil)
                return
            }
            
            guard let response = response,
                  let token = response.updateToken else {
                let code = response?.code ?? ""
                let message = response?.message ?? ""
                weakSelf.onError("api/Key/token failed - \(code), \(message)")
                completionHandler(nil)
                return
            }
            
            completionHandler(token)
        }
    }
    
}
