//
//  ConnectionInfo.h
//  MTUSDK
//
//  Created by Yong Guo on 10/15/21.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"
#import "CertificateInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConnectionInfo: NSObject

+ (ConnectionInfo*)initWithDeviceType: (MTU_DeviceType) deviceType
                       connectionType: (MTU_ConnectionType) connectionType
                              address: (NSString*) address;

+ (ConnectionInfo*)initWithDeviceType: (MTU_DeviceType) deviceType
                       connectionType: (MTU_ConnectionType) connectionType
                              address: (NSString*) address
                          certificate: (CertificateInfo*) certInfo;


- (MTU_DeviceType)getDeviceType;
- (MTU_ConnectionType)getConnectionType;
- (NSString*)getAddress;
- (CertificateInfo*)getCertificateInfo;

@end

NS_ASSUME_NONNULL_END
