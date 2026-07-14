//
//  ConnectionStateBuilder.h
//  MTUSDK
//
//  Created by Yong Guo on 11/11/21.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConnectionStateBuilder: NSObject

+ (MTU_ConnectionState)stringToConnectionState: (NSString*) connectionStateString;
+ (NSString*)connectionStateToString:(MTU_ConnectionState) connectionState;

@end

NS_ASSUME_NONNULL_END
