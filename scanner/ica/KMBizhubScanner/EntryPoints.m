#import "EntryPoints.h"
#import "KMScannerDevice.h"
#import "KMScannedImage.h"

#import <ICADevices/ICACamera.h>
#import <pthread.h>

static NSMutableDictionary* gDevices = nil;
static pthread_mutex_t gDevicesMutex = PTHREAD_MUTEX_INITIALIZER;

static void lockDevices(void) {
  pthread_mutex_lock(&gDevicesMutex);
}

static void unlockDevices(void) {
  pthread_mutex_unlock(&gDevicesMutex);
}

static KMScannerDevice* deviceForInfo(const ScannerObjectInfo* info) {
  if (!info || !info->privateData) {
    return nil;
  }
  id object = (__bridge id)(void*)info->privateData;
  if ([object isKindOfClass:[KMScannerDevice class]]) {
    return object;
  }
  return nil;
}

static void ensureDevices(void) {
  lockDevices();
  if (!gDevices) {
    gDevices = [NSMutableDictionary dictionary];
  }
  unlockDevices();
}

ICAError KMScannerOpenTCPIPDevice(CFDictionaryRef params,
                                  ScannerObjectInfo* newDeviceObjectInfo) {
  NSDictionary* dict = (__bridge NSDictionary*)params;
  NSString* key = dict[(id)kICABonjourServiceNameKey];
  if (!key) {
    key = dict[(id)kICAIPAddressKey];
  }

  ensureDevices();
  lockDevices();
  BOOL exists = gDevices[key] != nil;
  unlockDevices();
  if (exists) {
    return kICADeviceAlreadyOpenErr;
  }

  KMScannerDevice* device =
      [[KMScannerDevice alloc] initWithNetworkParams:dict];
  lockDevices();
  gDevices[key] = device;
  unlockDevices();

  memset(newDeviceObjectInfo, 0, sizeof(*newDeviceObjectInfo));
  device.deviceObjectInfo = newDeviceObjectInfo;
  newDeviceObjectInfo->privateData = (Ptr)(__bridge void*)device;
  newDeviceObjectInfo->icaObjectInfo.objectType = kICADevice;
  newDeviceObjectInfo->icaObjectInfo.objectSubtype = kICADeviceScanner;
  newDeviceObjectInfo->thumbnailSize = 0;
  strlcpy((char*)newDeviceObjectInfo->name, device.name.UTF8String,
          sizeof(newDeviceObjectInfo->name));
  return noErr;
}

ICAError KMScannerCloseDevice(ScannerObjectInfo* deviceObjectInfo) {
  KMScannerDevice* device = deviceForInfo(deviceObjectInfo);
  if (!device) {
    return paramErr;
  }
  lockDevices();
  for (NSString* key in [gDevices allKeysForObject:device]) {
    [gDevices removeObjectForKey:key];
  }
  unlockDevices();
  return noErr;
}

ICAError KMScannerCleanup(ScannerObjectInfo* objectInfo) {
  return noErr;
}

ICAError KMScannerGetObjectInfo(const ScannerObjectInfo* parentInfo,
                                UInt32 index,
                                ScannerObjectInfo* newInfo) {
  KMScannerDevice* device = deviceForInfo(parentInfo);
  if (!device) {
    return paramErr;
  }
  if (![device updateObjectInfo:newInfo forImageAtIndex:index]) {
    return kICAIndexOutOfRangeErr;
  }
  return noErr;
}

ICAError KMScannerReadFileData(const ScannerObjectInfo* objectInfo,
                               UInt32 dataType, Ptr buffer, UInt32 offset,
                               UInt32* length) {
  if (!objectInfo || !objectInfo->privateData) {
    return paramErr;
  }
  id object = (__bridge id)(void*)objectInfo->privateData;
  if (![object isKindOfClass:[KMScannedImage class]]) {
    return paramErr;
  }
  KMScannedImage* image = object;
  NSUInteger available = image.data.length;
  if (offset >= available) {
    *length = 0;
    return noErr;
  }
  NSUInteger count = MIN((NSUInteger)*length, available - offset);
  memcpy(buffer, (const uint8_t*)image.data.bytes + offset, count);
  *length = (UInt32)count;
  return noErr;
}

ICAError KMScannerSendMessage(const ScannerObjectInfo* objectInfo,
                              ICD_ScannerObjectSendMessagePB* pb,
                              ICDCompletion completion) {
  ICAError err = paramErr;
  KMScannerDevice* device = deviceForInfo(objectInfo);
  if (!device && objectInfo && objectInfo->privateData) {
    id object = (__bridge id)(void*)objectInfo->privateData;
    if ([object isKindOfClass:[KMScannedImage class]]) {
      device = ((KMScannedImage*)object).scannerObject;
    }
  }
  if (!device) {
    return err;
  }
  switch (pb->message.messageType) {
    case kICAMessageCameraDeleteOne:
      err = [device removeObject:objectInfo];
      break;
    default:
      err = paramErr;
      break;
  }
  pb->result = err;
  pb->header.err = err;
  if (err == noErr && completion) {
    completion((ICDHeader*)pb);
  }
  return err;
}

ICAError KMScannerAddPropertiesToCFDictionary(
    ScannerObjectInfo* objectInfo, CFMutableDictionaryRef dict) {
  KMScannerDevice* device = deviceForInfo(objectInfo);
  if (!device) {
    return paramErr;
  }
  [device addPropertiesToDictionary:(__bridge NSMutableDictionary*)dict];
  return noErr;
}

ICAError KMScannerOpenSession(const ScannerObjectInfo* deviceObjectInfo,
                              ICD_ScannerOpenSessionPB* pb) {
  KMScannerDevice* device = deviceForInfo(deviceObjectInfo);
  return device ? [device openSessionWithParams:pb] : paramErr;
}

ICAError KMScannerCloseSession(const ScannerObjectInfo* deviceObjectInfo,
                               ICD_ScannerCloseSessionPB* pb) {
  KMScannerDevice* device = deviceForInfo(deviceObjectInfo);
  return device ? [device closeSessionWithParams:pb] : paramErr;
}

ICAError KMScannerGetParameters(const ScannerObjectInfo* deviceObjectInfo,
                                ICD_ScannerGetParametersPB* pb) {
  KMScannerDevice* device = deviceForInfo(deviceObjectInfo);
  return device ? [device getSelectedFunctionalUnitParams:pb] : paramErr;
}

ICAError KMScannerSetParameters(const ScannerObjectInfo* deviceObjectInfo,
                                ICD_ScannerSetParametersPB* pb) {
  KMScannerDevice* device = deviceForInfo(deviceObjectInfo);
  return device ? [device setSelectedFunctionalUnitParams:pb] : paramErr;
}

ICAError KMScannerStatus(const ScannerObjectInfo* deviceObjectInfo,
                         ICD_ScannerStatusPB* pb) {
  return noErr;
}

ICAError KMScannerStart(const ScannerObjectInfo* deviceObjectInfo,
                        ICD_ScannerStartPB* pb) {
  KMScannerDevice* device = deviceForInfo(deviceObjectInfo);
  return device ? [device startScanningWithParams:pb] : paramErr;
}
