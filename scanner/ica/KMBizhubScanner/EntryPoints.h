#import <ICADevices/ICADevices.h>

ICAError KMScannerOpenTCPIPDevice(CFDictionaryRef params,
                                  ScannerObjectInfo* newDeviceObjectInfo);
ICAError KMScannerCloseDevice(ScannerObjectInfo* deviceObjectInfo);
ICAError KMScannerCleanup(ScannerObjectInfo* objectInfo);
ICAError KMScannerGetObjectInfo(const ScannerObjectInfo* parentInfo,
                                UInt32 index,
                                ScannerObjectInfo* newInfo);
ICAError KMScannerReadFileData(const ScannerObjectInfo* objectInfo,
                               UInt32 dataType, Ptr buffer, UInt32 offset,
                               UInt32* length);
ICAError KMScannerSendMessage(const ScannerObjectInfo* objectInfo,
                              ICD_ScannerObjectSendMessagePB* pb,
                              ICDCompletion completion);
ICAError KMScannerAddPropertiesToCFDictionary(
    ScannerObjectInfo* objectInfo, CFMutableDictionaryRef dict);
ICAError KMScannerOpenSession(const ScannerObjectInfo* deviceObjectInfo,
                              ICD_ScannerOpenSessionPB* pb);
ICAError KMScannerCloseSession(const ScannerObjectInfo* deviceObjectInfo,
                               ICD_ScannerCloseSessionPB* pb);
ICAError KMScannerGetParameters(const ScannerObjectInfo* deviceObjectInfo,
                                ICD_ScannerGetParametersPB* pb);
ICAError KMScannerSetParameters(const ScannerObjectInfo* deviceObjectInfo,
                                ICD_ScannerSetParametersPB* pb);
ICAError KMScannerStatus(const ScannerObjectInfo* deviceObjectInfo,
                         ICD_ScannerStatusPB* pb);
ICAError KMScannerStart(const ScannerObjectInfo* deviceObjectInfo,
                        ICD_ScannerStartPB* pb);
