//
//  ITransaction.h
//  MTUSDK
//
//  Created by Yong Guo on 11/12/21.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"

NS_ASSUME_NONNULL_BEGIN

/*!
 @interface ITransaction : the Transaction request object
 
 @see **startTransaction**
 */
@interface ITransaction : NSObject
/*!
 @property Timeout : Transaction timeout by seconds.
 */
@property (nonatomic) Byte Timeout;
/*!
 @property PaymentMethods: Payment methods for this transaction.
 */
@property (nonatomic) MTU_PaymentMethod PaymentMethods;
@property (nonatomic) BOOL QuickChip;
@property (nonatomic) BOOL EMVOnly;
@property (nonatomic) BOOL PreventMSRSignatureForCardWithICC;
@property (nonatomic) BOOL SuppressThankYouMessage;
/**
* Display Amount when quick chip is enabled
*
* @see QuickChip
*/
@property (nonatomic) BOOL DisplayAmountForQuickChip;

@property (nonatomic) Byte OverrideFinalTransactionMessage;
@property (nonatomic) Byte EMVResponseFormat;
@property (nonatomic) Byte TransactionType;
@property (nonatomic) NSString* Amount;
@property (nonatomic) NSString* CashBack;
@property (nonatomic) NSData* CurrencyCode;
@property (nonatomic) NSData* CurrenceExponent;
@property (nonatomic) NSData* TransactionCategory;
@property (nonatomic) NSData* MerchantCategory;
@property (nonatomic) NSData* MerchantID;
@property (nonatomic) NSData* MerchantCustomData;
@property (nonatomic) Byte ManualEntryType;
@property (nonatomic) Byte ManualEntryFormat;
@property (nonatomic) Byte ManualEntrySound;
@property (nonatomic) MTU_VASMode AppleVASMode;
@property (nonatomic) MTU_VASProtocol AppleVASProtocol;
/// @property FunctionalButtonRightOption
/// A string id to show a text button on transaction screen
@property (nonatomic) uint16_t FunctionalButtonRightOption;
@property (nonatomic) NSData* ECP2FrameData;
@property (nonatomic) MTU_NFCTransactionMode CustomNFCTransactionMode;
@property (nonatomic) MTU_NFCDataMode CustomNFCDataMode;

@property (nonatomic) Byte TipMode;
@property (nonatomic) Byte Tip1DisplayMode;
@property (nonatomic) Byte Tip2DisplayMode;
@property (nonatomic) Byte Tip3DisplayMode;
@property (nonatomic) Byte Tip4DisplayMode;
@property (nonatomic) Byte Tip5DisplayMode;
@property (nonatomic) Byte Tip6DisplayMode;
@property (nonatomic) NSString* Tip1Value;
@property (nonatomic) NSString* Tip2Value;
@property (nonatomic) NSString* Tip3Value;
@property (nonatomic) NSString* Tip4Value;
@property (nonatomic) NSString* Tip5Value;
@property (nonatomic) NSString* Tip6Value;
@property (nonatomic) NSString* TaxAmount;


+ (instancetype) Amount :(NSString*) amount Timeout : (Byte) timeout For :(MTU_PaymentMethod)methods ;
+ (instancetype) Amount :(NSString*) amount Cashback :(NSString*) cashback TransactionType:(Byte) transactionType Timeout : (Byte) timeout For :(MTU_PaymentMethod)methods QuickChip :(BOOL) quickChip ;


@end

NS_ASSUME_NONNULL_END
