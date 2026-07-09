//
//  PINRequest.h
//  MTUSDK
//
//  Created by Yong Guo on 12/27/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PINRequest : NSObject

@property Byte Timeout;
@property Byte PINMode;
@property Byte MinLength;
@property Byte MaxLength;
@property Byte Tone;
@property Byte Format;
@property NSString* PAN;

+ (instancetype)newRequest: (Byte) timeout mode: (Byte) mode min: (Byte) min max: (Byte) max tone: (Byte) tone format: (Byte) format PAN: (NSString*) pan;
+ (instancetype)newRequest: (Byte) timeout;

@end

NS_ASSUME_NONNULL_END
