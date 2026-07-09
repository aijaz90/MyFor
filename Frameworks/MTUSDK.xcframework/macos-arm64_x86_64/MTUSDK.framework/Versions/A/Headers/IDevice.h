//
//  IDevice.h
//  MTUSDK
//

#import <Foundation/Foundation.h>
#import "ConnectionInfo.h"
#import "IDeviceControl.h"
#import "IEventSubscriber.h"
#import "ITransaction.h"
#import "IDeviceConfiguration.h"
#import "PINRequest.h"
#import "PANRequest.h"
#import "DeviceInfo.h"
#import "DeviceCapability.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * IDevice is the base interface for all device types in the MTUSDK.
 * It provides methods for device connection management, transaction processing,
 * NFC operations, and event handling.
 *
 * This class encapsulates the core functionality needed to interact with
 * MagTek devices including DynaFlex and MTSCRA devices across various
 * connection types (BLE, iAP2, USB, MQTT).
 */
@interface IDevice: NSObject

// MARK: - Device Information

/// The display name of the device
@property (nonatomic, readonly, getter=getDeviceName) NSString *deviceName;

/**
 * Returns the connection information for the device.
 * This includes connection type, address, and other connection-specific details.
 *
 * @return ConnectionInfo object containing connection details, or nil if not available
 */
- (nullable ConnectionInfo*) getConnectionInfo;

/**
 * Returns the current connection state of the device.
 *
 * @return The current MTU_ConnectionState (e.g., connected, disconnected, connecting)
 */
- (MTU_ConnectionState) getConnectionState;

/**
 * Returns detailed information about the device.
 * This includes model, firmware version, serial number, and other device metadata.
 *
 * @return DeviceInformation object, or nil if not available
 */
- (nullable DeviceInformation*) getDeviceInfo;

/**
 * Returns the capabilities supported by the device.
 * This includes features like NFC support, contactless support, PIN entry, etc.
 *
 * @return DeviceCapability object describing supported features, or nil if not available
 */
- (nullable DeviceCapability*) getDeviceCapability;

// MARK: - Device Control and Configuration

/**
 * Returns the device control interface for managing device operations.
 * Use this to connect, disconnect, and perform device-specific control operations.
 *
 * @return IDeviceControl instance, or nil if not supported
 */
- (nullable IDeviceControl*) getDeviceControl;

/**
 * Returns the device configuration interface for managing device settings.
 * Use this to configure device parameters, update firmware, and modify settings.
 *
 * @return IDeviceConfiguration instance, or nil if not supported
 */
- (nullable IDeviceConfiguration*) getDeviceConfiguration;

// MARK: - Transaction Management

/**
 * Starts a transaction synchronously with the device.
 * The transaction will process payment card data, PIN entry, or other operations
 * based on the transaction configuration.
 *
 * @param transaction The transaction object containing configuration and data
 * @return YES if the transaction started successfully, NO otherwise
 */
- (BOOL)startTransaction: (ITransaction*) transaction;

/**
 * Cancels the currently active transaction synchronously.
 *
 * @return YES if the transaction was cancelled successfully, NO otherwise
 */
- (BOOL)cancelTransaction;

/**
 * Starts a transaction asynchronously with the device.
 * The completion handler is called when the transaction start operation completes.
 *
 * @param transaction The transaction object containing configuration and data
 * @param handler Completion callback with BOOL indicating success or failure
 */
- (void)startTransaction: (ITransaction*) transaction completionHandler: (BooleanCallback) handler;

/**
 * Cancels the currently active transaction asynchronously.
 *
 * @param handler Completion callback with BOOL indicating success or failure
 */
- (void)cancelTransactionWithCompletionHandler: (BooleanCallback) handler;

// MARK: - EMV Operations

/**
 * Sends selection data to the device during EMV transaction processing.
 * This is used to provide application selection information.
 *
 * @param data The selection data to send
 * @return YES if the data was sent successfully, NO otherwise
 */
- (BOOL) sendSelection: (IData*) data;

/**
 * Sends authorization data to the device during EMV transaction processing.
 * This is used to provide issuer authorization response.
 *
 * @param data The authorization data to send
 * @return YES if the data was sent successfully, NO otherwise
 */
- (BOOL) sendAuthorization:(IData*) data;

// MARK: - User Input Requests

/**
 * Requests signature capture from the device.
 *
 * @param handler Completion callback with BOOL indicating success or failure
 */
- (void)requestSignatureWithCompletionHandler: (BooleanCallback) handler;

/**
 * Requests PIN entry from the device.
 *
 * @param pinRequest Configuration for the PIN request (prompt, timeout, min/max length, etc.)
 * @param handler Completion callback with BOOL indicating success or failure
 */
- (void)requestPIN: (PINRequest*) pinRequest completionHandler: (BooleanCallback) handler;

/**
 * Requests PAN (Primary Account Number) and optionally PIN entry from the device.
 * This is used for manual card entry scenarios.
 *
 * @param panRequest Configuration for the PAN request
 * @param pinRequest Optional PIN request configuration (can be nil)
 * @param handler Completion callback with BOOL indicating success or failure
 */
- (void)requestPAN: (PANRequest*) panRequest withPIN: (nullable PINRequest*) pinRequest completionHandler: (BooleanCallback) handler;

// MARK: - NFC Operations

/**
 * Sends a generic NFC command to the device.
 * This can be used for various NFC card types.
 *
 * @param data The NFC command data to send
 * @param lastCommand YES if this is the last command in the sequence, NO otherwise
 * @param Encrypt YES to encrypt the command, NO to send unencrypted
 * @return YES if the command was sent successfully, NO otherwise
 */
- (BOOL) sendNFCCommand:(IData*) data lastCommand: (BOOL) lastCommand encrypt: (BOOL) Encrypt;

/**
 * Sends an NFC command specifically for MIFARE Classic cards.
 *
 * @param data The NFC command data to send
 * @param lastCommand YES if this is the last command in the sequence, NO otherwise
 * @param Encrypt YES to encrypt the command, NO to send unencrypted
 * @return YES if the command was sent successfully, NO otherwise
 */
- (BOOL) sendClassicNFCCommand:(IData*) data lastCommand: (BOOL) lastCommand encrypt: (BOOL) Encrypt;

/**
 * Sends an NFC command specifically for MIFARE DESFire cards.
 *
 * @param data The NFC command data to send
 * @param lastCommand YES if this is the last command in the sequence, NO otherwise
 * @param Encrypt YES to encrypt the command, NO to send unencrypted
 * @return YES if the command was sent successfully, NO otherwise
 */
- (BOOL) sendDESFireNFCCommand:(IData*) data lastCommand: (BOOL) lastCommand encrypt: (BOOL) Encrypt;

/**
 * Sends an NFC command specifically for MIFARE Plus cards.
 *
 * @param data The NFC command data to send
 * @param lastCommand YES if this is the last command in the sequence, NO otherwise
 * @param Encrypt YES to encrypt the command, NO to send unencrypted
 * @return YES if the command was sent successfully, NO otherwise
 */
- (BOOL) sendPlusNFCCommand:(IData*) data lastCommand: (BOOL) lastCommand encrypt: (BOOL) Encrypt;

// MARK: - Event Subscription

/**
 * Subscribes to all events from the device.
 * The delegate will receive callbacks for all device events including transaction updates,
 * connection state changes, errors, and data events.
 *
 * @param delegate The object conforming to IEventSubscriber protocol that will receive events
 * @return YES if subscription was successful, NO otherwise
 */
- (Boolean) subscribeAll: (id<IEventSubscriber>) delegate;

/**
 * Unsubscribes from all device events.
 * The delegate will no longer receive any callbacks from the device.
 *
 * @param delegate The object to unsubscribe from events
 * @return YES if unsubscription was successful, NO otherwise
 */
- (Boolean) unsubscribeAll: (id<IEventSubscriber>) delegate;

// MARK: - Debug Support

#ifdef DEBUG
/**
 * Sends a debug data string to the device.
 * This method is only available in DEBUG builds and is used for testing and development.
 *
 * @param DataString The debug data string to send
 */
- (void) debugDataString : (NSString*) DataString;
#endif

@end

/**
 * Block type for callbacks that return a list of devices.
 * Used for device discovery and enumeration operations.
 *
 * @param devices Array of IDevice instances
 */
typedef void (^DeviceListBlock)(NSArray<IDevice*>* devices);

NS_ASSUME_NONNULL_END
