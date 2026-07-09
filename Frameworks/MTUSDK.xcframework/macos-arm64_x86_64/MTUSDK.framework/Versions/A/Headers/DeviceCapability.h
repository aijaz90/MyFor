//
//  DeviceCapability.h
//  MTUSDK
//
//  Created by Yong Guo on 12/27/21.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface DeviceCapability : NSObject

@property MTU_PaymentMethod PaymentMethods;
@property BOOL Display;
@property BOOL PINPad;
@property BOOL Signature;
@property BOOL AutoSignatureCapture;
@property BOOL SRED;

@property BOOL MSRPowerSaver;
@property BOOL BatteryBackedClock;

@end

NS_ASSUME_NONNULL_END
