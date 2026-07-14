//
//  MQTTSettingsViewController.swift
//  MTUSDK_Sample
//
//  Created by Yong Guo on 3/31/25.
//

import Foundation
import CoreData
import UIKit
import MTUSDK

struct MQTTSettings {
    static let mosquittoUrl = "test.mosquitto.org:1883"
    static let emqxUrl = "broker.emqx.io:1883"
    
    var brokerUrl : String
    var brokerUsername : String
    var brokerPassword : String
    var clientId : String
    var subscribeTopic : String
    var publishTopic : String
    var clientCertificate : String?
    var clientCertificatePassword : String?
    
    static var shared : MQTTSettings =  {
        let uuid = UIDevice.current.identifierForVendor?.uuidString ?? "Unknown"
        var settings = MQTTSettings(brokerUrl: "",
                            brokerUsername: "",
                            brokerPassword: "",
                            clientId: "MTUSample-" + uuid,
                            subscribeTopic: "MagTek/Server/DynaFlexIIPED",
                            publishTopic: "MagTek/Device/DynaFlexIIPED",
                            clientCertificate: nil,
                            clientCertificatePassword: nil)
        settings.load()
        return settings
    }()
    
    public mutating func load() {
        /* do not load saving -- SII-2448
        if let saved = UserDefaults.standard.dictionary(forKey: "mqttSettings") {
            if let url = saved["brokerUrl"] as? String { self.brokerUrl = url }
            if let username = saved["brokerUsername"] as? String { self.brokerUsername = username }
            if let password = saved["brokerPassword"] as? String { self.brokerPassword = password }
            if let clientId = saved["clientId"] as? String { self.clientId = clientId }
            if let subscribeTopic = saved["subscribeTopic"] as? String { self.subscribeTopic = subscribeTopic }
            if let publishTopic = saved["publishTopic"] as? String { self.publishTopic = publishTopic }
            if let clientCertificate = saved["clientCertificate"] as? String { self.clientCertificate = clientCertificate } else {
                self.clientCertificate = nil
            }
            if let clientCertificatePassword = saved["clientCertificatePassword"] as? String { self.clientCertificatePassword = clientCertificatePassword } else {
                self.clientCertificatePassword = nil
            }
        }
         */
    }
    
    public func save() {
        /* do not save SII-2448
        var settings : [String : String] = [:]
        settings["brokerUrl"] = self.brokerUrl
        settings["brokerUsername"] = self.brokerUsername
        settings["brokerPassword"] = self.brokerPassword
        settings["clientId"] = self.clientId
        settings["subscribeTopic"] = self.subscribeTopic
        settings["publishTopic"] = self.publishTopic
        if let cert = self.clientCertificate {
            settings["clientCertificate"] = cert
        }
        if let password = self.clientCertificatePassword {
            settings["clientCertificatePassword"] = password
        }
        
        UserDefaults.standard.setValue(settings, forKey: "mqttSettings")
        */
        
        // setup()
    }
    
    public func setup() {
        CoreAPI.setMQTTBrokerInfo(self.brokerUrl, username: self.brokerUsername, password: self.brokerPassword)
        CoreAPI.setMQTTClientID(self.clientId)
        CoreAPI.setMQTTSubscribeTopic(self.subscribeTopic)
        CoreAPI.setMQTTPublishTopic(self.publishTopic)
        
        let encodedData = Data(base64Encoded: self.clientCertificate ?? "")
        
        let certificate : CertificateInfo = CertificateInfo(format: "PKCS12", data: encodedData ?? Data(), password: self.clientCertificatePassword ?? "")
        CoreAPI.setMQTTCientCertificateInfo(certificate)
    }
}

class MQTTSettingsViewController : UIViewController {
    
    @IBOutlet weak var brokerUrlTextField: UITextField!
    @IBOutlet weak var brokerUsernameTextField: UITextField!
    @IBOutlet weak var brokerPasswordTextField: UITextField!
    @IBOutlet weak var clientIdTextField: UITextField!
    @IBOutlet weak var subscribeTopicTextField: UITextField!
    @IBOutlet weak var publishTopicTextField: UITextField!
    @IBOutlet weak var clientCertificateTextField: UITextField!
    @IBOutlet weak var clientCertificatePasswordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        brokerUrlTextField.text = MQTTSettings.shared.brokerUrl
        brokerUsernameTextField.text = MQTTSettings.shared.brokerUsername
        brokerPasswordTextField.text = MQTTSettings.shared.brokerPassword
        clientIdTextField.text = MQTTSettings.shared.clientId
        subscribeTopicTextField.text = MQTTSettings.shared.subscribeTopic
        publishTopicTextField.text = MQTTSettings.shared.publishTopic
        clientCertificateTextField.text = MQTTSettings.shared.clientCertificate
        clientCertificatePasswordTextField.text = MQTTSettings.shared.clientCertificatePassword
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(done))
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    @objc func done() {
        MQTTSettings.shared.brokerUrl = brokerUrlTextField.text ?? ""
        MQTTSettings.shared.brokerUsername = brokerUsernameTextField.text ?? ""
        MQTTSettings.shared.brokerPassword = brokerPasswordTextField.text ?? ""
        MQTTSettings.shared.publishTopic = publishTopicTextField.text ?? ""
        MQTTSettings.shared.subscribeTopic = subscribeTopicTextField.text ?? ""
        MQTTSettings.shared.clientId = clientIdTextField.text ?? ""
        
        MQTTSettings.shared.clientCertificate = clientCertificateTextField.text ?? nil
        MQTTSettings.shared.clientCertificatePassword = clientCertificatePasswordTextField.text ?? nil
        
        MQTTSettings.shared.save()
        
        //self.dismiss(animated: true, completion: nil)
        self.navigationController?.popViewController(animated: true)
    }
    
    func pickFile(_ complete: @escaping (_ success: Bool, _ data: Data?) -> Void) {
        let picker = FilePickerViewController { success, data in
            if success {
                complete(true, data)
            } else {
                complete(false, nil)
            }
        }
        
        picker.delegate = picker
        present(picker, animated: true, completion: nil)
    }
    
    @IBAction
    @objc func loadCertificateFromP12File() {
        pickFile {success,data in 
            if (success) {
                self.clientCertificateTextField.text = data!.base64EncodedString()
            } else
            {
            }
        }
    }
    
}
