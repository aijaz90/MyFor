//
//  IResult.h
//  MTUSDK
//
//  Created by Yong Guo on 11/11/21.
//

#import <Foundation/Foundation.h>
#import "IData.h"
#import "MTUSDK_Constants.h"

NS_ASSUME_NONNULL_BEGIN

@interface IResult : NSObject

@property (nonatomic) MTU_StatusCode status;
@property (nonatomic, strong) IData* data;

+ (IResult*) status :(MTU_StatusCode) Status data : (IData*) Data;

@end

NS_ASSUME_NONNULL_END
