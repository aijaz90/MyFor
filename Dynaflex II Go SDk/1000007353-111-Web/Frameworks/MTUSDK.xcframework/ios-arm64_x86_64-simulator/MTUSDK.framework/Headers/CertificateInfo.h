//
//  CertificateInfo.h
//  MTUSDK
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CertificateInfo: NSObject

@property NSString *format;
@property NSData  *data;
@property NSString *password;

- (instancetype)initWithFormat: (NSString*) certFormat data: (NSData*) certData password: (NSString*) certPassword;

@end

NS_ASSUME_NONNULL_END
