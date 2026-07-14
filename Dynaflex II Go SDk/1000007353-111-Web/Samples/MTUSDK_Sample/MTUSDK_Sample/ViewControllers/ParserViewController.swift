//
//  ParserViewController.swift
//  MTUSDK_Sample
//
//  Created by Wenbo Ma on 12/2/21.
//

import UIKit

class ParserViewController: UIViewController {
    
    @IBOutlet var TLVInputData: UITextView!
    @IBOutlet var ParsedTLVData: UITextView!
    
    @IBOutlet weak var bottomLayoutConstraint: NSLayoutConstraint?
    
    // MARK: - VC life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { context in
            let keyWindow = UIApplication.shared.mainKeyWindow
            guard let statusBarFrame = keyWindow?.windowScene?.statusBarManager?.statusBarFrame else { return }
            UIApplication.shared.statusBarView?.frame = statusBarFrame
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
    
    // MARK: - Actions
    
    @objc func noticeChangeTextAction(noti: Notification) {
        guard  let userInfo = noti.userInfo else { return }
        
        if let arqcString = userInfo["ARQC"] as? String, arqcString.count > 4 {
            TLVInputData.text = arqcString.subString(4, arqcString.count)
        }
    }
    
    @IBAction func clean() {
        self.TLVInputData!.text = ""
        self.ParsedTLVData!.text = ""
    }
    
    @IBAction func parseTLVInfo() {
        self.ParsedTLVData!.text = ""
        
        if let input = TLVInputData.text {
            let emvBytes = HexUtil.getBytesFromHexString(input)
            let tlv = emvBytes?.parseTLVDataWithNoLength()
            self.ParsedTLVData!.text = tlv?.dumpTags()
            self.scrollTextView(toBottom: self.ParsedTLVData)
        }
    }
    
    func scrollTextView(toBottom textView: UITextView?) {
        let range = NSRange(location: textView?.text.count ?? 0, length: 0)
        textView?.scrollRangeToVisible(range)
        
        textView?.isScrollEnabled = false
        textView?.isScrollEnabled = true
    }
}

// MARK: - Private helpers

private extension ParserViewController {
    
    func setupUI() {
        setupNavigationTitle()
        setupSettingsBarButtonItem()
        ParsedTLVData.isEditable = false
        
        // Handle keyboard show and hide
        if bottomLayoutConstraint != nil {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillShow(_:)),
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillHide(_:)),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(noticeChangeTextAction(noti:)),
            name: NSNotification.Name(rawValue: "SENDARQCORBATCHDATA"),
            object: nil
        )
    }
    
    func setupNavigationTitle() {
        let fgColor = UIColor.white
        let textAttributes = [
            NSAttributedString.Key.foregroundColor: fgColor,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]
        navigationController?.navigationBar.titleTextAttributes = textAttributes
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.backgroundColor = .darkGray
    }
    
    func setupSettingsBarButtonItem() {
        let settingsIcon = UIImage(named: "settings")
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: settingsIcon, style: .plain, target: self, action: #selector(navigateToSettingsView))
    }
    
    @objc func navigateToSettingsView() {
        let settingsViewStoryboard = UIStoryboard(name: MTUConstant.settingsViewStoryboardName, bundle: nil)
        let settingsVC = settingsViewStoryboard.instantiateViewController(withIdentifier: MTUConstant.settingsViewStoryboardID)
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    @objc func keyboardWillShow(_ notification: NSNotification) {
        guard let info = notification.userInfo,
              let keyboardHeight = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height
        else { return }
        
        let animationDuration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.0
        bottomLayoutConstraint?.constant = keyboardHeight
        
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        guard let info = notification.userInfo else { return }
        
        let animationDuration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.0
        bottomLayoutConstraint?.constant = 10.0
        
        UIView.animate(withDuration: animationDuration) {
            self.view.layoutIfNeeded()
        }
    }

}
