//
//  DeviceEvent.h
//  MTUSDK
//
//  Created by Yong Guo on 8/9/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    MTU_DeviceEvent_None,
    MTU_DeviceEvent_DeviceResetOccurred,
    MTU_DeviceEvent_DeviceResetWillOccur,
    MTU_DeviceEvent_DeviceNotPaired,
    MTU_DeviceEvent_DeviceBatteryLow ,
    MTU_DeviceEvent_DeviceBatteryLowPowerDown ,
    MTU_DeviceEvent_DeviceBatteryPowerFull ,
    MTU_DeviceEvent_DeviceSoftReset,
    MTU_DeviceEvent_DeviceTemperatureLow,
    MTU_DeviceEvent_DeviceTemperatureHigh,
} MTU_DeviceEvent;

@interface DeviceEventBuilder: NSObject

+ (NSString*)deviceEventToString: (MTU_DeviceEvent) deviceEvent;
+ (MTU_DeviceEvent)stringToDeviceEvent: (NSString* _Nonnull) deviceEventString;

@end

NS_ASSUME_NONNULL_END
