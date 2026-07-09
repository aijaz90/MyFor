//
//  PersonalInfoEntryBuilder.h
//  MTUSDK
//
//  Created by Yong Guo on 1/8/26.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"
#import "PersonalInfoEntry.h"

NS_ASSUME_NONNULL_BEGIN

@interface PersonalInfoEntryBuilder : NSObject

+ (PersonalInfoEntry*) GetPersonalInfoEntry : (MTU_DeviceType) DeviceType data : (NSData*) data;

@end

NS_ASSUME_NONNULL_END
