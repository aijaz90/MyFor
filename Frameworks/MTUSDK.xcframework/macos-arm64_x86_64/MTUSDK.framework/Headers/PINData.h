//
//  PINData.h
//  MTUSDK
//
//  Created by Yong Guo on 1/3/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PINData : NSObject

@property NSData* PINBlock;
@property NSData* KSN;
@property Byte Format;
@property Byte EncryptionType;

+ (instancetype) NewPINData :(NSData*) pinBlock ksn :(NSData*) ksn format : (Byte) format encryption:(Byte) encryption;

@end

NS_ASSUME_NONNULL_END
