//
//  DisplayMessageBuilder.h
//  MTUSDK
//
//  Created by Harry Zhang on 2/3/24.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface DisplayMessageBuilder : NSObject

+ (nullable NSString*)buildDisplayMessage: (MTU_DeviceType) deviceType
                                 withData: (nonnull NSData*) data;

@end

NS_ASSUME_NONNULL_END
