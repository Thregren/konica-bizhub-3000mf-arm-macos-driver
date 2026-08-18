#import "KMScannerDevice.h"
#import "KMScannedImage.h"

#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <os/log.h>

#include "brscan.h"

@interface KMScannerDevice ()

@property(copy) NSDictionary* networkParams;
@property(strong) NSMutableDictionary* functionalUnitSettings;
@property(copy) NSString* selectedFunctionalUnit;
@property(strong) NSMutableDictionary* scanImageSettings;
@property(strong) NSMutableArray* scannedImages;

@property(assign) BOOL overviewRequested;
@property(assign) BOOL finalScanRequested;
@property(copy) NSString* documentFolderPath;
@property(copy) NSString* documentName;
@property(copy) NSString* documentUTI;
@property(copy) NSString* documentExtension;
@property(assign) BOOL cancelRequested;

@end

@implementation KMScannerDevice

static os_log_t scannerLog(void) {
  static os_log_t log = nil;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    log = os_log_create("com.konicaminolta.bizhub3000mf.scanner.ica",
                        "KMScannerModule");
  });
  return log;
}

- (instancetype)initWithNetworkParams:(NSDictionary*)params {
  if ((self = [super init])) {
    _networkParams = [params copy];
    _scannedImages = [NSMutableArray array];
    _scanImageSettings = [NSMutableDictionary dictionary];
    _selectedFunctionalUnit = @"0";
    [self loadFunctionalUnits];
  }
  return self;
}

- (void)loadFunctionalUnits {
  NSURL* plistURL = [[NSBundle mainBundle]
      URLForResource:@"ScannerProperties"
       withExtension:@"plist"];
  NSDictionary* root =
      [NSDictionary dictionaryWithContentsOfURL:plistURL];
  NSArray* units = root[@"Scanner Properties"][@"functionalUnitProperties"];

  _functionalUnitSettings = [NSMutableDictionary dictionary];
  for (NSDictionary* unit in units) {
    NSNumber* unitNumber = unit[@"unitNumber"];
    NSMutableDictionary* properties =
        [unit[@"unitProperties"] mutableCopy];
    _functionalUnitSettings[[unitNumber stringValue]] = properties;
  }
}

- (NSString*)name {
  return @"KONICA MINOLTA bizhub 3000MF";
}

#pragma mark - Device properties

- (void)addPropertiesToDictionary:(NSMutableDictionary*)dict {
  dict[(id)kICAUserAssignedDeviceNameKey] = self.name;
  // Image data is delivered as real TIFF/JPEG files, not ICA raw files.
  dict[@"supportsICARawFileFormat"] = @0;
}

#pragma mark - Session management

- (ICAError)openSessionWithParams:(ICD_ScannerOpenSessionPB*)pb {
  if (self.scannerSessionOpened) {
    return kICAInvalidSessionErr;
  }
  self.scannerSessionOpened = YES;
  return noErr;
}

- (ICAError)closeSessionWithParams:(ICD_ScannerCloseSessionPB*)pb {
  if (!self.scannerSessionOpened) {
    return kICAInvalidSessionErr;
  }
  self.scannerSessionOpened = NO;
  return noErr;
}

#pragma mark - Functional unit parameters

- (NSNumber*)valueForKey:(NSString*)key {
  NSMutableDictionary* unit = _functionalUnitSettings[_selectedFunctionalUnit];
  NSMutableDictionary* element = unit[key];
  if (!element) {
    return nil;
  }
  NSString* type = element[@"type"];
  if ([type isEqualToString:@"TWON_ONEVALUE"]) {
    return element[@"value"];
  }
  if ([type isEqualToString:@"TWON_ENUMERATION"]) {
    NSUInteger current = [element[@"current"] unsignedIntegerValue];
    return element[@"value"][current];
  }
  if ([type isEqualToString:@"TWON_RANGE"]) {
    return element[@"current"];
  }
  return nil;
}

- (void)setValueForKey:(NSString*)key fromDictionary:(NSDictionary*)dict {
  NSMutableDictionary* unit = _functionalUnitSettings[_selectedFunctionalUnit];
  NSMutableDictionary* element = unit[key];
  id incoming = dict[key];
  if (!element || !incoming) {
    return;
  }
  NSString* type = element[@"type"];
  if ([type isEqualToString:@"TWON_ENUMERATION"]) {
    NSNumber* incomingValue = incoming[@"value"];
    NSUInteger index = 0;
    for (NSNumber* candidate in element[@"value"]) {
      if ([candidate isEqualToNumber:incomingValue]) {
        element[@"current"] = @(index);
        break;
      }
      index++;
    }
  } else if ([type isEqualToString:@"TWON_RANGE"]) {
    NSNumber* incomingValue = incoming[@"value"];
    if ([incomingValue doubleValue] >= [element[@"min"] doubleValue] &&
        [incomingValue doubleValue] <= [element[@"max"] doubleValue]) {
      element[@"current"] = incomingValue;
    }
  } else {
    unit[key] = incoming;
  }
}

- (ICAError)getSelectedFunctionalUnitParams:(ICD_ScannerGetParametersPB*)pb {
  NSMutableDictionary* dict = (__bridge NSMutableDictionary*)pb->theDict;
  if (!dict) {
    return paramErr;
  }
  dict[@"device"] = _functionalUnitSettings[_selectedFunctionalUnit];
  return noErr;
}

- (ICAError)setSelectedFunctionalUnitParams:(ICD_ScannerSetParametersPB*)pb {
  NSMutableDictionary* paramDict =
      (__bridge NSMutableDictionary*)pb->theDict;
  if (!paramDict) {
    return paramErr;
  }

  id userScanArea = paramDict[@"userScanArea"];
  NSDictionary* dict = nil;
  if ([userScanArea isKindOfClass:[NSArray class]]) {
    dict = [(NSArray*)userScanArea objectAtIndex:1];
  } else if ([userScanArea isKindOfClass:[NSDictionary class]]) {
    dict = userScanArea;
  }
  if (!dict) {
    return noErr;
  }

  NSNumber* selectedUnit = dict[@"selectedFunctionalUnitType"];
  if (selectedUnit) {
    self.selectedFunctionalUnit = [selectedUnit stringValue];
    return noErr;
  }

  [self setValueForKey:@"ICAP_BITDEPTH" fromDictionary:dict];
  [self setValueForKey:@"ICAP_PIXELTYPE" fromDictionary:dict];
  [self setValueForKey:@"ICAP_UNITS" fromDictionary:dict];
  [self setValueForKey:@"ICAP_XRESOLUTION" fromDictionary:dict];
  [self setValueForKey:@"ICAP_YRESOLUTION" fromDictionary:dict];

  if (dict[@"progressNotificationWithData"]) {
    self.overviewRequested = [dict[@"progressNotificationWithData"] boolValue];
  } else {
    self.overviewRequested = NO;
  }
  if (dict[@"progressNotificationNoData"]) {
    self.finalScanRequested = [dict[@"progressNotificationNoData"] boolValue];
  } else {
    self.finalScanRequested = NO;
  }

  if (dict[@"offsetX"]) {
    _scanImageSettings[@"offsetX"] = dict[@"offsetX"];
  }
  if (dict[@"offsetY"]) {
    _scanImageSettings[@"offsetY"] = dict[@"offsetY"];
  }
  if (dict[@"width"]) {
    _scanImageSettings[@"width"] = dict[@"width"];
  }
  if (dict[@"height"]) {
    _scanImageSettings[@"height"] = dict[@"height"];
  }

  self.documentName = dict[@"document name"];
  self.documentFolderPath = dict[@"document folder"];
  self.documentUTI = dict[@"document format"];
  self.documentExtension = dict[@"document extension"];

  os_log(scannerLog(),
         "SetParameters: %{public}@", paramDict);

  return noErr;
}

#pragma mark - Notifications

- (void)sendNotificationOfType:(CFStringRef)type
                       forObject:(UInt32)icaObject
                           file:(NSString*)filePath {
  ICASendNotificationPB notePB = {};
  NSMutableDictionary* notification = [NSMutableDictionary dictionary];
  notification[(id)kICANotificationICAObjectKey] = @(icaObject);
  notification[(id)kICANotificationTypeKey] = (__bridge id)type;
  if (filePath) {
    notification[(id)kICANotificationScannerDocumentNameKey] = filePath;
  }
  notePB.notificationDictionary =
      (__bridge CFMutableDictionaryRef)notification;
  ICDSendNotification(&notePB);
}

- (BOOL)waitingForCancelWithNotification:(NSMutableDictionary*)notification {
  ICASendNotificationPB notePB = {};
  notePB.notificationDictionary =
      (__bridge CFMutableDictionaryRef)notification;
  if (ICDSendNotificationAndWaitForReply(&notePB) == noErr) {
    return notePB.replyCode == userCanceledErr;
  }
  return NO;
}

#pragma mark - Image encoding

- (NSData*)encodedImageDataFromRawGray:(NSData*)gray
                                 width:(NSUInteger)width
                                height:(NSUInteger)height
                                   dpi:(double)dpi
                                   uti:(NSString*)uti {
  CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceGray();
  CGDataProviderRef provider =
      CGDataProviderCreateWithCFData((__bridge CFDataRef)gray);
  CGImageRef image = CGImageCreate(width, height, 8, 8, width, colorspace,
                                   (CGBitmapInfo)kCGImageAlphaNone, provider,
                                   NULL, false, kCGRenderingIntentDefault);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(colorspace);

  NSMutableData* output = [NSMutableData data];
  CGImageDestinationRef destination = CGImageDestinationCreateWithData(
      (__bridge CFMutableDataRef)output, (__bridge CFStringRef)uti, 1, NULL);
  NSDictionary* properties = @{
    (__bridge id)kCGImagePropertyDPIWidth : @(dpi),
    (__bridge id)kCGImagePropertyDPIHeight : @(dpi),
  };
  CGImageDestinationAddImage(destination, image,
                             (__bridge CFDictionaryRef)properties);
  CGImageDestinationFinalize(destination);
  CFRelease(destination);
  CGImageRelease(image);
  return output;
}

- (NSData*)paddedGrayData:(NSData*)gray
                    width:(NSUInteger)width
                   height:(NSUInteger)height {
  NSUInteger expected = width * height;
  if (gray.length >= expected || width == 0 || gray.length == 0) {
    return gray;
  }
  NSMutableData* padded = [gray mutableCopy];
  const uint8_t* src = (const uint8_t*)gray.bytes;
  NSData* lastRow =
      [NSData dataWithBytes:src + (gray.length - width) length:width];
  while (padded.length < expected) {
    NSUInteger remaining = expected - padded.length;
    NSUInteger count = MIN(remaining, width);
    [padded appendBytes:lastRow.bytes length:count];
  }
  return padded;
}

- (NSData*)encodedImageDataFromJPEG:(NSData*)jpeg uti:(NSString*)uti {
  CGImageSourceRef source =
      CGImageSourceCreateWithData((__bridge CFDataRef)jpeg, NULL);
  if (!source) {
    return nil;
  }
  CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
  CFRelease(source);
  if (!image) {
    return nil;
  }
  NSMutableData* output = [NSMutableData data];
  CGImageDestinationRef destination = CGImageDestinationCreateWithData(
      (__bridge CFMutableDataRef)output, (__bridge CFStringRef)uti, 1, NULL);
  CGImageDestinationAddImage(destination, image, NULL);
  CGImageDestinationFinalize(destination);
  CFRelease(destination);
  CGImageRelease(image);
  return output;
}

#pragma mark - Scanning

- (brscan::ScanOptions)scanOptionsForOverview:(BOOL)overview
                                     dpiX:(int*)dpiX
                                     dpiY:(int*)dpiY {
  double requestedX = [[self valueForKey:@"ICAP_XRESOLUTION"] doubleValue];
  double requestedY = [[self valueForKey:@"ICAP_YRESOLUTION"] doubleValue];
  int x = (int)requestedX;
  int y = (int)requestedY;
  if (x < 75) {
    x = 75;
  }
  if (y < 75) {
    y = 75;
  }
  if (overview && x > 100) {
    x = 100;
  }
  if (overview && y > 100) {
    y = 100;
  }
  *dpiX = x;
  *dpiY = y;

  double nativeX = [[self valueForKey:@"ICAP_XNATIVERESOLUTION"] doubleValue];
  double nativeY = [[self valueForKey:@"ICAP_YNATIVERESOLUTION"] doubleValue];
  NSUInteger width = [_scanImageSettings[@"width"] unsignedIntegerValue];
  NSUInteger height = [_scanImageSettings[@"height"] unsignedIntegerValue];
  NSUInteger offsetX = [_scanImageSettings[@"offsetX"] unsignedIntegerValue];
  NSUInteger offsetY = [_scanImageSettings[@"offsetY"] unsignedIntegerValue];

  brscan::ScanOptions options;
  options.dpiX = x;
  options.dpiY = y;
  options.mode = brscan::ColorMode::Gray64;
  options.compression = "NONE";
  options.feeder = !overview && [_selectedFunctionalUnit isEqualToString:@"3"];

  if (overview) {
    options.x = 0;
    options.y = 0;
    options.width = (int)(210.0 * x / 25.4);
    options.height = (int)(291.0 * y / 25.4);
  } else {
    options.x = (int)(offsetX * x / (nativeX > 0 ? nativeX : 600.0));
    options.y = (int)(offsetY * y / (nativeY > 0 ? nativeY : 600.0));
    options.width = (int)width;
    options.height = (int)height;
  }
  if (options.width <= 0) {
    options.width = (int)(210.0 * x / 25.4);
  }
  if (options.height <= 0) {
    options.height = (int)(291.0 * y / 25.4);
  }
  return options;
}

- (NSString*)temporaryPathWithExtension:(NSString*)extension {
  NSString* uuid = [[NSUUID UUID] UUIDString];
  return [NSTemporaryDirectory()
      stringByAppendingPathComponent:
          [NSString stringWithFormat:@"km-scan-%@.%@", uuid, extension]];
}

- (void)performOverviewScan {
  int dpiX = 100;
  int dpiY = 100;
  brscan::ScanOptions options = [self scanOptionsForOverview:YES
                                                       dpiX:&dpiX
                                                       dpiY:&dpiY];
  brscan::Session session;
  if (![self connectSession:&session]) {
    return;
  }

  brscan::Offer offer;
  if (!session.lease(dpiX, brscan::ColorMode::Gray64, &offer)) {
    return;
  }
  std::vector<brscan::ScanPage> pages;
  if (!session.startScan(options, &pages) || pages.empty()) {
    return;
  }

  NSUInteger width = options.width;
  NSUInteger height = options.height;
  os_log(scannerLog(), "Overview: %lux%lu px", (unsigned long)width,
         (unsigned long)height);
  NSData* gray = [NSData dataWithBytes:pages[0].data.data()
                                length:pages[0].data.size()];
  gray = [self paddedGrayData:gray width:width height:height];

  NSMutableDictionary* notification = [NSMutableDictionary dictionary];
  notification[(id)kICANotificationICAObjectKey] =
      @(_deviceObjectInfo->icaObject);
  notification[(id)kICANotificationTypeKey] =
      (__bridge id)kICANotificationTypeScanProgressStatus;
  ICDAddImageInfoToNotificationDictionary(
      (__bridge CFMutableDictionaryRef)notification, (unsigned)width,
      (unsigned)height, (unsigned)width, 0, (unsigned)height,
      (unsigned)(gray.length), (void*)gray.bytes);

  if ([self waitingForCancelWithNotification:notification]) {
    self.cancelRequested = YES;
    [self sendNotificationOfType:kICANotificationTypeTransactionCanceled
                       forObject:_deviceObjectInfo->icaObject
                           file:nil];
  }
  [self sendNotificationOfType:kICANotificationTypeScannerPageDone
                     forObject:_deviceObjectInfo->icaObject
                         file:nil];
  [self sendNotificationOfType:kICANotificationTypeScannerScanDone
                     forObject:_deviceObjectInfo->icaObject
                         file:nil];
}

- (BOOL)connectSession:(brscan::Session*)session {
  NSString* host = _networkParams[(id)kICAIPAddressKey];
  NSNumber* portNumber = _networkParams[(id)kICAIPPortKey];
  if (![host isKindOfClass:[NSString class]]) {
    return NO;
  }
  uint16_t port = portNumber ? [portNumber unsignedShortValue] : 54921;
  if (!session->connect(host.UTF8String, port, 10)) {
    return NO;
  }
  return YES;
}

- (void)performFinalScan {
  int dpiX = 0;
  int dpiY = 0;
  brscan::ScanOptions options = [self scanOptionsForOverview:NO
                                                       dpiX:&dpiX
                                                       dpiY:&dpiY];

  NSUInteger width = options.width;
  NSUInteger height = options.height;
  os_log(scannerLog(),
         "Final: %lux%lu px, dpi=%d,%d, folder=%@, name=%@, uti=%@",
         (unsigned long)width, (unsigned long)height, options.dpiX,
         options.dpiY, self.documentFolderPath, self.documentName,
         self.documentUTI);

  brscan::Session session;
  if (![self connectSession:&session]) {
    [self sendNotificationOfType:kICANotificationTypeDeviceStatusError
                       forObject:_deviceObjectInfo->icaObject
                           file:nil];
    return;
  }

  brscan::Offer offer;
  if (!session.lease(dpiX, brscan::ColorMode::Gray64, &offer)) {
    [self sendNotificationOfType:kICANotificationTypeDeviceStatusError
                       forObject:_deviceObjectInfo->icaObject
                           file:nil];
    return;
  }
  options.dpiX = offer.dpiX;
  options.dpiY = offer.dpiY;

  std::vector<brscan::ScanPage> pages;
  if (!session.startScan(options, &pages) || pages.empty()) {
    [self sendNotificationOfType:kICANotificationTypeDeviceStatusError
                       forObject:_deviceObjectInfo->icaObject
                           file:nil];
    return;
  }

  NSString* uti = self.documentUTI;
  if (!uti) {
    uti = UTTypeTIFF.identifier;
  }
  NSString* extension = self.documentExtension;
  if (!extension) {
    extension = @"tif";
  }

  for (size_t i = 0; i < pages.size(); ++i) {
    if (self.cancelRequested) {
      break;
    }
    NSData* gray = [NSData dataWithBytes:pages[i].data.data()
                                  length:pages[i].data.size()];
    gray = [self paddedGrayData:gray width:width height:height];
    NSData* encoded =
        [self encodedImageDataFromRawGray:gray
                                    width:width
                                   height:height
                                      dpi:dpiX
                                      uti:uti];
    if (!encoded) {
      continue;
    }

    NSString* filePath = nil;
    if (self.documentFolderPath) {
      NSString* fileName = self.documentName ?: @"scan";
      if (pages.size() > 1) {
        fileName = [fileName
            stringByAppendingFormat:@"_%zu", (unsigned long)(i + 1)];
      }
      filePath = [self.documentFolderPath
          stringByAppendingPathComponent:
              [NSString stringWithFormat:@"%@.%@", fileName, extension]];
      [encoded writeToFile:filePath atomically:YES];
    } else {
      KMScannedImage* image =
          [[KMScannedImage alloc] initWithData:encoded
                                  scannerObject:self
                                    imageWidth:(UInt32)width
                                   imageHeight:(UInt32)height];
      ICAObject newObject = 0;
      [_scannedImages addObject:image];
      if (ICDScannerNewObjectInfoCreated(_deviceObjectInfo, 0, &newObject) ==
          noErr) {
        image.icaObject = newObject;
        [self sendNotificationOfType:kICANotificationTypeObjectAdded
                           forObject:newObject
                               file:nil];
      } else {
        [_scannedImages removeLastObject];
      }
    }

    [self sendNotificationOfType:kICANotificationTypeScannerPageDone
                       forObject:_deviceObjectInfo->icaObject
                           file:filePath];
  }

  if (self.cancelRequested) {
    [self sendNotificationOfType:kICANotificationTypeTransactionCanceled
                       forObject:_deviceObjectInfo->icaObject
                           file:nil];
  } else {
    [self sendNotificationOfType:kICANotificationTypeScannerScanDone
                       forObject:_deviceObjectInfo->icaObject
                           file:nil];
  }
}

- (ICAError)startScanningWithParams:(ICD_ScannerStartPB*)pb {
  self.cancelRequested = NO;
  os_log(scannerLog(),
         "Start: overview=%d final=%d",
         self.overviewRequested, self.finalScanRequested);
  if (self.overviewRequested) {
    [self performOverviewScan];
  } else if (self.finalScanRequested) {
    [self performFinalScan];
  }
  return noErr;
}

#pragma mark - Scanned image objects

- (NSUInteger)numberOfScannedImages {
  return _scannedImages.count;
}

- (BOOL)updateObjectInfo:(ScannerObjectInfo*)info
        forImageAtIndex:(NSUInteger)index {
  if (index >= _scannedImages.count) {
    return NO;
  }
  KMScannedImage* image = _scannedImages[index];
  memset(info, 0, sizeof(*info));
  info->privateData = (Ptr)(__bridge void*)image;
  info->icaObjectInfo.objectType = kICAFile;
  info->icaObjectInfo.objectSubtype = kICAFileImage;
  info->dataWidth = image.imageWidth;
  info->dataHeight = image.imageHeight;
  info->dataSize = (UInt32)image.data.length;
  info->thumbnailSize = 0;
  strlcpy((char*)info->name, "scan.tif", sizeof(info->name));
  strlcpy((char*)info->creationDate, "0000:00:00 00:00:00",
          sizeof(info->creationDate));
  return YES;
}

- (BOOL)readFileDataWithObjectInfo:(const ScannerObjectInfo*)objectInfo
                        intoBuffer:(void*)buffer
                       withOffset:(UInt32)offset
                         andLength:(UInt32*)length {
  KMScannedImage* image =
      (__bridge KMScannedImage*)(void*)objectInfo->privateData;
  if (![image isKindOfClass:[KMScannedImage class]]) {
    return NO;
  }
  NSUInteger available = image.data.length;
  if (offset >= available) {
    *length = 0;
    return YES;
  }
  NSUInteger count = MIN((NSUInteger)*length, available - offset);
  memcpy(buffer, (const uint8_t*)image.data.bytes + offset, count);
  *length = (UInt32)count;
  return YES;
}

- (ICAError)removeObject:(const ScannerObjectInfo*)objectInfo {
  KMScannedImage* image =
      (__bridge KMScannedImage*)(void*)objectInfo->privateData;
  if ([image isKindOfClass:[KMScannedImage class]]) {
    [_scannedImages removeObject:image];
  }
  return noErr;
}

@end
