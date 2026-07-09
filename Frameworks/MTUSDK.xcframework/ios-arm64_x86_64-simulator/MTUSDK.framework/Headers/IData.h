//
//  IData.h
//  MTUSDK
//
//  Created by Yong Guo on 10/27/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IData : NSObject

@property (nonatomic) NSString* StringValue;
@property (nonatomic) NSData* ByteArray;

+ (IData*) dataWithString :( NSString*) string;
+ (IData*) dataWithData :(NSData*) data;
+ (IData*) dataWithHex : (NSString*) hex;

- (IData*) Clone;

@end

NS_ASSUME_NONNULL_END
