//
//  NFCEventBuilder.h
//  MTUSDK
//
//  Created by Yong Guo on 7/1/24.
//

#import <Foundation/Foundation.h>
#import "NFCEvent.h"

NS_ASSUME_NONNULL_BEGIN

@interface NFCEventBuilder : NSObject

+ (MTU_NFCEvent) GetEventValue :(NSString*) data;
+ (NSString*) GetEventString : (MTU_NFCEvent) event;

@end

NS_ASSUME_NONNULL_END
