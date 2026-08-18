#import <Foundation/Foundation.h>
#import <ICADevices/ICADevices.h>

#import "EntryPoints.h"

int main(int argc, const char* argv[]) {
  ICD_scanner_callback_functions* callbacks = &gICDScannerCallbackFunctions;
  memset(callbacks, 0, sizeof(*callbacks));
  callbacks->f_ICD_ScannerOpenTCPIPDevice = KMScannerOpenTCPIPDevice;
  callbacks->f_ICD_ScannerCloseDevice = KMScannerCloseDevice;
  callbacks->f_ICD_ScannerCleanup = KMScannerCleanup;
  callbacks->f_ICD_ScannerGetObjectInfo = KMScannerGetObjectInfo;
  callbacks->f_ICD_ScannerReadFileData = KMScannerReadFileData;
  callbacks->f_ICD_ScannerSendMessage = KMScannerSendMessage;
  callbacks->f_ICD_ScannerAddPropertiesToCFDictionary =
      KMScannerAddPropertiesToCFDictionary;
  callbacks->f_ICD_ScannerOpenSession = KMScannerOpenSession;
  callbacks->f_ICD_ScannerCloseSession = KMScannerCloseSession;
  callbacks->f_ICD_ScannerGetParameters = KMScannerGetParameters;
  callbacks->f_ICD_ScannerSetParameters = KMScannerSetParameters;
  callbacks->f_ICD_ScannerStatus = KMScannerStatus;
  callbacks->f_ICD_ScannerStart = KMScannerStart;

  return ICD_ScannerMain(argc, argv);
}
