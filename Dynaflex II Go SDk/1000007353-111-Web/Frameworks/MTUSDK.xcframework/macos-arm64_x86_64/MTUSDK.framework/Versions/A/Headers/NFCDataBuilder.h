//
//  NFCDataBuilder.h
//  MTUSDK
//
//  Created by Yong Guo on 7/1/24.
//

#import <Foundation/Foundation.h>
#import "NFCData.h"
#import "NFCRAPDUData.h"
#import "MTUSDK_Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFCDataBuilder : NSObject

+ (nullable NFCData*) GetNFC : (MTU_DeviceType)DeviceType Data : (NSData*) Data;
+ (nullable NFCRAPDUData*) GetNFC : (MTU_DeviceType)DeviceType RAPDUData : (NSData*) Data;

@end

NS_ASSUME_NONNULL_END
