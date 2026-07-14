//
//  IConfigurationCallback.h
//  MTUSDK
//
//  Created by Yong Guo on 11/29/21.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"
#import "IResult.h"

NS_ASSUME_NONNULL_BEGIN

@protocol IConfigurationCallback <NSObject>
@optional
- (void) OnProgress : (int) Progress;
@optional
- (void) OnResult : (MTU_StatusCode) status data : (NSData*) data;
@optional
- (IResult*) OnCalculateMAC :( unsigned char) macType data :( NSData*) data;

@end

NS_ASSUME_NONNULL_END
