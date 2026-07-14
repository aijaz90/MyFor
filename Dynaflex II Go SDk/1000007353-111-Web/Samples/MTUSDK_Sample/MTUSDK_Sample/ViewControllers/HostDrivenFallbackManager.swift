//
//  File.swift
//  MTUSDK_Sample
//

import Foundation
import MTUSDK

public class HostDrivenFallbackManager: NSObject {
    
    // MARK: - Private vars
    
    private var mCardInserted = false
    private var mMSRDetected = false
    private var mChipDetected = false
    private var mChipFailureCount = 0
    
    private var mPendingOnUseChipReader = false
    private var mPendingOnUseMSR = false
    private var mPendingOnTryAgain = false
    private var mPendingOnGetSignature = false
    
    // MARK: - Life cycle
    
    let onUseMSR: () -> Void
    let onUseChipReader: () -> Void
    let onCaptureSignature: () -> Void
    let onTryAgainCallback: () -> Void
    
    init(
        useMsr: @escaping () -> Void,
        useChip: @escaping () -> Void,
        captureSignature: @escaping () -> Void,
        tryAgain: @escaping () -> Void
    ) {
        onUseMSR = useMsr
        onUseChipReader = useChip
        onCaptureSignature = captureSignature
        onTryAgainCallback = tryAgain
    }
    
    // MARK: - Public APIs
    
    func sendOnSignatureCapture() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.onCaptureSignature()
        }
    }
    
    func sendOnMSR() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.onUseMSR()
        }
    }
    
    func sendOnChip() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.onUseChipReader()
        }
    }
    
    func sendOnTryAgain() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.onTryAgainCallback()
        }
    }
    
}

// MARK: - IEventSubscriber

extension HostDrivenFallbackManager: IEventSubscriber {
    
    public func onEvent(_ eventType: MTU_EventType, data: IData!) {
        switch eventType {
        case MTU_EventType_AuthorizationRequest:
            checkCardType(data)
            
        case MTU_EventType_TransactionStatus:
            handleTransactionStatus(data)
            
        case MTU_EventType_TransactionResult:
            break
        default:
            break
        }
    }
    
}

// MARK: - Private helpers

private extension HostDrivenFallbackManager {
    
    func msrFallForwardHandler() {
        guard mChipDetected, mMSRDetected else { return }
        
        if mChipFailureCount < 3 {
            if mCardInserted {
                mPendingOnUseChipReader = true
            } else {
                mChipDetected = false
                mMSRDetected = false
                sendOnChip()
            }
        }
    }
    
    func startOnUseMSR() {
        if mCardInserted {
            mPendingOnUseMSR = true
        } else {
            sendOnMSR()
        }
    }
    
    func technicalOrMSRFallbackHandler() {
        mChipFailureCount += 1
#if DEBUG
        print("Current Chip Failed Times: \(mChipFailureCount)")
#endif
        if mChipFailureCount < 3 {
            if mCardInserted {
                mPendingOnTryAgain = true
            } else {
                sendOnTryAgain()
            }
        }
        else { // After 3 times failed with chip, then fallback to MSR mode
            startOnUseMSR()
        }
    }
    
    func handleTransactionStatus(_ data: IData) {
        let tStatus = TransactionStatusBuilder.getStatusCode(data.stringValue)
#if DEBUG
        print("Current transaction status code: \(data.stringValue), tStatus: \(tStatus)")
#endif
        
        switch tStatus {
        case MTU_TransactionStatus_CardInserted:
            mCardInserted = true
            
        case MTU_TransactionStatus_CardRemoved:
            mCardInserted = false
            
            if mPendingOnUseChipReader {
                mPendingOnUseChipReader = false
                sendOnChip()
            }
            else if mPendingOnUseMSR {
                mPendingOnUseMSR = false
                sendOnMSR()
            }
            else if mPendingOnTryAgain {
                mPendingOnTryAgain = false
                sendOnTryAgain()
            }
            else if mPendingOnGetSignature {
                mPendingOnGetSignature = false
                sendOnSignatureCapture()
            }
            
        case MTU_TransactionStatus_QuickChipDeferred,
             MTU_TransactionStatus_TransactionCompleted,
             MTU_TransactionStatus_TransactionApproved:
            msrFallForwardHandler()
            
        // When got the transaction_not_accepted, no fallback at all
        case MTU_TransactionStatus_TransactionFailed:
            startOnUseMSR()
            
        case MTU_TransactionStatus_TechnicalFallback,
             MTU_TransactionStatus_MSRFallback:
            technicalOrMSRFallbackHandler()
            
        case MTU_TransactionStatus_SignatureCaptureRequested:
            if mCardInserted {
                mPendingOnGetSignature = true
                return
            }
            
            sendOnSignatureCapture()
            
        case MTU_TransactionStatus_ReservedICCOnly:
            // do nothing by far
            break;
            
        default:
            break
        }
    }
    
    // check card with a chip or not
    func checkCardType(_ arqcData: IData) {
        let length = (Int)(arqcData.byteArray[0]) * 256 + (Int)(arqcData.byteArray[1])
        let emvData = arqcData.byteArray.subdata(in: 2..<(2 + length))
        let tlvs = (emvData as NSData).parseTLVDataWithNoLength()
        
        // Get the card type
        if let cardType = tlvs?.getTLV("DFDF52") {
            if cardType.value == "07" {
                // 0x07 = MSR Financial and Contact Chip Card (ICC)
                // means need to do MSR fall forward
                mChipDetected = true
                mMSRDetected = true
            }
            else if cardType.value == "06" || cardType.value == "05" {
                mChipDetected = true
                mMSRDetected = false
            }
            else {
                // do nothing
            }
        }
    }
    
}
