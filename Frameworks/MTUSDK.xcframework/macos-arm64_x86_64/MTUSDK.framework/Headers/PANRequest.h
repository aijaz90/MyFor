//
//  PANRequest.h
//  MTUSDK
//
//  Created by Yong Guo on 12/27/21.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface PANRequest : NSObject

@property Byte Timeout;
@property MTU_PaymentMethod PaymentMethods;

+ (instancetype)newRequest: (Byte) timeout payment: (MTU_PaymentMethod) payment;

@end

NS_ASSUME_NONNULL_END
