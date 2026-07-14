//
//  Constants.swift
//  Test_Constants_Struct
//
//  Created by Marijan Vukcevich on 1/27/16.
//  Copyright © 2016 MagTek. All rights reserved.
//

import UIKit
import Foundation
import SwiftUI
import MTUSDK

@available(iOS 13.0, *)

extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}

extension UIColor {
    
    class func colorWhiteAlpha(_ whiteColor: CGFloat, alphaValue: CGFloat) -> UIColor {
        return UIColor(white: whiteColor, alpha: alphaValue)
    }
    
    class func colorWithR(_ redColor: CGFloat, greenColor: CGFloat, blueColor: CGFloat, alphaValue: CGFloat) -> UIColor {
        return UIColor(red: (redColor/255.0), green: (greenColor/255.0), blue: (blueColor/255.0), alpha: alphaValue)
    }
    
    class func colorWithRGBA(_ redColor: CGFloat, greenColor: CGFloat, blueColor: CGFloat, alphaValue: CGFloat) -> UIColor {
        return UIColor(red: redColor, green: greenColor, blue: blueColor, alpha: alphaValue)
    }
    
    class func colorWithRGB(_ redColor: Int, greenColor: Int, blueColor: Int) -> UIColor {
        
        let redFloat = CGFloat(redColor)/255
        let greenFloat = CGFloat(greenColor)/255
        let blueFloat = CGFloat(blueColor)/255
        
        return UIColor(red: redFloat, green: greenFloat, blue: blueFloat, alpha: 1.0)
    }
    
}

@available(iOS 13.0, *)
extension CGColor {
    class func colorWithHex(_ hex: Int) -> CGColor {
        return UIColor(hex: hex).cgColor
    }
    class func colorWhiteAlpha(_ whiteColor: CGFloat, alphaValue: CGFloat) -> CGColor {
        return UIColor(white: whiteColor, alpha: alphaValue).cgColor
    }
    class func colorWithR(_ redColor: CGFloat, greenColor: CGFloat, blueColor: CGFloat, alphaValue: CGFloat) -> CGColor {
        return UIColor(red: (redColor/255.0), green: (greenColor/255.0), blue: (blueColor/255.0), alpha: alphaValue).cgColor
    }
    class func colorWithRGBA(_ redColor: CGFloat, greenColor: CGFloat, blueColor: CGFloat, alphaValue: CGFloat) -> CGColor {
        return UIColor(red: redColor, green: greenColor, blue: blueColor, alpha: alphaValue).cgColor
    }
    class func colorWithRGB(_ redColor: Int, greenColor: Int, blueColor: Int) -> CGColor {
        return UIColor.colorWithRGB(redColor, greenColor: greenColor, blueColor: blueColor).cgColor
    }
}


@objc extension NSString
{
    func generateQRCode() -> UIImage? {
        let data = self.data(using: 1, allowLossyConversion: false)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            
            if let output = filter.outputImage?.transformed(by: transform) {
                return UIImage(ciImage: output)
            }
        }
        
        return nil
    }
}

extension String
{
    func generateQRCode() -> UIImage? {
        let data = self.data(using:.ascii, allowLossyConversion: false)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            
            if let output = filter.outputImage?.transformed(by: transform) {
                return UIImage(ciImage: output)
            }
        }
        
        return nil
    }
    
    func protocolCheck(_ iPAddress: String) -> Bool {
        let pattern = "(\(iPAddress)?)://"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(
            in: self,
            options: [],
            range: NSRange(
                location: 0,
                length: Array(self).count
            )
        )
        
        return matches.count > 0
    }
    
    func subString(_ from: Int, _ to: Int) ->String? {
        let from = self.index(self.startIndex, offsetBy: from)
        let end = self.index(self.startIndex, offsetBy: to)
        let range = from..<end
         
        let subStr = String(self[range])
        
        return subStr
    }
}

//Swift -
//Usage: Constant.kAppGreenColor
@available(iOS 13.0, *)
struct Constant {
    
    //Fonts Name - Family
    static let kFontRegular = "HelveticaNeue-Thin"
    static let kFontLight = "HelveticaNeue-Light";
    static let kFontUltraLight = "HelveticaNeue-UltraLight";
    
    
    static var kClearPreset:   UIColor { return UIColor.clear }
    static var kWhitePreset:   UIColor { return UIColor.white }
    static var kGrayPreset:   UIColor { return UIColor.gray }
    static var kLightGrayPreset:   UIColor { return UIColor.lightGray }
    static var kDarkGrayPreset:   UIColor { return UIColor.darkGray }
    static var kBlackPreset:   UIColor { return UIColor.black }
    static var kRedPreset:     UIColor { return UIColor.red }
    static var kBluePreset:    UIColor { return UIColor.blue }
    static var kGreenPreset:    UIColor { return UIColor.green }
    
    //ViewController.swift
    static var kViewBkgColor:   UIColor { return UIColor(hex:0xF8F8F8) } //QPAdminController.swift //QPSalesController.swift //QPTransSummary.swift //QPPasscodeController.swift
    static var kTableCellTextColor:   UIColor { return UIColor(hex:0x514545) }
    
    //QPLoginController.swift
    static var kFormColor:   UIColor { return UIColor(hex:0xCC3333) }
    static var kQPLoginViewBkgColor:   UIColor { return UIColor(hex:0xffffff) }
    static var kQPTextFieldTintColor:   UIColor { return UIColor(hex:0xCC3333) }
    
    //QPAdminController.swift
    static var kDemoViewBkgColor:   UIColor { return UIColor(hex:0x494545) }
    static var kDemoSwitchThumbTintColor:   UIColor { return UIColor(hex:0x828283) }
    static var kDemoSwitchBkgColor:   UIColor { return UIColor(hex:0xDFDFDF) }
    static var kFooterLabelColor:   UIColor { return UIColor(hex:0xb2b2b2) }
    static var kAnimDemoSwitchThumbTintColor:   UIColor { return UIColor(hex:0xFF9900) }
    static var kAnimDemoSwitchBkgColor:   UIColor { return UIColor(hex:0xFFFFFF) }
    static var kAnimDemoSwitchTintColor:   UIColor { return UIColor(hex:0xFFFFFF) }
    static var kDemoPromptWarningTitleColor:   UIColor { return UIColor(hex:0xcc3333) }

    
    //QPSalesController.swift
    static var kItemAttributeColor:   UIColor { return UIColor(hex:0xCD5D65) }  //QPCardInputOptionController.swift //QPTransSummary.swift //QPTransResult.swift //QPQwickCodeController.swift
    
    //QPCardInputOptionController.swift
    static var kQPCardInputViewBkgColor:   UIColor { return UIColor(hex:0xDFDFDF) }
    static var kTitleAttributeColor:   UIColor { return UIColor(hex:0xCC3333) }
    static var kQPHeaderLabelColor:  UIColor { return UIColor(hex:0x494545) }
    
    //QPTransSummary.swift
    static var kQPTransLabelColor:  UIColor { return UIColor(hex:0x494545) }
    static var kQPTransSegmentTintColor:  UIColor { return UIColor(hex:0x494545) }
    static var kBorderCGColor: CGColor { return CGColor.colorWithHex(0xCCCCCC) }
    static var kQPTransSubViewBkgColor:  UIColor { return UIColor(hex:0x494545) }
    static var kQPOnSwitchThumbTintColor:   UIColor { return UIColor(hex:0xFF9900) }
    static var kQPOnSwitchBkgColor:   UIColor { return UIColor(hex:0xFFFFFF) }
    static var kQPOnSwitchOnTintColor:   UIColor { return UIColor(hex:0xFFFFFF) }
    static var kQPOffSwitchThumbTintColor:   UIColor { return UIColor(hex:0x828283) }
    static var kQPOffSwitchBkgColor:   UIColor { return UIColor(hex:0xDFDFDF) }
    
    
    //QPTransResult.swift
    static var kQPTransResultViewBkgColor:   UIColor { return UIColor(hex:0xDFDFDF) }
    static var kQPTransResultReceiptBkgColor:   UIColor { return UIColor(hex:0x09A275) }
    static var kClearUIButtonBkgColor:   UIColor { return UIColor(hex:0xCC3333) }
    static var kShareUIButtonBkgColor:   UIColor { return UIColor(hex:0xE19049) }
    static var kDoneUIButtonBkgColor:   UIColor { return UIColor(hex:0x09A275) }
    
    static var kNavBarTintColor:   UIColor { return UIColor(hex:0xffffff) }    //QPTransHistoryItem.m
    static var kNavBarBarTintColor:   UIColor { return UIColor(hex:0x514545) } //QPTransHistoryItem.m
   
    //QPTransHistory.swift
    static var kQPTransHistoryViewBkgColor:   UIColor { return UIColor(hex:0xDFDFDF) }
    static var kSearchBarBkgColor:   UIColor { return UIColor(hex:0x494545) }    //QPVoidTransaction.swift  //QPRefundTransaction.swift
    static var kFilterViewBkgColor:   UIColor { return UIColor(hex:0x494545) }
    static var kTextFieldTextColor:   UIColor { return UIColor(hex:0xFFFFFF) }   //QPVoidTransaction.swift  //QPRefundTransaction.swift
    static var kSegmentTintColor:   UIColor { return UIColor(hex:0xFFFFFF) }
    static var kTableCellLabelTextColor:   UIColor { return UIColor(hex:0xCC3333) }
    static var kTableCellLabelBorderCGColor: CGColor { return CGColor.colorWithHex(0xCC3333) }
    static var kVorRLabelTextColor: UIColor { return UIColor(hex:0xFFFFFF) }
    static var kVorRLabelBorderCGColor: CGColor { return CGColor.colorWithHex(0xCC3333) }
    static var kVorRLabelLayerBkgCGColor: CGColor { return CGColor.colorWithHex(0xCC3333) }
    static var kCancelBtnAttributeColor: UIColor { return UIColor(hex:0xFFFFFF) }    //QPVoidTransaction.swift  //QPRefundTransaction.swift //QPQwickCodeController.swift
    
    //QPTransHistoryItem.m
    static var kQPTransHistoryItemViewBkgColor:   UIColor { return UIColor(hex:0xDFDFDF) }
    static var kInfoViewBkgColor: UIColor { return UIColor(hex:0x494545) }
    static var kNavBariPADTintColor:   UIColor { return UIColor(hex:0xCC3333) }
    static var kTableHeaderLabelColor:   UIColor { return UIColor(hex:0xbb1337) }
    
    //QPVoidTransaction.swift
    static var kQPVoidTransViewBkgColor:   UIColor { return UIColor(hex:0xDFDFDF) }
    static var kTableCellTextFieldTextColor:   UIColor { return UIColor(hex:0xCC3333) } //QPRefundTransaction.swift
    static var kLeftBorderCGColor: CGColor { return CGColor.colorWithHex(0xCCCCCC) }
    static var kTableCellDefaultTextColor:   UIColor { return UIColor(hex:0xCC3333) }
   
    //QPRefundTransaction.swift
    static var kQPRefundTransViewBkgColor:   UIColor { return UIColor(hex:0xDFDFDF) }
    
    //QPQwickCodeController.swift
    static var kQPQwickCodeViewBkgColor:   UIColor { return UIColor(hex:0xDFDFDF) }
    static var kQPQwickCodeTextFieldTextColor:   UIColor { return UIColor(hex:0xcc3333) }
  
    
    //QPPasscodeController.swift
    static var kQPPassTableCellTextColor:   UIColor { return UIColor(hex:0xCCCCCC) }
    
    
    //MPScore - Colors
    static var kMPScorePlus35Color: UIColor { return UIColor(hex:0x089B8B) }
    static var kMPScoreMinus35Color: UIColor { return UIColor(hex:0xCF4647) }
    static var kMPScoreNotNumColor: UIColor { return UIColor(hex:0x0080C9) }
    
    //MTDatePicker
    static var kMTDatePickerTintColor:   UIColor { return UIColor(hex:0xCC3333) }

    
    //MTCustomButton
    static var kMTBtnTransInitBkgColor:  UIColor { return UIColor(hex:0x828283) }
    static var kMTBtnTransHighlightColor:  UIColor { return UIColor(hex:0xDFDFDF) }
    static var kMTBtnContinueInitBkgColor: UIColor { return UIColor(hex:0x089B8B) }
    static var kMTBtnContinueInvoiceBkgColor : UIColor {return UIColor(hex: 0x6c5ce7)}
    
    static var kMTCustomBtnBorderCGColor: CGColor { return CGColor.colorWithHex(0x828283) }
    static var kMTBtnContinueBorderCGColor: CGColor { return CGColor.colorWithHex(0x089B8B) }
    static var kMTBtnTitleColor:  UIColor { return UIColor(hex:0xFFFFFF) }                      //QPVoidTransaction.swift //QPQwickCodeController.swift(Process Transaction)
    
    static var kMTBtnContactBkgColor:  UIColor { return UIColor(hex:0x29ABA4) }
    static var kMTBtnContactBorderCGColor:  CGColor { return CGColor.colorWithHex(0x29ABA4) }
    static var kMTBtnTransBkgColor:  UIColor { return UIColor(hex:0x29ABA4) }
    static var kMTBtnTransBorderCGColor:  CGColor { return CGColor.colorWithHex(0x29ABA4) }
    
    //Void
    static var kMTBtnVoidBorderCGColor: CGColor { return CGColor.colorWithHex(0xCC3333) }
    static var kMTBtnVoidBkgColor:  UIColor { return UIColor(hex:0xCC3333) }
    static var kMTBtnVoidHighlightColor:  UIColor { return UIColor(hex:0xCD5D65) }
    //Refund
    static var kMTBtnRefundBorderCGColor: CGColor { return CGColor.colorWithHex(0xCC3333) }
    static var kMTBtnRefundBkgColor:  UIColor { return UIColor(hex:0xCC3333) }
    static var kMTBtnRefundHighlightColor:  UIColor { return UIColor(hex:0xCD5D65) }
    
    //Process Transaction - Button - QPQwickCodeController
    static var kMTBtnProcessBorderCGColor: CGColor { return CGColor.colorWithHex(0xCC3333) }
    static var kMTBtnProcessBkgColor:  UIColor { return UIColor(hex:0x3465AA) }
    static var kMTBtnProcessHighlightColor:  UIColor { return UIColor(hex:0x88BCE2) }
   
    
    //MTInfoView - mutableString
    static var kMutableStringAttributeColor:   UIColor { return UIColor(hex:0xCC3333) }
    static var kAttributeColorRed:   UIColor { return UIColor(hex:0xff0000) }
    
    //For MTLockScreenView
    static var kLockScreenBkgColor:   UIColor { return UIColor(hex:0xF8F8F8) }
    static var kLockScreenLabelColor:   UIColor { return UIColor(hex:0xcc3333) }
    static var kLockBtnBkgColor:   UIColor { return kClearPreset }
    static var kLockBtnBorderColor:   UIColor { return UIColor(hex:0xcc3333) }
    static var kLockBtnTextColor:   UIColor { return UIColor(hex:0xcc3333) }
    static var kLockBtnSelectedColor:   UIColor { return UIColor(hex:0xcc3333) }
    static var kPinSelectSelectedColor:   UIColor { return UIColor(hex:0xcc3333) }
    
    
    //MTSettings.m
    static var kHeaderTextColor:   UIColor { return UIColor(hex:0xFFFFFF) }
    static var kHeaderViewBkgColor:   UIColor { return UIColor(hex:0xcc3333) }
    static var kCellTextColor:   UIColor { return UIColor(hex:0x333333) }
    static var kPromptForTipTextColor: UIColor {
        return UIColor.colorWithR(0.22, greenColor: 0.33, blueColor: 0.53, alphaValue: 1.0)
    }

    
    //For MTDropDown init:
    static var kDropDownDefaultBkgColor:   UIColor { return UIColor(hex:0xCD5D65) }
    static var kDropDownBkgColor:   UIColor { return UIColor(hex:0x3399CC) }
    static var kDropDownPrinterBkgColor:   UIColor { return UIColor(hex:0xCD5D65) }
    static var kDropDownPrintCompleteBkgColor:   UIColor { return UIColor(hex:0x3399CC) }
    static var kDropDownPrintErrorBkgColor:   UIColor { return UIColor(hex:0xCD5D65) }
    static var kDropDownCashDrawerBkgColor:   UIColor { return UIColor(hex:0x16A085) }
    static var kDropDownStarPrinterBkgColor:   UIColor { return UIColor(hex:0xcc3333) }
    static var kDropDownSwipeTimedOutBkgColor:   UIColor { return UIColor(hex:0xFF9900) }
    static var kDropDownConnectionErrorBkgColor:   UIColor { return UIColor(hex:0xCD5D65) }
    
    
    
    //For MTPickerView init:
    static var kPickerViewBkgColor:   UIColor { return UIColor(hex:0xECECEC) }
    static var kPickerViewTextColor:   UIColor { return UIColor(hex:0xcc3333) }
    static var kPickerViewToolBarColor:   UIColor { return UIColor(hex:0xcc3333) }
    static var kPickerViewButtonColor:   UIColor { return UIColor(hex:0xffffff) }
    
    //For MTAlertViewButtonItem init:
    static var kAlertViewTitleAttributeColor:   UIColor { return UIColor(hex:0xCC3333) }
    static var kAlertViewBtnYesBkgColor:   UIColor { return UIColor(hex:0x009966) }
    static var kAlertViewBtnNoBkgColor:   UIColor { return UIColor(hex:0xCC3333) }
    static var kAlertViewBtnContinueBkgColor:   UIColor { return UIColor(hex:0x009966) }
    static var kAlertViewBtnCancelBkgColor:   UIColor { return UIColor(hex:0xCC3333) }
    static var kAlertViewBtnCustomBkgColor:   UIColor { return UIColor(hex:0x6E9ECF) }
    static var kAlertViewBtnProceedBkgColor:   UIColor { return UIColor(hex:0x6E9ECF) }
    static var kAlertViewBtnSMSBkgColor:   UIColor { return UIColor(hex:0x6E9ECF) }
    static var kAlertViewBtnEmailBkgColor:   UIColor { return UIColor(hex:0x6E9ECF) }
    static var kAlertViewBtnPrintBkgColor:   UIColor { return UIColor(hex:0x6E9ECF) }
    static var kAlertViewDipBkgColor:   UIColor { return UIColor(hex:0x6E9ECF) }
    static var kAlertViewReceiptBtnBkgColor:   UIColor { return UIColor(hex:0x6E9ECF) }

    
    /*Do not use: Old copy for reference only howto --*/
    //static var kOverlayGray: UIColor { return UIColor.colorWhiteAlpha(0.0, alphaValue: 0.3961) }
    //static var kSomeTestColor: UIColor { return UIColor.colorWithRGBA(255.0, greenColor: 0.0, blueColor: 0.0, alphaValue: 1.0) }
    //static var kSomeTestTwoColor: UIColor { return UIColor.colorWithRGB(255, greenColor: 0, blueColor: 0) }
    //static var kLineRedCGColor:  CGColor { return CGColor.colorWithHex(0xFF0000) }
    //static var kLineGrayCGColor: CGColor { return CGColor.colorWithRGB(128, greenColor: 128, blueColor: 128) }
    //static var kLineRedCGColor:  CGColor { return CGColor.colorWithRGBA(255.0, greenColor: 0.0, blueColor: 0.0, alphaValue: 1.0) }
    
    static var isIpad = UIDevice.current.userInterfaceIdiom == .pad ? true : false
    static var amountTenderSize = isIpad == true ? CGFloat(UIScreen.main.bounds.width-150)/4 : 150
        
    static var kioskPinViewWidth = isIpad == true ? 600 : CGFloat(UIScreen.main.bounds.width)
        //CGFloat(UIScreen.main.bounds.width-20)/2
    static var kioskPinViewHeight = isIpad == true ? 600 : CGFloat(UIScreen.main.bounds.height)

    static var kioskPinViewMinWidth = isIpad == true ? 600 : CGFloat(UIScreen.main.bounds.width-20)
    static var kioskPinViewMinHeight = isIpad == true ? 600 : CGFloat(UIScreen.main.bounds.height-120)

    static var amountTenderSpacer : CGFloat = isIpad == true ?CGFloat(25) :  CGFloat(15) //CGFloat(50) :  CGFloat(15)

    static var kamountTenderTitleSize : CGFloat = isIpad == true ?CGFloat(25) :  CGFloat(13)
    static var kamountTenderValueSize : CGFloat = isIpad == true ?CGFloat(50) :  CGFloat(22)
    static var kamountTenderSubTitleSize : CGFloat = isIpad == true ?CGFloat(20) :  CGFloat(10)
    static var kDefaultWidth: CGFloat = isIpad == true ?CGFloat(600) :  CGFloat(UIScreen.main.bounds.width-20)
    static var kDefaultHeight : CGFloat = isIpad == true ?CGFloat(600) :  CGFloat(UIScreen.main.bounds.height)
    static var kCustomAmountHeight : CGFloat = isIpad == true ?CGFloat(800) :  CGFloat(UIScreen.main.bounds.height)
    static var kTitleFont : CGFloat = isIpad == true ?CGFloat(40) :  CGFloat(25)
    static var kSubTitleFont : CGFloat = isIpad == true ?CGFloat(20) :  CGFloat(15)
    static var kStepSignsSize : CGFloat = isIpad == true ?CGFloat(55) :  CGFloat(35)
    
//    static var kQRCodeYposition = isIpad == true ? 15 : ( MTHelperManager.sharedInstance.isSmallFamilyDevice() ? 10 : 30)
//    static var kQRCodeImageWith = isIpad == true ? 270 : ( MTHelperManager.sharedInstance.isSmallFamilyDevice() ? 160 : 260)
//    static var kQRCodeExtraSpace = isIpad == true ? 30 : ( MTHelperManager.sharedInstance.isSmallFamilyDevice() ? 10 : 40)

}


//For Objective-C files - since they can not access Swift - struct
//add this #import "ProjectName-Swift.h"  where you need to use constats in Objective-C
//usage: [Constants appGreenColor];
@available(iOS 13.0, *)
class Constants: NSObject {
    
    fileprivate override init() {}

   @objc class func FontRegular() -> String { return Constant.kFontRegular }
   @objc class func FontLight()     -> String { return Constant.kFontLight }
   @objc class func FontUltraLight()     -> String { return Constant.kFontUltraLight }
    
    
    //UIColor Presets
   @objc class func ClearPreset() -> UIColor { return Constant.kClearPreset }
   @objc class func WhitePreset() -> UIColor { return Constant.kWhitePreset }
   @objc class func GrayPreset() -> UIColor { return Constant.kGrayPreset }
   @objc class func LightGrayPreset() -> UIColor { return Constant.kLightGrayPreset }
   @objc class func DarkGrayPreset() -> UIColor { return Constant.kDarkGrayPreset }
   @objc class func BlackPreset() -> UIColor { return Constant.kBlackPreset }
   @objc class func RedPreset() -> UIColor { return Constant.kRedPreset }
   @objc class func BluePreset() -> UIColor { return Constant.kBluePreset }
   @objc class func GreenPreset() -> UIColor { return Constant.kGreenPreset }
    
    //ViewController.swift
   @objc class func ViewBkgColor()   -> UIColor { return Constant.kViewBkgColor }
   @objc class func TableCellTextColor()   -> UIColor { return Constant.kTableCellTextColor }
    
    //QPLoginController.swift
   @objc class func FormColor()   -> UIColor { return Constant.kFormColor }
   @objc class func QPLoginViewBkgColor()   -> UIColor { return Constant.kQPLoginViewBkgColor }
   @objc class func QPTextFieldTintColor()   -> UIColor { return Constant.kQPTextFieldTintColor }
    
    //QPAdminController.swift
   @objc class func DemoViewBkgColor()   -> UIColor { return Constant.kDemoViewBkgColor }
   @objc class func DemoSwitchThumbTintColor()   -> UIColor { return Constant.kDemoSwitchThumbTintColor }
   @objc class func DemoSwitchBkgColor()   -> UIColor { return Constant.kDemoSwitchBkgColor }
   @objc class func FooterLabelColor()   -> UIColor { return Constant.kFooterLabelColor }
    
   @objc class func AnimDemoSwitchThumbTintColor()   -> UIColor { return Constant.kAnimDemoSwitchThumbTintColor }
   @objc class func AnimDemoSwitchBkgColor()   -> UIColor { return Constant.kAnimDemoSwitchBkgColor }
   @objc class func AnimDemoSwitchTintColor()   -> UIColor { return Constant.kAnimDemoSwitchTintColor }
   @objc class func DemoPromptWarningTitleColor()   -> UIColor { return Constant.kDemoPromptWarningTitleColor }
    
    //QPSalesController.swift
   @objc class func ItemAttributeColor()   -> UIColor { return Constant.kItemAttributeColor }
   
    //QPCardInputOptionController.swift
   @objc class func TitleAttributeColor()   -> UIColor { return Constant.kTitleAttributeColor }
    
    
    //QPTransHistoryItem.m
   @objc class func QPTransHistoryItemViewBkgColor()   -> UIColor { return Constant.kQPTransHistoryItemViewBkgColor }
   @objc class func InfoViewBkgColor()   -> UIColor { return Constant.kInfoViewBkgColor }
   @objc class func NavBarTintColor()   -> UIColor { return Constant.kNavBarTintColor } //SHARED
   @objc class func NavBarBarTintColor()   -> UIColor { return Constant.kNavBarBarTintColor } //SHARED
   @objc class func NavBariPADTintColor()   -> UIColor { return Constant.kNavBariPADTintColor }
   @objc class func TableHeaderLabelColor()   -> UIColor { return Constant.kTableHeaderLabelColor }
    
   
    //MTInfoView - mutableString
   @objc class func MutableStringAttributeColor()   -> UIColor { return Constant.kMutableStringAttributeColor }
    
    //For MTLockScreenView
   @objc class func LockScreenBkgColor()   -> UIColor { return Constant.kLockScreenBkgColor }
   @objc class func LockScreenLabelColor()   -> UIColor { return Constant.kLockScreenLabelColor }
   @objc class func LockBtnBkgColor()   -> UIColor { return Constant.kLockBtnBkgColor }
   @objc class func LockBtnBorderColor()   -> UIColor { return Constant.kLockBtnBorderColor }
   @objc class func LockBtnTextColor()   -> UIColor { return Constant.kLockBtnTextColor }
   @objc class func LockBtnSelectedColor()   -> UIColor { return Constant.kLockBtnSelectedColor }
   @objc class func PinSelectSelectedColor()   -> UIColor { return Constant.kPinSelectSelectedColor }
    
    //MTSettings.m
   @objc class func HeaderTextColor()   -> UIColor { return Constant.kHeaderTextColor }
   @objc class func HeaderViewBkgColor()   -> UIColor { return Constant.kHeaderViewBkgColor }
   @objc class func CellTextColor()   -> UIColor { return Constant.kCellTextColor }
   @objc class func PromptForTipTextColor()   -> UIColor { return Constant.kPromptForTipTextColor }
    
    //For MTDropDown init
   @objc class func DropDownDefaultBkgColor()   -> UIColor { return Constant.kDropDownDefaultBkgColor }
   @objc class func DropDownBkgColor()   -> UIColor { return Constant.kDropDownBkgColor }
   @objc class func DropDownPrinterBkgColor()   -> UIColor { return Constant.kDropDownPrinterBkgColor }
   @objc class func DropDownCashDrawerBkgColor()   -> UIColor { return Constant.kDropDownCashDrawerBkgColor }
   @objc class func DropDownStarPrinterBkgColor()   -> UIColor { return Constant.kDropDownStarPrinterBkgColor }
   @objc class func DropDownSwipeTimedOutBkgColor()   -> UIColor { return Constant.kDropDownSwipeTimedOutBkgColor }
   @objc class func DropDownPrintCompleteBkgColor()   -> UIColor { return Constant.kDropDownPrintCompleteBkgColor }
   @objc class func DropDownPrintErrorBkgColor()   -> UIColor { return Constant.kDropDownPrintErrorBkgColor }
   @objc class func DropDownConnectionErrorBkgColor()   -> UIColor { return Constant.kDropDownConnectionErrorBkgColor }
    
    
    //For MTPickerView init:
   @objc class func PickerViewBkgColor()   -> UIColor { return Constant.kPickerViewBkgColor }
   @objc class func PickerViewTextColor()   -> UIColor { return Constant.kPickerViewTextColor }
   @objc class func PickerViewToolBarColor()   -> UIColor { return Constant.kPickerViewToolBarColor }
   @objc class func PickerViewButtonColor()   -> UIColor { return Constant.kPickerViewButtonColor }
    
    //For MTAlertViewButtonItem init:
   @objc class func AlertViewBtnYesBkgColor()   -> UIColor { return Constant.kAlertViewBtnYesBkgColor }
   @objc class func AlertViewBtnNoBkgColor()   -> UIColor { return Constant.kAlertViewBtnNoBkgColor }
   @objc class func AlertViewBtnContinueBkgColor()   -> UIColor { return Constant.kAlertViewBtnContinueBkgColor }
   @objc class func AlertViewBtnCancelBkgColor()   -> UIColor { return Constant.kAlertViewBtnCancelBkgColor }
   @objc class func AlertViewBtnCustomBkgColor()   -> UIColor { return Constant.kAlertViewBtnCustomBkgColor }
   
   @objc class func AlertViewBtnProceedBkgColor() -> UIColor { return Constant.kAlertViewBtnProceedBkgColor }
   @objc class func AlertViewBtnSMSBkgColor() -> UIColor { return Constant.kAlertViewBtnSMSBkgColor }
   @objc class func AlertViewBtnEmailBkgColor() -> UIColor { return Constant.kAlertViewBtnEmailBkgColor }
   @objc class func AlertViewBtnPrintBkgColor() -> UIColor { return Constant.kAlertViewBtnPrintBkgColor }
   @objc class func AlertViewDipBkgColor() -> UIColor { return Constant.kAlertViewDipBkgColor }
   @objc class func AlertViewReceiptBtnBkgColor() -> UIColor { return Constant.kAlertViewReceiptBtnBkgColor }

}

enum Validate {
    case email(_: String)
    case phoneNum(_: String)
    case carNum(_: String)
    case username(_: String)
    case password(_: String)
    case nickname(_: String)

    case URL(_: String)
    case IP(_: String)
    
    var isRight: Bool {
        var predicateStr:String!
        var currObject:String!
        switch self {
        case let .email(str):
            predicateStr = "^([a-z0-9_\\.-]+)@([\\da-z\\.-]+)\\.([a-z\\.]{2,6})$"
            currObject = str
        case let .phoneNum(str):
            predicateStr = "^((13[0-9])|(15[^4,\\D]) |(17[0,0-9])|(18[0,0-9]))\\d{8}$"
            currObject = str
        case let .carNum(str):
            predicateStr = "^[A-Za-z]{1}[A-Za-z_0-9]{5}$"
            currObject = str
        case let .username(str):
            predicateStr = "^[A-Za-z0-9]{6,20}+$"
            currObject = str
        case let .password(str):
            predicateStr = "^[a-zA-Z0-9]{6,20}+$"
            currObject = str
        case let .nickname(str):
            predicateStr = "^[\\u4e00-\\u9fa5]{4,8}$"
            currObject = str
        case let .URL(str):
            predicateStr = "^(https?:\\/\\/)?([\\da-z\\.-]+)\\.([a-z\\.]{2,6})([\\/\\w \\.-]*)*\\/?$"
            currObject = str
        case let .IP(str):
            predicateStr = "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
            currObject = str
        }

        let predicate =  NSPredicate(format: "SELF MATCHES %@" ,predicateStr)
        return predicate.evaluate(with: currObject)
    }
}

// MARK: - Segue

enum Segue {
    static let unwindToOpenDeviceVCSegue = "UnwindToOpenDeviceVCSegue"
}

// MARK: - Device Connection Type

enum DeviceConnectionType {
    static let kWebSocket = 0
    static let kLightning = 1
    static let kBLE = 2
    static let kMQTT = 3
}

// MARK: - Core Data Entity Attribute Key

enum CoreDataEntityAttributeKey {
    static let ipAddress = "iPAddress"
}

// MARK: - UserDefaults

enum UserDefaultsKey {
    static let currentSelectedConnectionType = "CurrentSelectedConnectionType"
    static let currentAPIRuntimeLogFlagKey = "CurrentTimingLogFlag"
}

// MARK: - MTUConstant

enum MTUConstant {
    
    static let connectDeviceAlertMsg = "Please connect to a reader first before you continue to do an operation."
    static let notSupportedOperation = "The current device does not support this operation!"
    
    static let kBleDeviceNotPairedString = "Device_Not_Paired"
    
    static let kConnectionStateUnknownString = "unknown"
    static let kConnectionStateDisconnectedString = "disconnected"
    static let kConnectionStateConnectingString = "connecting"
    static let kConnectionStateErrorString = "error"
    static let kConnectionStateConnectedString = "connected"
    static let kConnectionStateDisconnectingString = "disconnecting"
    
    
    static let settingsViewStoryboardName = "SettingsView"
    static let settingsViewStoryboardID = "SettingsView"
    
    // Operation names
    static let startTransactionOperationName = "Start Transaction"
    static let transactionStarted = "[Transaction Started]"
    static let transactionTimeout = 30
    static let transactionType = 0
    static let manualStartTransactionOperationName = "Manual Start Transaction"
    static let hostCancelledTransaction = "[Host Cancelled]"
    static let cancelTransactionOperationName = "Cancel Transaction"
    
    static let requestSignatureOperationName = "Request Signature"
    
    static let pinOperationName = "Request PIN"
    static let pinRequestStarted = "[Request PIN Started]"
    static let panOperationName = "Request PAN"
    static let panRequestStarted = "[Request PAN Started]"
    
    static let sendCommandOperationName = "Send Command"
    static let scanBarcodeStarted = "[Scan Barcode Started]"
    static let scanBarcodeOperationName = "Start Scan Barcode"
    static let displayMsgOperationName = "Display Message"
    static let displayMsgStarted = "[Display Message Started]"
    static let showImageOperationName = "Show Image"
    static let showImageStarted = "[Show Image Started]"
    static let deviceResetOperationName = "Device Reset"
    static let deviceResetStarted = "[Device Reset Started]"
    static let setDisplayImageOperationName = "Set Display Image"
    static let setDisplayImageStarted = "[Set Display Image Started]"
    static let getChallengeTokenOperationName = "Get Challenge Token"
    static let getChallengeTokenStarted = "[Get Challenge Token Started]"
    static let getDeviceInfoStarted = "[Get Device Info Started]"
    
    static let sendImageOperationName = "Send Image"
    static let sendImageStarted = "[Send Image Started]"
    static let sendFileOperationName = "Send File"
    static let sendFileStarted = "[Send File Started]"
    static let sendExcelFileStarted = "[Send Excel File Started]"
    static let getFileOperationName = "Get File"
    static let getFileStarted = "[Get File Started]"
    static let updateFirmwareOperationName = "Update Firmware"
    static let updateFirmwareStarted = "[Update Firmware Started]"
    static let startNFCEmulationOperationName = "NFC Card Emulation"
    static let startNFCEmulationStarted = "[NFC Card Emulation Started]"
    static let startBuzzerOperationName = "Play Sound"
    static let startBuzzerStarted = "[Play Sound]"
    static let repairBLEDeviceRequiredMessage = "\n!!! IMPORTANT NOTE !!!\nThe Bluetooth LE Firmware has been updated, you need to go to the Bluetooth Settings to forget the device and then pair the device again manually.\n"
    
    static let waitTheOperationToComplete = "The operation is ongoing, please wait for it to complete!"
    static let noTransactionOngoing = "There is no transaction ongoing."
    
    // EA protocol strings
    static let dynaFlex2GoProtocolString = "com.magtek.dynaflex2go"
    static let dynaproxProtocolString = "com.magtek.dynaprox"
    static let noEAProtocolStrings = "No EA protocol strings supported"
    static let selectEAProtocolStringTitle = "EA protocol strings"
    static let selectEAProtocolStringMsg = "Please select an EA protocol string"
    static let cancelButtonTitle = "Cancel"
    
    static let asciiTimout = "TIMEOUT"
    static let asciiFailed = "FAILED"
    
    static let operationFailed = "operation_failed"
    
    static let codeTimout = "timed_out"
    static let codeHostCancelled = "host_cancelled"
    static let codeTransactionCancelled = "transaction_cancelled"
    static let codeTransactionError = "transaction_error"
    static let codeTransactionDeclined = "transaction_declined"
    static let codeTransactionFailed = "transaction_failed"
    static let codeTryOtherInterface = "try_other_interface"
    
    
    // code to end transaction state machine
    static let codeTransactionExceptionStatusSet: Set<String> = [
        MTUConstant.codeTimout, 
        MTUConstant.codeHostCancelled,
        MTUConstant.codeTransactionCancelled,
        MTUConstant.codeTransactionError, 
        MTUConstant.codeTransactionDeclined,
        MTUConstant.codeTransactionFailed,
        MTUConstant.codeTryOtherInterface,
        NFCEventBuilder.getEventString(MTU_NFCEvent_TagRemoved),
    ]
    
    // Switch USB modes
    static let cmdUSBHIDMode = "AA0081040100D111841BD11181072B06010401F609850101890BE209E207E205E103C20100"
    static let cmdUSBiAP2Mode = "AA0081040100D111841BD11181072B06010401F609850101890BE209E207E205E103C20101"
    static let cmdUSBiAP2WithHIDFallbackMode = "AA0081040100D111841BD11181072B06010401F609850101890BE209E207E205E103C20102"
    static let setUSBModeOperationName = "Set USB Mode:"
    
    static let cmdSetMaskLeading6 = "AA0081040107D111841BD11181072B06010401F609850101890BE109E207E205E103C30106"
    static let cmdSetMaskTrailing4 = "AA0081040109D111841BD11181072B06010401F609850101890BE109E207E205E103C40104"
    static let cmdSetBeepVolume50 = "AA008104010BD111841BD11181072B06010401F609850101890BE209E307E205E103C10132"
    static let cmdGetBatteryLevel = "AA008104010CD101841AD10181072B06010401F609850102890AE308E106E204E102C400"
    
    static let cmdSetUserEventOn = "AA008104010ED111841ED11181072B06010401F609850101890EE20CE70AE108E206C1041F000000"
    static let cmdResetDevice = "AA008104010F1F0184021F01"
    
    static let cmdGetSCDESettings = "AA0081040106D101841AD10181072B06010401F609850101890AE108E206E604E102C100"
    
    // FAQs
    static let faqURL = "https://www.magtek.com/support/dynaflex-ii-go?tab=faq"
    
}
