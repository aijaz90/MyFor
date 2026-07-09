//
//  IDeviceConfiguration.h
//  MTUSDK
//
//  Created by Yong Guo on 11/29/21.
//

#import <Foundation/Foundation.h>
#import "MTUSDK_Constants.h"
#import "IConfigurationCallback.h"

NS_ASSUME_NONNULL_BEGIN

#ifndef byte
#define byte  unsigned char
#endif

/**
 * IDeviceConfiguration provides configuration and management interface for device settings.
 * It handles device information retrieval, configuration updates, firmware updates,
 * key management, file operations, and display image management.
 *
 * Use this interface to configure device parameters, update firmware, manage encryption keys,
 * and handle file transfers to/from the device.
 */
@interface IDeviceConfiguration: NSObject

// MARK: - Device Information Retrieval

/**
 * Retrieves device information of the specified type.
 *
 * @param infoType The type of information to retrieve (serial number, firmware version, model, etc.)
 * @return String containing the requested device information
 */
- (NSString*) getDeviceInfo : (MTU_InfoType) infoType;

/**
 * Retrieves configuration information from the device.
 *
 * @param configType The type of configuration to retrieve
 * @param data Additional data required for the configuration query
 * @return NSData containing the configuration information
 */
- (NSData*) getConfigInfo : (byte) configType data : (NSData*) data;

/**
 * Retrieves key information from the device.
 * Used to query encryption key metadata and status.
 *
 * @param keyType The type of key to query
 * @param data Additional data required for the key query
 * @return NSData containing the key information
 */
- (NSData*) getKeyInfo : (byte) keyType data : (NSData*) data;

/**
 * Retrieves a challenge token from the device for authentication purposes.
 *
 * @param data Challenge request data
 * @return NSData containing the challenge token response
 */
- (NSData*) getChallengeToken : (NSData*) data;

// MARK: - Configuration and Key Management

/**
 * Sets or updates configuration information on the device.
 *
 * @param configType The type of configuration to set
 * @param data The configuration data to write
 * @param callback Optional callback to receive progress and completion notifications
 * @return Status code (0 for success, non-zero for error)
 */
- (int) setConfigInfo : (byte) configType data :(NSData*) data callback :(nullable id<IConfigurationCallback>) callback;

/**
 * Updates encryption key information on the device.
 * Used to inject or update cryptographic keys.
 *
 * @param keyType The type of key to update
 * @param data The key data to write
 * @param callback Optional callback to receive progress and completion notifications
 * @return Status code (0 for success, non-zero for error)
 */
- (int) updateKeyInfo : (byte) keyType data :(NSData*) data callback :(nullable id<IConfigurationCallback>) callback;

/**
 * Updates the device firmware.
 *
 * @param configType Firmware configuration type
 * @param fwFileData Binary firmware file data
 * @param callback Optional callback to receive progress and completion notifications
 * @return Status code (0 for success, non-zero for error)
 */
- (int)updateFirmware: (ushort) configType data: (NSData*) fwFileData callback: (nullable id<IConfigurationCallback>) callback;

// MARK: - File Operations

/**
 * Retrieves a file from the device.
 *
 * @param fileID The identifier of the file to retrieve
 * @param callback Optional callback to receive progress and file data
 * @return Status code (0 for success, non-zero for error)
 */
- (int) getFile : (NSData*) fileID callback :(nullable id<IConfigurationCallback>) callback;

/**
 * Sends a file to the device.
 *
 * @param fileID The identifier for the file
 * @param data The file data to send
 * @param callback Optional callback to receive progress and completion notifications
 * @return Status code (0 for success, non-zero for error)
 */
- (int) sendFile : (NSData*) fileID data:(NSData*) data callback :(nullable id<IConfigurationCallback>) callback;

/**
 * Sends a secure (encrypted) file to the device.
 * The file will be encrypted during transmission and storage.
 *
 * @param fileID The identifier for the file
 * @param data The file data to send (will be encrypted)
 * @param callback Optional callback to receive progress and completion notifications
 * @return Status code (0 for success, non-zero for error)
 */
- (int) sendSecureFile : (NSData*) fileID data:(NSData*) data callback :(nullable id<IConfigurationCallback>) callback;

/**
 * Deletes a file from the device.
 *
 * @param fileID The identifier of the file to delete
 * @return Status code (0 for success, non-zero for error)
 */
- (int) deleteFile:(NSData*) fileID;

// MARK: - Display Image Management

/**
 * Sends an image to the device for storage.
 * The image can later be displayed using setDisplayImage.
 *
 * @param imageID The identifier for the image (0-255)
 * @param imageData The image data in a supported format
 * @param callback Optional callback to receive progress and completion notifications
 * @return Status code (0 for success, non-zero for error)
 */
- (int)sendImage: (byte) imageID data: (NSData*) imageData callback: (nullable id<IConfigurationCallback>) callback;

/**
 * Sets which image to display on the device screen.
 *
 * @param imageID The identifier of the image to display
 * @return Status code (0 for success, non-zero for error)
 */
- (int) setDisplayImage:(byte) imageID;

/**
 * Sets which image to display on the device screen asynchronously.
 *
 * @param imageID The identifier of the image to display
 * @param callback Completion handler called with success/failure status
 */
- (void)setDisplayImage: (byte) imageID completionHandler: (BooleanCallback) callback;

@end


/**
 * ConfigurationInfo represents a configuration parameter using ASN.1 OID notation.
 * This class allows you to create configuration objects with OID paths and values
 * for structured device configuration.
 *
 * ASN.1 OIDs provide a hierarchical naming system for configuration parameters.
 */
@interface ConfigurationInfo: NSObject

/// The configuration type identifier
@property Byte configType;

/// The ASN.1 OID and value data
@property NSData* OidAndValue;

/**
 * Creates a configuration info object with an ASN.1 OID path.
 *
 * @param oidPath The ASN.1 OID path string (e.g., "1.2.840.113549.1.1.1")
 * @return A new ConfigurationInfo instance, or nil if the OID is invalid
 */
+ (nullable instancetype)initWithASN1Oid: (NSString*) oidPath;

/**
 * Creates a configuration info object with an ASN.1 OID path and hex value.
 *
 * @param oidPath The ASN.1 OID path string
 * @param value The value as a hex string (e.g., "0A1B2C")
 * @return A new ConfigurationInfo instance, or nil if the OID or value is invalid
 */
+ (nullable instancetype)initWithASN1Oid: (NSString*) oidPath hexValue: (NSString*) value;

/**
 * Creates a configuration info object with an ASN.1 OID path and binary value.
 *
 * @param oidPath The ASN.1 OID path string
 * @param data The value as binary data (can be nil)
 * @return A new ConfigurationInfo instance, or nil if the OID is invalid
 */
+ (nullable instancetype)initWithASN1Oid: (NSString*) oidPath value: (nullable NSData*) data;

/**
 * Returns a string description of the configuration info.
 *
 * @return String representation of the OID and value
 */
- (NSString*) description;

@end

NS_ASSUME_NONNULL_END
