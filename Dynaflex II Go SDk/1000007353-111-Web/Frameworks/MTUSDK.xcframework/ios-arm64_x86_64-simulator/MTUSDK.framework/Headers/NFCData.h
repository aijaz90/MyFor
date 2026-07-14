//
//  NFCData.h
//  MTUSDK
//
//  Created by Yong Guo on 7/1/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NFCData : NSObject
@property (nonatomic) NSData* Data;
@property (nonatomic) NSData* KSN;
@property (nonatomic) BOOL Encrypted;
@property (nonatomic) Byte EncryptionType;

+ (instancetype) NewNFCData : (NSData*) data encrypted : (BOOL) encrypted encryptionType : (Byte) encryptionType KSN : (nullable NSData*) ksn;

@end

NS_ASSUME_NONNULL_END
