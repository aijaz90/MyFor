//
//  IDeviceControl.h
//  MTUSDK
//

#import <Foundation/Foundation.h>
#import "IData.h"
#import "MTUSDK_Constants.h"
#import "IResult.h"
#import "ImageData.h"
#import "BarCodeRequest.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * IDeviceControl provides control and command interface for device operations.
 * It manages device connection lifecycle, command sending, display operations,
 * barcode scanning, NFC card emulation, and other device-specific functions.
 *
 * Use this interface to interact with the device hardware and perform operations
 * beyond basic transaction processing.
 */
@interface IDeviceControl: NSObject

// MARK: - Connection Management

/**
 * Opens a connection to the selected device.
 * This must be called before sending commands or starting transactions.
 *
 * @return YES if the device was opened successfully, NO otherwise
 */
- (Boolean) open;

/**
 * Closes the connection to the selected device.
 * Call this when finished using the device to free resources.
 *
 * @return YES if the device was closed successfully, NO otherwise
 */
- (Boolean) close;

// MARK: - Command Sending

/**
 * Sends data to the device asynchronously without waiting for a response.
 *
 * @param data The data to send to the device
 * @return YES if the data was sent successfully, NO otherwise
 */
- (Boolean)send: (IData*) data;

/**
 * Sends data to the device synchronously and waits for a response.
 *
 * @param data The data to send to the device
 * @return IResult object containing the device response
 */
- (IResult*)sendSync: (IData*)data;

/**
 * Sends data to the device asynchronously with a completion handler.
 *
 * @param data The data to send to the device
 * @param callback Completion handler called with the device response
 */
- (void)send: (IData*) data completeHandler :(void (^)(IResult* response)) callback;

/**
 * Sends data to the device with a boolean completion callback.
 *
 * @param data The data to send to the device
 * @param callback Completion handler called with success/failure status
 */
- (void)sendData: (IData *)data completionHandler: (BooleanCallback) callback;

// MARK: - Extended Commands

/**
 * Sends an extended command to the device.
 * Extended commands provide access to advanced device features.
 *
 * @param data The extended command data to send
 * @return YES if the command was sent successfully, NO otherwise
 */
- (Boolean) sendExtendedCommand: (IData*) data;

/**
 * Ends the current session with the device.
 *
 * @return YES if the session ended successfully, NO otherwise
 */
- (Boolean) endSession;

/**
 * Sets the date and time on the device.
 *
 * @param data The date/time data to set
 * @return YES if the date/time was set successfully, NO otherwise
 */
- (Boolean) setDateTime: (IData*) data;

/**
 * Plays a sound on the device.
 *
 * @param data The sound configuration data
 * @return YES if the sound command was sent successfully, NO otherwise
 */
- (Boolean) playSound:(IData*) data;

/**
 * Requests input from the device.
 *
 * @param data The input request configuration data
 * @return YES if the input request was sent successfully, NO otherwise
 */
- (Boolean) getInput:(IData*) data;


// MARK: - Display Operations

/**
 * Displays a predefined message on the device screen.
 *
 * @param messageID The ID of the message to display
 * @param timeOut Timeout in seconds (0 for indefinite)
 * @return YES if the message was displayed successfully, NO otherwise
 */
- (Boolean) displayMessage:(Byte) messageID timeout:(Byte) timeOut;

/**
 * Shows a predefined image on the device screen by image ID.
 *
 * @param imageId The ID of the image to display
 * @return YES if the image was displayed successfully, NO otherwise
 */
- (Boolean) showImage : (Byte) imageId;

/**
 * Shows a custom image on the device screen.
 *
 * @param data The image data to display
 * @param timeOut Timeout in seconds (0 for indefinite)
 * @return YES if the image was displayed successfully, NO otherwise
 */
- (Boolean) showImage : (ImageData*) data timeout : (Byte) timeOut;

/**
 * Displays a barcode on the device screen for scanning by external devices.
 *
 * @param request The barcode request containing barcode data and type
 * @param timeOut Timeout in seconds (0 for indefinite)
 * @param prompt Optional prompt data to display with the barcode
 * @return YES if the barcode was displayed successfully, NO otherwise
 */
- (Boolean) showBarCode : (BarCodeRequest*) request timeout :(Byte) timeOut prompt : (IData*) prompt;

// MARK: - Barcode Reader

/**
 * Starts the barcode reader to scan barcodes.
 *
 * @param timeOut Timeout in seconds (0 for indefinite)
 * @param encryptionMode Encryption mode for captured barcode data
 * @return YES if the barcode reader started successfully, NO otherwise
 */
- (Boolean) startBarCodeReader: (Byte) timeOut mode: (Byte) encryptionMode;

/**
 * Stops the barcode reader.
 *
 * @return YES if the barcode reader stopped successfully, NO otherwise
 */
- (Boolean) stopBarCodeReader;

// MARK: - NFC Card Emulation

/**
 * Starts NFC card emulation mode on the device.
 * The device will emulate an NFC card with the provided data.
 *
 * @param timeOut Timeout in seconds (0 for indefinite)
 * @param data The data to emulate as an NFC card
 * @return YES if NFC card emulation started successfully, NO otherwise
 */
- (Boolean) startNFCCardEmulation: (Byte) timeOut data: (NSString*) data;

/**
 * Stops NFC card emulation mode.
 *
 * @return YES if NFC card emulation stopped successfully, NO otherwise
 */
- (Boolean) stopNFCCardEmulation;

/**
 * Configures the device to enter NFC Pass-Through Mode, enabling the host application
 * to directly exchange APDU commands and responses with an NFC card or mobile device
 * through the reader.
 *
 * @param timeout Duration to stay in Pass-Through mode: 0 (always), or [1…255] (seconds to stay in Pass-Through mode)
 * @param mode Pass-Through mode: 0 (disable), or 1 (enable)
 * @return YES if NFC Pass-Through mode was configured successfully, NO otherwise
 */
- (Boolean) setNFCPassThroughMode: (Byte) timeout mode: (Byte) mode;

/**
 * Configures the NFC reader polling behavior used to detect nearby NFC targets such as
 * cards, mobile devices, or mDL wallets.
 *
 * @param timeout Duration of NFC polling: 0 (always), or [1…255] (seconds to stay in polling mode)
 * @param mode Polling mode: 0 (disable), or 1 (enable)
 * @return YES if NFC polling mode was configured successfully, NO otherwise
 */
- (Boolean) setNFCPollingMode: (Byte) timeout mode: (Byte) mode;

/**
 * Sends a raw APDU command from the host application to the NFC target while the device
 * is operating in NFC Pass-Through mode.
 *
 * The command is forwarded directly to the NFC interface and the response from the NFC
 * target is returned to the host application.
 *
 * This function is used for applications that require direct APDU-level communication,
 * such as mDL, secure element transactions, or custom NFC protocols.
 *
 * @param data APDU command data to be transmitted to the NFC target device
 * @return YES if the command was sent successfully, NO otherwise
 */
- (Boolean) sendNFCPassThroughCommand: (IData*) data;

// MARK: - Personal Information Entry

/**
 * Starts personal information entry mode on the device.
 * Used for capturing sensitive personal data like SSN, phone numbers, etc.
 *
 * @param captureType The type of personal information to capture (SSN, phone, email, etc.)
 * @param encrypt YES to encrypt the captured data, NO otherwise
 * @return YES if personal info entry started successfully, NO otherwise
 */
- (Boolean) startPersonalInfoEntry: (MTU_CaptureType) captureType encrypt : (Boolean) encrypt;

/**
 * Stops personal information entry mode.
 *
 * @return YES if personal info entry stopped successfully, NO otherwise
 */
- (Boolean) stopPersonalInfoEntry;

// MARK: - Device Management

/**
 * Sets or releases the device latch (physical lock mechanism).
 *
 * @param enableLock YES to engage the latch, NO to release it
 * @return YES if the latch was set successfully, NO otherwise
 */
- (Boolean) setLatch :(BOOL) enableLock;

/**
 * Resets the device to factory settings.
 *
 * @return YES if the reset command was sent successfully, NO otherwise
 */
- (Boolean) deviceReset;

/**
 * Controls the status of the device's LED indicators to provide visual feedback for
 * system or NFC operation states.
 *
 * This function allows the host application to enable, disable, or modify the LED
 * behavior for a specific LED indicator.
 *
 * @param led Identifier for the LED to be controlled: 0 (LED 1), 1 (LED 2), 2 (LED 3), 3 (LED 4), or 255 (All LEDs)
 * @param status Desired LED status: 0 (Off), 1 (Green On), or 2 (Red On)
 * @return YES if the LED status was set successfully, NO otherwise
 */
- (Boolean) setLEDStatus: (Byte) led status: (Byte) status;

// MARK: - Device Discovery (Deprecated)

/**
 * Starts scanning for devices.
 *
 * @deprecated Use CoreAPI's startDiscover method instead.
 */
- (void)startScan;

/**
 * Stops scanning for devices.
 *
 * @deprecated Use CoreAPI's stopDiscover method instead.
 */
- (void)stopScan;

/**
 * Configures the External Accessory protocol string for iAP2 connections.
 *
 * @param protocolString The protocol string defined in your app's Info.plist
 * @deprecated Use CoreAPI's setupEADeviceProtocolString method instead.
 */
- (void)setupEADeviceProtocolString: (NSString *)protocolString;

/**
 * Shows any currently connected External Accessory devices.
 *
 * @deprecated Use CoreAPI's startDiscover method instead.
 */
- (void)showConnectedEAAccessoryIfAny;

/**
 * Enables notifications for External Accessory connection/disconnection events.
 *
 * @deprecated Use CoreAPI's startDiscover method instead.
 */
- (void)turnEAAccessoryConnectionNotificationsOn;

/**
 * Disables notifications for External Accessory connection/disconnection events.
 *
 * @deprecated Use CoreAPI's stopDiscover method instead.
 */
- (void)turnEAAccessoryConnectionNotificationsOff;

// MARK: - Async Operations with Completion Handlers

/**
 * Resets the device asynchronously with a completion handler.
 *
 * @param callback Completion handler called with success/failure status
 */
- (void)resetDeviceWithCompletionHandler: (BooleanCallback)callback;

/**
 * Displays a message on the device screen asynchronously.
 *
 * @param messageID The ID of the message to display
 * @param time Timeout in seconds (0 for indefinite)
 * @param callback Completion handler called with success/failure status
 */
- (void)displayMessage: (Byte) messageID timeout: (Byte) time completionHandler: (BooleanCallback) callback;

/**
 * Shows an image on the device screen asynchronously.
 *
 * @param imageID The ID of the image to display
 * @param callback Completion handler called with success/failure status
 */
- (void)showImage: (Byte) imageID completionHandler: (BooleanCallback) callback;

/**
 * Starts barcode scanning asynchronously.
 *
 * @param time Timeout in seconds (0 for indefinite)
 * @param mode Encryption mode for captured barcode data
 * @param callback Completion handler called with success/failure status
 */
- (void)startScanBarcodeWithTimeout: (Byte) time encryptionMode: (Byte) mode completionHandler: (BooleanCallback) callback;

/**
 * Stops barcode scanning asynchronously.
 *
 * @param callback Completion handler called with success/failure status
 */
- (void)stopScanBarcodeWithCompletionHandler: (BooleanCallback) callback;

// MARK: - UI Page Display

/**
 * Displays a custom UI page on the device screen with full configuration options.
 * This is the most comprehensive UI page method with all available parameters.
 *
 * @param timeout Timeout in seconds (0 for indefinite)
 * @param option Display options bitfield
 * @param title Title text resource ID
 * @param line1 First line of text content
 * @param line2 Second line of text content
 * @param line3 Third line of text content
 * @param line4 Fourth line of text content
 * @param line5 Fifth line of text content
 * @param textButton1 Text resource ID for button 1
 * @param textButton2 Text resource ID for button 2
 * @param textButton3 Text resource ID for button 3
 * @param textButton4 Text resource ID for button 4
 * @param textButton5 Text resource ID for button 5
 * @param textButton6 Text resource ID for button 6
 * @param amount1 Amount text for button 1
 * @param amount2 Amount text for button 2
 * @param amount3 Amount text for button 3
 * @param amount4 Amount text for button 4
 * @param amount5 Amount text for button 5
 * @param amount6 Amount text for button 6
 * @param leftButton Left navigation button text resource ID
 * @param middleButton Middle navigation button text resource ID
 * @param rightButton Right navigation button text resource ID
 * @param leftButtonColor Color for left button
 * @param middleButtonColor Color for middle button
 * @param rightButtonColor Color for right button
 * @param xPosition X position for image display
 * @param yPosition Y position for image display
 * @param imageData Optional image data to display
 */
- (void) showUIPage :(Byte) timeout option:(Byte) option title :(uint16_t) title line1 : (NSString*) line1 line2 : (NSString*) line2 line3 : (NSString*) line3 line4 : (NSString*) line4 line5 : (NSString*) line5 textButton1 :(uint16_t) textButton1 textButton2 :(uint16_t) textButton2 textButton3 :(uint16_t) textButton3 textButton4 :(uint16_t) textButton4 textButton5 :(uint16_t) textButton5 textButton6 :(uint16_t) textButton6 amountButton1 :(NSString*) amount1 amountButton2 :(NSString*) amount2 amountButton3 :(NSString*) amount3 amountButton4 :(NSString*) amount4 amountButton5 :(NSString*) amount5 amountButton6 :(NSString*) amount6 leftButton: (uint16_t) leftButton  middleButton: (uint16_t) middleButton rightButton: (uint16_t) rightButton leftButtonColor : (Byte) leftButtonColor middleButtonColor : (Byte) middleButtonColor rightButtonColor : (Byte) rightButtonColor xPosition:(uint16_t) xPosition yPosition: (uint16_t) yPosition imageData : (nullable NSData*) imageData;

/**
 * Displays a simple UI page with text lines from an array and a middle button.
 * Convenience method for displaying multi-line text with a single button.
 *
 * @param timeout Timeout in seconds (0 for indefinite)
 * @param lines Array of text strings to display (up to 5 lines)
 * @param middleButton Middle navigation button text resource ID
 */
- (void) showUIPage :(Byte) timeout withTextLines : (NSArray<NSString*>*) lines middleButton : (uint16_t) middleButton;

/**
 * Displays a UI page with up to 5 text lines and a middle button.
 * Convenience method for displaying multi-line text with individual line parameters.
 *
 * @param timeout Timeout in seconds (0 for indefinite)
 * @param line1 First line of text content
 * @param line2 Second line of text content
 * @param line3 Third line of text content
 * @param line4 Fourth line of text content
 * @param line5 Fifth line of text content
 * @param middleButton Middle navigation button text resource ID
 */
- (void) showUIPage :(Byte) timeout line1 : (NSString*) line1 line2 : (NSString*) line2 line3 : (NSString*) line3 line4 : (NSString*) line4 line5 : (NSString*) line5 middleButton : (uint16_t) middleButton;

/**
 * Displays a UI page with text buttons and navigation buttons.
 * Used for creating menu-style interfaces with multiple selectable options.
 *
 * @param timeout Timeout in seconds (0 for indefinite)
 * @param title Title text resource ID
 * @param textButton1 Text resource ID for button 1
 * @param textButton2 Text resource ID for button 2
 * @param textButton3 Text resource ID for button 3
 * @param textButton4 Text resource ID for button 4
 * @param textButton5 Text resource ID for button 5
 * @param textButton6 Text resource ID for button 6
 * @param leftButton Left navigation button text resource ID
 * @param middleButton Middle navigation button text resource ID
 * @param rightButton Right navigation button text resource ID
 * @param leftButtonColor Color for left button
 * @param middleButtonColor Color for middle button
 * @param rightButtonColor Color for right button
 */
- (void) showUIPage :(Byte) timeout title :(uint16_t) title textButton1 :(uint16_t) textButton1 textButton2 :(uint16_t) textButton2 textButton3 :(uint16_t) textButton3 textButton4 :(uint16_t) textButton4 textButton5 :(uint16_t) textButton5 textButton6 :(uint16_t) textButton6 leftButton: (uint16_t) leftButton  middleButton: (uint16_t) middleButton rightButton: (uint16_t) rightButton leftButtonColor : (Byte) leftButtonColor middleButtonColor : (Byte) middleButtonColor rightButtonColor : (Byte) rightButtonColor;

/**
 * Displays a UI page with amount buttons and navigation buttons.
 * Used for quick amount selection in payment scenarios.
 *
 * @param timeout Timeout in seconds (0 for indefinite)
 * @param title Title text resource ID
 * @param amount1 Amount text for button 1
 * @param amount2 Amount text for button 2
 * @param amount3 Amount text for button 3
 * @param amount4 Amount text for button 4
 * @param amount5 Amount text for button 5
 * @param amount6 Amount text for button 6
 * @param leftButton Left navigation button text resource ID
 * @param middleButton Middle navigation button text resource ID
 * @param rightButton Right navigation button text resource ID
 * @param leftButtonColor Color for left button
 * @param middleButtonColor Color for middle button
 * @param rightButtonColor Color for right button
 */
- (void) showUIPage :(Byte) timeout title :(uint16_t) title amountButton1 :(NSString*) amount1 amountButton2 :(NSString*) amount2 amountButton3 :(NSString*) amount3 amountButton4 :(NSString*) amount4 amountButton5 :(NSString*) amount5 amountButton6 :(NSString*) amount6 leftButton: (uint16_t) leftButton  middleButton: (uint16_t) middleButton rightButton: (uint16_t) rightButton leftButtonColor : (Byte) leftButtonColor middleButtonColor : (Byte) middleButtonColor rightButtonColor : (Byte) rightButtonColor;

/**
 * Displays a UI page with a custom image at specified coordinates.
 * Used for displaying custom graphics or logos on the device screen.
 *
 * @param timeout Timeout in seconds (0 for indefinite)
 * @param title Title text resource ID
 * @param rightButton Right navigation button text resource ID
 * @param xPosition X position for image placement
 * @param yPosition Y position for image placement
 * @param imageData Image data to display
 */
- (void) showUIPage :(Byte) timeout title :(uint16_t) title rightButton :(uint16_t) rightButton xPosition:(uint16_t) xPosition yPosition: (uint16_t) yPosition imageData : (NSData*) imageData;

@end

NS_ASSUME_NONNULL_END
