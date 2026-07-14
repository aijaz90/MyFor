//
//  BarCodeData.h
//  MTUSDK
//
//  Created by Yong Guo on 12/27/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BarCodeData : NSObject

@property NSData* Data;
@property BOOL Encrypted;
@property Byte EncryptionType;
@property NSData* KSN;

+ (instancetype) NewBarCodeData: (NSData*) data
                            ksn: (NSData*) ksn
                      encrypted: (BOOL) encrypted
                     encryption: (Byte) encryption;

@end

NS_ASSUME_NONNULL_END
