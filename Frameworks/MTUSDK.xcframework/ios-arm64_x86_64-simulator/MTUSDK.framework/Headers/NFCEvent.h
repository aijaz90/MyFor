//
//  NFCEvent.h
//  MTUSDK
//
//  Created by Yong Guo on 7/1/24.
//

typedef enum : NSUInteger {
    MTU_NFCEvent_None = 0,
    MTU_NFCEvent_NFCMifareUltralight = 1,
    MTU_NFCEvent_MifareClassic1K = 2,
    MTU_NFCEvent_MifareClassic4K = 3,
    MTU_NFCEvent_MifareDESFire = 4,
    MTU_NFCEvent_MifareDESFireLight = 4,
    MTU_NFCEvent_MifareMini = 5,
    MTU_NFCEvent_MifarePlusEV1 = 6,
    MTU_NFCEvent_MifarePlusEV2 = 7,
    MTU_NFCEvent_MifarePlusSE = 8,
    MTU_NFCEvent_MifarePlusX = 9,
    MTU_NFCEvent_MifareDESFireEV1 = 10,
    MTU_NFCEvent_MifareDESFireEV2 = 11,
    MTU_NFCEvent_MifareDESFireEV3 = 12,
    MTU_NFCEvent_CAmDL = 13,
    MTU_NFCEvent_ISO14443TypeA = 14,
    MTU_NFCEvent_ISO14443TypeB = 15,
    MTU_NFCEvent_NFCCardTypeNotSupported = 16,
    MTU_NFCEvent_TagRemoved = 0x80,
    MTU_NFCEvent_Failed = 0x81,
    MTU_NFCEvent_IOFailed = 0x82,
    MTU_NFCEvent_AuthenticationFailed = 0x83,
    MTU_NFCEvent_Collision = 0x84,
} MTU_NFCEvent;

