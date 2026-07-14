//
//  UserEvent.h
//  MTUSDK
//
//  Created by Yong Guo on 8/9/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    MTU_UserEvent_None = 0,
    MTU_UserEvent_ContactlessCardPresented = 1,
    MTU_UserEvent_ContactlessCardRemoved = 2,
    MTU_UserEvent_CardSeated = 3,
    MTU_UserEvent_CardUnseated = 4,
    MTU_UserEvent_CardSwiped = 5,
    MTU_UserEvent_TouchPresented = 6,
    MTU_UserEvent_TouchRemoved = 7,
    MTU_UserEvent_BarcodeRead = 8,
    MTU_UserEvent_NFCMifareUltralightPresented = 9,
    MTU_UserEvent_MifareClassic1KPresented = 10,
    MTU_UserEvent_MifareClassic4KPresented = 11,
    MTU_UserEvent_MifareDESFirePresented = 12,
    MTU_UserEvent_MifareDESFireLightPresented = 12,
    MTU_UserEvent_NFCMifareUltralightRemoved = 13,
    MTU_UserEvent_MifareClassic1KRemoved = 14,
    MTU_UserEvent_MifareClassic4KRemoved = 15,
    MTU_UserEvent_MifareDESFireRemoved = 16,
    MTU_UserEvent_MifareDESFireLightRemoved = 16,
    
    MTU_UserEvent_MifareMiniPresented = 17,
    MTU_UserEvent_MifareMiniRemoved = 18,
    
    MTU_UserEvent_MifarePlusEV1Presented = 19,
    MTU_UserEvent_MifarePlusEV2Presented = 20,
    MTU_UserEvent_MifarePlusSEPresented = 21,
    MTU_UserEvent_MifarePlusXPresented = 22,
    MTU_UserEvent_MifareDESFireEV1Presented = 23,
    MTU_UserEvent_MifareDESFireEV2Presented = 24,
    MTU_UserEvent_MifareDESFireEV3Presented = 25,
    MTU_UserEvent_MifarePlusEV1Removed = 26,
    MTU_UserEvent_MifarePlusEV2Removed = 27,
    MTU_UserEvent_MifarePlusSERemoved = 28,
    MTU_UserEvent_MifarePlusXRemoved = 29,
    MTU_UserEvent_MifareDESFireEV1Removed = 30,
    MTU_UserEvent_MifareDESFireEV2Removed = 31,
    MTU_UserEvent_MifareDESFireEV3Removed = 32,
    MTU_UserEvent_mDLPresented = 33,
    MTU_UserEvent_mDLRemoved = 34,
} MTU_UserEvent;

@interface UserEventBuilder : NSObject

+ (MTU_UserEvent) GetValue : (NSString* _Nonnull) valueString;
+ (NSString*) GetString : (MTU_UserEvent) eventValue;

@end

NS_ASSUME_NONNULL_END
