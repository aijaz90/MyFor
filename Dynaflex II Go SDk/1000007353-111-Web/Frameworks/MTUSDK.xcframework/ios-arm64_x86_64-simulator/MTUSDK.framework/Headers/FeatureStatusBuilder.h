//
//  FeatureStatusBuilder.h
//  MTUSDK
//
//  Created by Yong Guo on 1/3/22.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface FeatureStatusBuilder : NSObject

+ (MTU_DeviceFeature) getDeviceFeatrue:(NSString*) data;
+ (MTU_FeatureStatus) getFeatureStatus:(NSString*) data;

+ (NSString*) getFeatureString:(MTU_DeviceFeature) value;
+ (NSString*) getStatusString:(MTU_FeatureStatus) value;

@end

NS_ASSUME_NONNULL_END
