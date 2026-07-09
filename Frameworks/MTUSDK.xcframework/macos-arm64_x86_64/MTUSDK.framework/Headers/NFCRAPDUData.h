//
//  NFCRAPDUData.h
//  MTUSDK
//
//  Created by Yong Guo on 7/1/24.
//

#import <Foundation/Foundation.h>

#import "NFCData.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFCRAPDUData : NFCData

@property (nonatomic) NSData* Response;

+ (instancetype) NewNFCRAPDUData : (NSData*) data Response :(NSData*) response encrypted : (BOOL) encrypted encryptionType : (Byte) encryptionType KSN : (nullable NSData*) ksn;

@end

NS_ASSUME_NONNULL_END
