//
//  BarCodeRequest.h
//  MTUSDK
//
//  Created by Yong Guo on 12/27/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    MTU_QRCODE,
} BarCodeType;

typedef enum : NSUInteger {
    MTU_BARCODE_FORMAT_BLOB,
    MTU_BARCODE_FORMAT_COMMAND,
    MTU_BARCODE_FORMAT_BLOB_BASE64,
    MTU_BARCODE_FORMAT_COMMAND_BASE64,
} BarCodeFormat;

@interface BarCodeRequest : NSObject

@property BarCodeType Type;
@property BarCodeFormat Format;
@property NSData* Data;
@property NSData* BlockColor;
@property NSData* BackgroundColor;
@property Byte ErrorCorrection;
@property Byte MaskPattern;
@property Byte MinVersion;
@property Byte MaxVersion;


@end

NS_ASSUME_NONNULL_END
