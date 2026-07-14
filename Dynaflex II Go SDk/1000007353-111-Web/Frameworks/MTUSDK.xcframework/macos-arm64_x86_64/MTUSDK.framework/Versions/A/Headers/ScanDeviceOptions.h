//
//  ScanDeviceOptions.h
//  MTUSDK
//
//  Created by Yong Guo on 5/26/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ScanDeviceOptions : NSObject

@property (nonatomic) NSString* Filter;
@property (nonatomic) NSTimeInterval TimeOut;
@property (nonatomic) BOOL StopScanAfterDeviceDiscovered;

+ (instancetype) filter : (nonnull NSString*) filter;
+ (instancetype) filter : (nonnull NSString*) filter stop : (BOOL) stop;

- (instancetype) init;

@end

NS_ASSUME_NONNULL_END
