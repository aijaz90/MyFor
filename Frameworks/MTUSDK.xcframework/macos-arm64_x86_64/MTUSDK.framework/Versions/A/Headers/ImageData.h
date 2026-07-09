//
//  ImageData.h
//  MTUSDK
//
//  Created by Yong Guo on 12/27/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    MTU_IMAGE_TYPE_BITMAP,
} ImageType;

@interface ImageData: NSObject

@property ImageType imageType;
@property NSData *data;
@property NSData *backgroundColor;

@end

NS_ASSUME_NONNULL_END
