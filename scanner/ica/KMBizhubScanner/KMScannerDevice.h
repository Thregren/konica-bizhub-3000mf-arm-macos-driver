#import <Foundation/Foundation.h>
#import <ICADevices/ICADevices.h>

@interface KMScannerDevice : NSObject

@property(readonly) NSString* name;
@property(assign) ScannerObjectInfo* deviceObjectInfo;
@property(assign) BOOL scannerSessionOpened;

- (instancetype)initWithNetworkParams:(NSDictionary*)params;

- (void)addPropertiesToDictionary:(NSMutableDictionary*)dict;
- (ICAError)openSessionWithParams:(ICD_ScannerOpenSessionPB*)pb;
- (ICAError)closeSessionWithParams:(ICD_ScannerCloseSessionPB*)pb;
- (ICAError)getSelectedFunctionalUnitParams:(ICD_ScannerGetParametersPB*)pb;
- (ICAError)setSelectedFunctionalUnitParams:(ICD_ScannerSetParametersPB*)pb;
- (ICAError)startScanningWithParams:(ICD_ScannerStartPB*)pb;

- (NSUInteger)numberOfScannedImages;
- (BOOL)updateObjectInfo:(ScannerObjectInfo*)info forImageAtIndex:(NSUInteger)index;
- (BOOL)readFileDataWithObjectInfo:(const ScannerObjectInfo*)objectInfo
                        intoBuffer:(void*)buffer
                       withOffset:(UInt32)offset
                         andLength:(UInt32*)length;
- (ICAError)removeObject:(const ScannerObjectInfo*)objectInfo;

@end
