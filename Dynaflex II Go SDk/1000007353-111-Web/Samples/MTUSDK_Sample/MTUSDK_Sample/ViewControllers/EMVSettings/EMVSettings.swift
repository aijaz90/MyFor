//
//  EMVSettings.swift
//  MTUSDK_Sample
//
//  Created by Yong Guo on 2/25/26.
//

import Foundation
import UIKit


let ECP2FrameDataKey = "ECP2 Frame Data"

public class EMVSettingsViewController :UIViewController, UITableViewDataSource, UITableViewDelegate {
    public static var shared: EMVSettingsViewController = EMVSettingsViewController()
    
    public static var settings : [ String : String] = [ECP2FrameDataKey : "6A02C3020003FFFF" ]
    public static var settingKeys : [String] = []
    
    private var settingTableView : UITableView = UITableView()
    
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "     EMV Settings     "
        label.sizeToFit()
        return label
    }()
    
    public static func getValue(forKey: String) -> String? {
        return EMVSettingsViewController.settings[forKey]
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        EMVSettingsViewController.settingKeys = EMVSettingsViewController.settings.keys.map({$0})
    }
    
    public init () {
        super.init(nibName: nil, bundle: nil)
        EMVSettingsViewController.settingKeys = EMVSettingsViewController.settings.keys.map({$0})
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(titleLabel)
        
        settingTableView.frame = CGRectOffset(self.view.frame, 0, titleLabel.frame.height)
        self.view.addSubview(settingTableView)
        
        settingTableView.dataSource = self
        settingTableView.delegate = self
        settingTableView.register(UITableViewCell.self, forCellReuseIdentifier:  "settingValueCell")
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return EMVSettingsViewController.settingKeys.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "settingValueCell", for: indexPath)
        let label = EMVSettingsViewController.settingKeys[indexPath.row]
        
        var content = UIListContentConfiguration.cell()
        content.text = label
        content.secondaryText = EMVSettingsViewController.settings[label]
        cell.contentConfiguration = content

        return cell
    }
    
    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // edit value for this row
        let label = EMVSettingsViewController.settingKeys[indexPath.row]
        let alert = UIAlertController(title: label, message: "Enter new value", preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.text = EMVSettingsViewController.settings[label]
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            if let textField = alert.textFields?.first, let newValue = textField.text {
                EMVSettingsViewController.settings[label] = newValue
                tableView.reloadRows(at: [indexPath], with: .automatic)
            }
        }
        alert.addAction(saveAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
}
