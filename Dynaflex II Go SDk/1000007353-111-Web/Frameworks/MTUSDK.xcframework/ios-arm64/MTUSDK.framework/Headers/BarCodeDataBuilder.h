//
//  BarCodeDataBuilder.h
//  MTUSDK
//
//  Created by Yong Guo on 1/3/22.
//

#import <Foundation/Foundation.h>

#import "MTUSDK_Constants.h"
#import "BarCodeData.h"


NS_ASSUME_NONNULL_BEGIN

@interface BarCodeDataBuilder : NSObject

+ (nullable BarCodeData*)GetBarCodeData: (MTU_DeviceType) deviceType
                                   data: (nonnull NSData*) data;

@end

NS_ASSUME_NONNULL_END
