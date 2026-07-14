//
//  PANDataBuilder.h
//  MTUSDK
//
//  Created by Yong Guo on 1/4/22.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"
#import "PANData.h"

NS_ASSUME_NONNULL_BEGIN

@interface PANDataBuilder : NSObject

+ (nullable PANData*)  GetPANData : (MTU_DeviceType) deviceType data : (nonnull NSData*) data;


@end

NS_ASSUME_NONNULL_END
