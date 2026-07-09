//
//  OperationStatusBuilder.h
//  MTUSDK
//
//  Created by Yong Guo on 11/11/21.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface OperationStatusBuilder : NSObject

+ (NSString*) GetString : (MTU_OperationStatus) status;

+ (MTU_OperationStatus) GetStatus : (NSString*) statusString;

@end

NS_ASSUME_NONNULL_END
