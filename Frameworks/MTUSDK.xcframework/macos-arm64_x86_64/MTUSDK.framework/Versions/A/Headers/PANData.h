//
//  PANData.h
//  MTUSDK
//
//  Created by Yong Guo on 1/3/22.
//

#import <Foundation/Foundation.h>
#import "PINData.h"

NS_ASSUME_NONNULL_BEGIN

@interface PANData : NSObject

@property NSData* Data;
@property NSData* KSN;
@property Byte EncryptionType;

@property PINData* PINData;

+ (instancetype) NewPANData :(NSData*) Data ksn : (NSData*) ksn encryption : (Byte) encryption pin : (nullable PINData*) pinData;

@end

NS_ASSUME_NONNULL_END
