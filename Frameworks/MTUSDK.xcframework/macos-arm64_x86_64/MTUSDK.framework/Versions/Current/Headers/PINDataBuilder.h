//
//  PINDataBuilder.h
//  MTUSDK
//
//  Created by Yong Guo on 1/4/22.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"
#import "PINData.h"

NS_ASSUME_NONNULL_BEGIN

@interface PINDataBuilder : NSObject

+ (nullable PINData*)  GetPINData : (MTU_DeviceType) deviceType data : (nonnull NSData*) data;


@end

NS_ASSUME_NONNULL_END
