//
//  PersonalInfoEntry.h
//  MTUSDK
//
//  Created by Yong Guo on 1/8/26.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface PersonalInfoEntry : NSObject

@property (nonatomic) NSData* Data;
@property MTU_CaptureType DataType;
@property (nonatomic) BOOL Encrypted;
@property (nonatomic) Byte EncryptionType;
@property (nonatomic) NSData* KSN;


@end

NS_ASSUME_NONNULL_END
