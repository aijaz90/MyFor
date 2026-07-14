//
//  MTTLV.h
//  MTUSDK
//
//  Created by Yong Guo on 11/29/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTTLV : NSObject

@property (nonatomic, strong) NSString* tag;
@property (nonatomic) unsigned long length;
@property (nonatomic, strong) NSString* value;

+ (instancetype) init :(NSString*) Tag value :(NSString*) Value;
+ (instancetype) init :(NSData*) Tag data :(NSData*) Value;
+ (NSArray*) parse : (NSData*) tlvData;
+ (NSArray*) parseHex : (NSString*) hexTlvData;

+ (NSString*) getValue : (nullable NSArray*) tlvs tag : (NSString*) tag;

- (BOOL) isConstructed;

- (NSString*) toString;
- (NSData*) toData;
@end

NS_ASSUME_NONNULL_END
