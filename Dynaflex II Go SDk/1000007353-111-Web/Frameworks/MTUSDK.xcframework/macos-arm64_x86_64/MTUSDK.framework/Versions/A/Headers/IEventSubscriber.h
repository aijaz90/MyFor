//
//  IEventSubscriber.h
//  MTUSDK
//
//  Created by Yong Guo on 10/27/21.
//

#ifndef IEventSubscriber_h
#define IEventSubscriber_h

#import "MTUSDK_Constants.h"

@protocol IEventSubscriber <NSObject>

- (void)OnEvent: (MTU_EventType) eventType Data: (IData*) data;

@end

#endif /* IEventSubscriber_h */
