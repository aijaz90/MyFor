//
//  CoreAPI.h
//  MTUSDK
//

#import <Foundation/Foundation.h>
#import "IDevice.h"
#import "MTUSDK_Constants.h"
#import "ScanDeviceOptions.h"

NS_ASSUME_NONNULL_BEGIN

// MARK: - MTUSDKDelegate protocol

/**
 * SystemState enumeration defines the various states the SDK can be in.
 * These states cover Bluetooth LE status (0-5), network connectivity (11-16),
 * and server connection status (1000).
 */
typedef NS_ENUM(NSInteger, SystemState) {
    SystemStateUnknown = 0,                         // Initial or undefined state
    SystemStateBluetoothLEResetting = 1,            // Bluetooth is currently resetting
    SystemStateBluetoothLEUnsupported = 2,          // Device doesn't support Bluetooth LE
    SystemStateBluetoothLEUnauthorized = 3,         // App lacks Bluetooth permissions
    SystemStateBluetoothLEPoweredOff = 4,           // Bluetooth is turned off
    SystemStateBluetoothLEPoweredOn = 5,            // Bluetooth is ready to use
    SystemStateNetworkOff = 11,                     // Network connectivity is unavailable
    SystemStateNetworkOn = 12,                      // Network connectivity is available
    SystemStateServerNotReachable = 13,             // Cannot connect to remote server
    SystemStateRejectedByServer = 14,               // Server rejected the connection
    SystemStateTLSAuthenticationFailed = 15,        // TLS/SSL authentication failed
    SystemStateProtocolError = 16,                  // Protocol-level communication error
    SystemStateServerConnected = 1000,              // Successfully connected to server
};


/**
 * MTUSDKDelegate protocol defines callbacks for SDK events.
 * All delegate methods are called on the main queue to ensure thread safety for UI updates.
 */
@protocol MTUSDKDelegate <NSObject>

/**
 * Called when devices are discovered during scanning.
 * For example, the BLE service calls this when BLE devices are found.
 *
 * @param instance The service instance that discovered the devices
 * @param connectionType The type of connection (BLE, iAP2, USB, MQTT, etc.)
 * @param deviceList Array of discovered devices conforming to IDevice protocol
 */
- (void)onDeviceList: (id)instance withConnectionType: (MTU_ConnectionType)connectionType deviceList: (NSArray<IDevice *> *)deviceList;

@optional
/**
 * Called when devices are discovered during scanning.
 * For example, the BLE service calls this when BLE devices are found.
 * It add deviceType, to work with multiple device type scanning.
 *
 * @param instance The service instance that discovered the devices
 * @param deviceType  The type of device to work with (e.g., MMS, MTSCRA)
 * @param connectionType The type of connection (BLE, iAP2, USB, MQTT, etc.)
 * @param deviceList Array of discovered devices conforming to IDevice protocol
 */
- (void)onDeviceList: (id)instance withDeviceType:(MTU_DeviceType)deviceType withConnectionType: (MTU_ConnectionType)connectionType deviceList: (NSArray<IDevice *> *)deviceList;

@optional
/**
 * Called when the system state changes (e.g., Bluetooth state, network state, server connection).
 *
 * @param state The new system state
 */
- (void)didSystemUpdateState : (SystemState) state;

@optional
/**
 * Called when debug log messages are available from the SDK.
 *
 * @param log The debug log message string
 */
- (void)didReceiveDebugLog : (NSString*) log;

@end


// MARK: - CoreAPI class

@class DynaFlexDevice;

#ifdef STANDALONE
#else
@class MTSCRADevice;
#endif

/**
 * CoreAPI is the main interface for the MTUSDK.
 * It manages device discovery, connections, and communication across different connection types
 * (Bluetooth LE, iAP2, USB, MQTT) and device types (DynaFlex, MTSCRA).
 *
 * This class follows the singleton pattern - use [CoreAPI shared] to access the instance.
 */
@interface CoreAPI: NSObject

/// Delegate to receive SDK events and updates
@property (nonatomic, weak) id<MTUSDKDelegate> mtuSDKDelegate;

/// Primary DynaFlex device instance (connection type depends on configuration)
@property (nonatomic, strong) DynaFlexDevice *mtmmsDynaFlexDevice;

#ifdef STANDALONE
#else
/// MTSCRA device instance (only available in non-standalone builds)
@property (nonatomic, strong) MTSCRADevice *mtscraDevice;
#endif


// MARK: - Public APIs

/**
 * Returns the shared singleton instance of CoreAPI.
 *
 * @return The shared CoreAPI instance
 */
+ (instancetype)shared;

/**
 * Configures the device type and connection type for subsequent operations.
 * This must be called before starting device discovery.
 *
 * @param deviceType The type of device to work with (e.g., DynaFlex, MTSCRA)
 * @param connectionType The connection method (BLE, iAP2, USB, MQTT, etc.)
 */
- (void)setDeviceType: (MTU_DeviceType)deviceType 
    andConnectionType: (MTU_ConnectionType)connectionType;

/**
 * Starts scanning for surrounding Bluetooth LE peripherals.
 *
 * @deprecated Use startDiscover instead, which supports all connection types.
 */
- (void)startScanningForPeripherals  __deprecated_msg("Use startDiscover instead.");

/**
 * Stops scanning for surrounding Bluetooth LE peripherals.
 *
 * @deprecated Use stopDiscover instead, which supports all connection types.
 */
- (void)stopScanningForPeripherals  __deprecated_msg("Use stopDiscover instead.");

/**
 * Configures the External Accessory protocol string for iAP2 mode.
 * This is required for devices like DF2GO that use the iAP2 connection.
 *
 * @param protocolString The protocol string defined in your app's Info.plist
 */
- (void)setupEADeviceProtocolString: (NSString *)protocolString;

/**
 * Shows any currently connected External Accessory devices.
 *
 * @deprecated Use startDiscover instead.
 */
- (void)showConnectedEAAccessoryIfAny  __deprecated_msg("Use startDiscover instead.");

/**
 * Enables notifications for External Accessory connection/disconnection events.
 *
 * @deprecated Use startDiscover instead.
 */
- (void)turnEAAccessoryConnectionNotificationsOn  __deprecated_msg("Use startDiscover instead.");

/**
 * Disables notifications for External Accessory connection/disconnection events.
 *
 * @deprecated Use stopDiscover instead.
 */
- (void)turnEAAccessoryConnectionNotificationsOff  __deprecated_msg("Use stopDiscover instead.");

/**
 * Starts discovering devices for the specified deviceType and connectionType.
 * This unified method replaces the deprecated turnEAAccessoryConnectionNotificationsOn (for iAP2)
 * and startScanningForPeripherals (for Bluetooth).
 *
 * Discovered devices are reported via the onDeviceList delegate method.
 */
- (void) startDiscover;

/**
 * Stops discovering devices.
 * This unified method replaces the deprecated turnEAAccessoryConnectionNotificationsOff (for iAP2)
 * and stopScanningForPeripherals (for Bluetooth).
 */
- (void) stopDiscover;


/**
 * Returns the SDK API version number.
 *
 * @return The API version as an integer
 */
+ (NSInteger)getAPIVersion;

/**
 * Creates a device instance with basic information.
 *
 * @param deviceType The type of device (DynaFlex, MTSCRA, etc.)
 * @param connectionType The connection method
 * @param address Device address (MAC address for BLE, accessory ID for iAP2, etc.)
 * @param model Device model identifier
 * @param name Device name
 * @param serialNumber Device serial number
 * @return A new device instance conforming to IDevice, or nil if creation fails
 */
+ (nullable IDevice*)createDevice: (MTU_DeviceType) deviceType
                       connection: (MTU_ConnectionType) connectionType
                          address: (NSString*) address
                            model: (NSString*) model
                             name: (NSString*) name
                           serial: (NSString*) serialNumber;

/**
 * Creates a device instance with certificate information for secure connections.
 *
 * @param deviceType The type of device
 * @param connectionType The connection method
 * @param address Device address
 * @param model Device model identifier
 * @param name Device name
 * @param serialNumber Device serial number
 * @param cert Certificate information for TLS/mTLS authentication
 * @return A new device instance conforming to IDevice, or nil if creation fails
 */
+ (nullable IDevice*)createDevice: (MTU_DeviceType) deviceType
                       connection: (MTU_ConnectionType) connectionType
                          address: (NSString*) address
                            model: (NSString*) model
                             name: (NSString*) name
                           serial: (NSString*) serialNumber
                             cert: (CertificateInfo*) cert;


/**
 * Returns the list of supported connection types for a given device type.
 *
 * @param deviceType The device type to query
 * @return Array of connection type names as strings
 */
+ (NSArray<NSString*>*)getConnectionTypes: (MTU_DeviceType) deviceType;

/**
 * Converts a connection type string to its enumeration value.
 *
 * @param connectionTypeString String representation of the connection type
 * @return The corresponding MTU_ConnectionType enumeration value
 */
+ (MTU_ConnectionType)getConnectionTypeFromString: (NSString*) connectionTypeString;

/**
 * Checks if a device type supports enumeration (discovery) for a given connection type.
 *
 * @param deviceType The device type
 * @param connectionType The connection type
 * @return YES if the combination supports device enumeration, NO otherwise
 */
+ (Boolean)isDevice: (MTU_DeviceType) deviceType
         enumerable: (MTU_ConnectionType) connectionType;

/**
 * Returns all discovered devices across all types and connections.
 *
 * @return Array of all discovered devices
 */
+ (NSArray<IDevice*>*)getDeviceList;

/**
 * Returns discovered devices of a specific type.
 *
 * @param deviceType Filter by device type
 * @return Array of discovered devices matching the type
 */
+ (NSArray<IDevice*>*)getDeviceList: (MTU_DeviceType) deviceType;

/**
 * Returns discovered devices matching both device type and connection type.
 *
 * @param deviceType Filter by device type
 * @param connectionType Filter by connection type
 * @return Array of discovered devices matching both criteria
 */
+ (NSArray<IDevice*>*)getDeviceList: (MTU_DeviceType) deviceType
                         connection: (MTU_ConnectionType) connectionType;

// MARK: - MQTT Configuration

/**
 * Configures the MQTT broker connection information.
 * Supports multiple URL schemes for different connection types:
 *   - mqtt://  : TCP connection
 *   - mqtts:// : Encrypted TCP connection (TLS)
 *   - ws://    : WebSocket connection
 *   - wss://   : Secure WebSocket connection (TLS)
 *
 * @param url Broker server URL with appropriate scheme
 * @param username Authentication username (can be nil for anonymous)
 * @param password Authentication password (can be nil for anonymous)
 */
+ (void) setMQTTBrokerInfo : (nonnull NSString*) url  username :(nullable NSString*) username password : (nullable NSString*) password;

/**
 * Sets the MQTT client identifier.
 * This should be unique for each client connecting to the broker.
 *
 * @param clientID Unique client identifier string
 */
+ (void) setMQTTClientID : (nonnull NSString*) clientID;

/**
 * Configures the MQTT topic for subscribing to server messages.
 *
 * @param topic Subscribe topic (default: 'MagTek/Server/DynaFlexIIPED/')
 */
+ (void) setMQTTSubscribeTopic : (nonnull NSString*) topic;

/**
 * Configures the MQTT topic for publishing device messages.
 *
 * @param topic Publish topic (default: 'MagTek/Device/DynaFlexIIPED/')
 */
+ (void) setMQTTPublishTopic : (nonnull NSString*) topic;

/**
 * This function currently does nothing.
 * Device discovery via MQTT will never time out.
 *
 * @param Seconds Timeout value in seconds (ignored)
 */
+ (void) setMQTTDeviceDiscoveryTimeout : (int) Seconds;

/**
 * Sets the MQTT Quality of Service level.
 * Currently uses QoS 0 by default. Applications should not change this
 * unless they fully understand MQTT QoS semantics.
 *
 * QoS levels:
 *   0 = At most once delivery (fire and forget)
 *   1 = At least once delivery (acknowledged)
 *   2 = Exactly once delivery (assured)
 *
 * @param qoS Quality of Service level (0, 1, or 2)
 */
+ (void) setMQTTQoS : (int) qoS;

// MARK: - Global Configuration

/**
 * Sets a global SDK property value.
 *
 * @param property Property name
 * @param value Property value
 */
+ (void) setGlobal: (NSString*) property value : (NSString*) value;

/**
 * Loads a client certificate for mutual TLS (mTLS) authentication.
 * Can be used with WebSocket and MQTT connections.
 *
 * @param format Certificate format - must be "PKCS12"
 * @param data Binary data of the PKCS#12 file
 * @param password Password to decrypt the PKCS#12 file
 * @return Status code (0 for success, non-zero for error)
 */
+ (int)loadClientCertificate:(NSString* _Nonnull)format data:(NSData* _Nonnull)data password:(NSString* _Nonnull)password;

/**
 * Convenience wrapper for loadClientCertificate that accepts a CertificateInfo object.
 *
 * @param certificateInfo Certificate information containing:
 *   - format: Should be "PKCS12"
 *   - data: Content of PKCS#12 file
 *   - password: Password for PKCS#12 file
 */
+ (void)setMQTTCientCertificateInfo:(CertificateInfo*) certificateInfo;

@end

/**
 * Private class extension for CoreAPI.
 * Contains internal device instances for each connection type.
 */
@interface CoreAPI ()
/// DynaFlex device instance for iAP2 connections
@property (nonatomic, strong) DynaFlexDevice *mtmmsDynaFlexDevice_iap2;

/// DynaFlex device instance for USB connections
@property (nonatomic, strong) DynaFlexDevice *mtmmsDynaFlexDevice_usb;

/// DynaFlex device instance for Bluetooth LE connections
@property (nonatomic, strong) DynaFlexDevice *mtmmsDynaFlexDevice_ble;

/// DynaFlex device instance for MQTT connections
@property (nonatomic, strong) DynaFlexDevice *mtmmsDynaFlexDevice_mqtt;
@end

NS_ASSUME_NONNULL_END
