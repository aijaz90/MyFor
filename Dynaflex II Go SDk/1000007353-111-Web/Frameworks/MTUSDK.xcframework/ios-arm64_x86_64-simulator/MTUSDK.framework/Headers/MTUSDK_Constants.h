//
//  MTUSDK_Constants.h
//  MTUSDK
//

#ifndef MTUSDK_Constants_h
#define MTUSDK_Constants_h

//#include "DynaFlex_Constants.h"

typedef enum : NSUInteger {
    MTU_DeviceType_Unknown = NSUIntegerMax,
    MTU_DeviceType_SCRA = 0,
    MTU_DeviceType_PPSCRA,
    MTU_DeviceType_CMF,
    MTU_DeviceType_MMS
} MTU_DeviceType;

typedef enum : NSUInteger {
    MTU_ConnectionType_Unknown = NSUIntegerMax,
    MTU_ConnectionType_USB = 0,
    MTU_ConnectionType_BLUETOOTH_LE,
    MTU_ConnectionType_BLUETOOTH_LE_EMV,
    MTU_ConnectionType_BLUETOOTH_LE_EMVT,
    MTU_ConnectionType_TCP,
    MTU_ConnectionType_TCP_TLS,
    MTU_ConnectionType_TCP_TLS_TRUST,
    MTU_ConnectionType_WEBSOCKET,
    MTU_ConnectionType_WEBSOCKET_TRUST,
    MTU_ConnectionType_SERIAL,
    MTU_ConnectionType_AUDIO,
    MTU_ConnectionType_EXTERNAL_ACCESSORY,
    MTU_ConnectionType_MQTT = 12,
    MTU_ConnectionType_VIRTUAL
} MTU_ConnectionType;

#define MTU_ConnectionType_USB_String "USB"
#define MTU_ConnectionType_BLUETOOTH_LE_String "BluetoothLE"
#define MTU_ConnectionType_BLUETOOTH_LE_EMV_String "BluetoothLE_EMV"
#define MTU_ConnectionType_BLUETOOTH_LE_EMVT_String "BluetoothLE_EMVT"
#define MTU_ConnectionType_TCP_String "TCP"
#define MTU_ConnectionType_TCP_TLS_String "TLS12"
#define MTU_ConnectionType_TCP_TLS_TRUST_String "TLS12_TRUST"
#define MTU_ConnectionType_WEBSOCKET_String "WS"
#define MTU_ConnectionType_WEBSOCKET_TRUST_String "WS_TRUST"
#define MTU_ConnectionType_SERIAL_String "Serial"
#define MTU_ConnectionType_AUDIO_String "Audio"
#define MTU_ConnectionType_EXTERNAL_ACCESSORY_String "External Accessory"
#define MTU_ConnectionType_MQTT_String "MQTT"
#define MTU_ConnectionType_VIRTUAL_String "Virtual"

// Not using
#define hexWelcome @"57454C434F4D45"
#define asciiWelcome @"WELCOME"
#define hexTapCard @"5441502043415244"
#define asciiTapCard @"TAP CARD"
#define hexRemoveCard @"52454D4F56452043415244"
#define asciiRemoveCard @"REMOVE CARD"
#define hexThankYou @"5448414E4B20594F55"
#define asciiThankYou @"THANK YOU"
#define hexTimeout @"54494D454F5554"
#define asciiTimout @"TIMEOUT"
#define hexTapInsertOrSwipeCard @"5441502C20494E53455254206F722053574950452043415244"
#define asciiTapInsertOrSwipeCard @"TAP, INSERT or SWIPE CARD"
#define hexTapOrSwipeCard @"544150206F722053574950452043415244"
#define asciiTapOrSwipeCard @"TAP or SWIPE CARD"
#define hexCanceled @"43414E43454C4544"
#define asciiCanceled @"CANCELED"


inline const char* GetConnectionTypeString(MTU_ConnectionType type)
{
    switch (type)
    {
        case MTU_ConnectionType_USB:
            return MTU_ConnectionType_USB_String;
        case  MTU_ConnectionType_BLUETOOTH_LE:
            return MTU_ConnectionType_BLUETOOTH_LE_String;
        case MTU_ConnectionType_BLUETOOTH_LE_EMV:
            return MTU_ConnectionType_BLUETOOTH_LE_EMV_String;
        case MTU_ConnectionType_BLUETOOTH_LE_EMVT:
            return MTU_ConnectionType_BLUETOOTH_LE_EMVT_String;
        case MTU_ConnectionType_TCP:
            return MTU_ConnectionType_TCP_String;
        case MTU_ConnectionType_TCP_TLS:
            return MTU_ConnectionType_TCP_TLS_String;
        case MTU_ConnectionType_TCP_TLS_TRUST:
            return MTU_ConnectionType_TCP_TLS_TRUST_String;
        case MTU_ConnectionType_WEBSOCKET:
            return MTU_ConnectionType_WEBSOCKET_String;
        case MTU_ConnectionType_WEBSOCKET_TRUST:
            return MTU_ConnectionType_WEBSOCKET_TRUST_String;
        case MTU_ConnectionType_SERIAL:
            return MTU_ConnectionType_SERIAL_String;
        case MTU_ConnectionType_AUDIO:
            return MTU_ConnectionType_AUDIO_String;
        case MTU_ConnectionType_EXTERNAL_ACCESSORY:
            return MTU_ConnectionType_EXTERNAL_ACCESSORY_String;
        case MTU_ConnectionType_VIRTUAL:
            return MTU_ConnectionType_VIRTUAL_String;
        default:
            break;
    }
    return "Unknown";
}

typedef enum : NSUInteger {
    MTU_DeviceFeature_None,
    MTU_DeviceFeature_SignatureCapture,
    MTU_DeviceFeature_PINEntry,
    MTU_DeviceFeature_PANEntry,
    MTU_DeviceFeature_ShowBarCode,
    MTU_DeviceFeature_ScanBarCode,
    MTU_DeviceFeature_Buzzer,
    MTU_DeviceFeature_NFCCardEmulation,
    MTU_DeviceFeature_PersonalInfoEntry,
} MTU_DeviceFeature;

typedef enum : NSUInteger {
    MTU_TransactionStatus_NoStatus,
    MTU_TransactionStatus_NoTransaction,
    MTU_TransactionStatus_CardSwiped,
    MTU_TransactionStatus_CardInserted,
    MTU_TransactionStatus_CardRemoved,
    MTU_TransactionStatus_CardDetected,
    MTU_TransactionStatus_CardCollision,
    MTU_TransactionStatus_TimedOut,
    MTU_TransactionStatus_HostCancelled,            // Cancelled by Host/App
    MTU_TransactionStatus_TransactionCancelled,     // Cancelled by Device
    MTU_TransactionStatus_TransactionInProgress,
    MTU_TransactionStatus_TransactionError,
    MTU_TransactionStatus_TransactionApproved,
    MTU_TransactionStatus_TransactionDeclined,
    MTU_TransactionStatus_TransactionCompleted,
    MTU_TransactionStatus_TransactionFailed,
    MTU_TransactionStatus_TransactionNotAccepted,
    MTU_TransactionStatus_SignatureCaptureRequested,
    MTU_TransactionStatus_TechnicalFallback,
    MTU_TransactionStatus_QuickChipDeferred,
    MTU_TransactionStatus_DataEntered,
    MTU_TransactionStatus_TryAnotherInterface,
    MTU_TransactionStatus_BarcodeRead,
    MTU_TransactionStatus_VASError,
    MTU_TransactionStatus_MSRFallback,
    MTU_TransactionStatus_ReservedICCOnly,
} MTU_TransactionStatus;

typedef enum : NSUInteger{
    MTU_FeatureStatus_NoStatus,
    MTU_FeatureStatus_Success,
    MTU_FeatureStatus_Failed,
    MTU_FeatureStatus_TimedOut,
    MTU_FeatureStatus_Cancelled,
    MTU_FeatureStatus_Error,
    MTU_FeatureStatus_HardwareNA,
} MTU_FeatureStatus;

typedef enum : NSUInteger {
    MTU_ConnectionState_Unknown,
    MTU_ConnectionState_Disconnected,
    MTU_ConnectionState_Connecting,
    MTU_ConnectionState_Error,
    MTU_ConnectionState_Connected,
    MTU_ConnectionState_Disconnecting
} MTU_ConnectionState;

typedef enum : NSUInteger {
    MTU_EventType_ConnectionState,
    MTU_EventType_DeviceResponse,
    MTU_EventType_DeviceExtendedResponse,
    MTU_EventType_DeviceNotification,
    MTU_EventType_DataTransferCancelled,
    MTU_EventType_CardData,
    MTU_EventType_TransactionStatus,
    MTU_EventType_DisplayMessage,
    MTU_EventType_InputRequest,
    MTU_EventType_AuthorizationRequest,
    MTU_EventType_TransactionResult,
    MTU_EventType_PINBlock,
    MTU_EventType_Signature,
    MTU_EventType_DeviceDataFile,
    MTU_EventType_OperationStatus,
    MTU_EventType_DeviceEvent,
    MTU_EventType_UserEvent,
    MTU_EventType_FeatureStatus,
    MTU_EventType_PINData,
    MTU_EventType_PANData,
    MTU_EventType_BarCodeData,
    MTU_EventType_NFCEvent,
    MTU_EventType_NFCData,
    MTU_EventType_NFCResponse,
    MTU_EventType_NFCRAPDUResponse,
    MTU_EventType_ClearDisplay,
    MTU_EventType_EnhancedInputRequest,
    MTU_EventType_TouchScreenSignatureCapture,
    MTU_EventType_TouchScreenFunctionalButtonSelected,
    MTU_EventType_TouchScreenTextStringButtonSelected,
    MTU_EventType_TouchScreenAmountButtonSelected,
    MTU_EventType_TouchScreenPresentCardFunctionalButtonSelected,
    
    MTU_EventType_TouchScreenPersonalInfo,

    MTU_EventType_NFCCardData,
    
    MTU_EventType_NFCPassThroughData,
    MTU_EventType_NFCPassThroughResponse,
} MTU_EventType;

typedef NS_ENUM(NSUInteger){
    MTU_CaptureType_None = 0,
    MTU_CaptureType_PhoneNumber = 1,
    MTU_CaptureType_SocialSecurityNumber = 2,
    MTU_CaptureType_ZipCode = 3,
    MTU_CaptureType_EmployeeID = 4,
    MTU_CaptureType_Birthday = 5,
    MTU_CaptureType_Cancel = 255,
} MTU_CaptureType;

typedef NS_OPTIONS(NSUInteger, MTU_PaymentMethod){
    MTU_PaymentMethod_MSR = 1,
    MTU_PaymentMethod_Contact = 2,
    MTU_PaymentMethod_Contactless = 4,
    MTU_PaymentMethod_ManualEntry = 8,
    MTU_PaymentMethod_BarCode = 16,
    MTU_PaymentMethod_AppleVAS = 32,
    MTU_PaymentMethod_BarCodeEncrypted = 64,
    MTU_PaymentMethod_NFC = 128,
    MTU_PaymentMethod_GoogleVAS = 256,
} ;

typedef enum : NSUInteger {
    MTU_StatusCode_Success = 0,
    MTU_StatusCode_Timeout = 1,
    MTU_StatusCode_Error = 2,
    MTU_StatusCode_Unavailable = 3,
} MTU_StatusCode;

typedef enum : NSUInteger {
    MTU_OperationStatus_NoStatus = 0,
    MTU_OperationStatus_Started = 1,
    MTU_OperationStatus_Warning = 2,
    MTU_OperationStatus_Failed = 3,
    MTU_OperationStatus_Done = 4,
} MTU_OperationStatus;

typedef enum : NSUInteger {
    MTU_InfoType_DeviceSerialNumber,
    MTU_InfoType_FirmwareVersion,
    MTU_InfoType_DeviceCapabilities,
    MTU_InfoType_Boot1Version,
    MTU_InfoType_Boot0Version,
    MTU_InfoType_FirmwareHash,
    MTU_InfoType_TamperStatus,
    MTU_InfoType_OperationStatus,
    MTU_InfoType_OfflineDetail,
    MTU_InfoType_DeviceModel,
    MTU_InfoType_FirmwareVersionWLAN,
    MTU_InfoType_FirmwareVersionBLE,
    MTU_InfoType_BatteryLevel,
} MTU_InfoType;

typedef NS_ENUM( NSUInteger )  {
    MTU_VASMode_Single = 1,
    MTU_VASMode_Dual = 2,
    MTU_VASMode_VASOnly = 3,
    MTU_VASMode_ECP2 = 5,
} MTU_VASMode;

typedef NS_OPTIONS(NSUInteger,MTU_NFCTransactionMode) {
    MTU_NFCTransactionMode_None = 0,
    MTU_NFCTransactionMode_MifareClassic = 1,
    MTU_NFCTransactionMode_MifareDESFire = 2,
    MTU_NFCTransactionMode_AppleWalletMobileDESFire = 4,
    MTU_NFCTransactionMode_Mifare2GoMobileDESFire = 8,
} ;

typedef NS_ENUM( NSUInteger, MTU_NFCDataMode) {
    MTU_NFCDataMode_ASCII = 0,
    MTU_NFCDataMode_Binary = 1,
} ;

typedef NS_OPTIONS(NSUInteger, MTU_VASProtocol) {
    MTU_VASProtocol_URL = 1,
    MTU_VASProtocol_Full = 2,
} ;


typedef void(^BooleanCallback)(Boolean resultFlag);


#endif /* MTUSDK_Constants_h */
