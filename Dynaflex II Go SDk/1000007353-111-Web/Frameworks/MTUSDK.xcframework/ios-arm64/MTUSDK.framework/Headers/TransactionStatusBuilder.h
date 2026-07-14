//
//  TransactionStatusBuilder.h
//  MTUSDK
//
//  Created by Yong Guo on 8/22/22.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"


NS_ASSUME_NONNULL_BEGIN

@interface TransactionStatusBuilder : NSObject

+ (MTU_TransactionStatus) GetStatusCode : (NSString*) data;
+ (NSString*) GetString : (MTU_TransactionStatus) status;
+ (NSString*) GetString : (MTU_TransactionStatus) status WithDetail : (NSString*) detail;
+ (NSString*) GetDetailData : (NSString*) data;

@end

NS_ASSUME_NONNULL_END
