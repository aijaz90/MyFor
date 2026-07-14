//
//  DeviceInfo.h
//  MTUSDK
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DeviceInformation: NSObject

@property NSString *deviceName;
@property NSString *deviceModel;
@property NSString *deviceSerialNumber;

+ (instancetype)initWithName: (NSString*) name model: (NSString*) model serialNumber: (NSString*) sn;

@end

NS_ASSUME_NONNULL_END
