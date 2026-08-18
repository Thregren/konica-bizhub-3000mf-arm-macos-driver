#import <Foundation/Foundation.h>
#import <ICADevices/ICADevices.h>

@interface KMScannedImage : NSObject

@property(strong, readonly) NSData* data;
@property(assign, readonly) UInt32 imageWidth;
@property(assign, readonly) UInt32 imageHeight;
@property(weak) id scannerObject;
@property(assign) ICAObject icaObject;

- (instancetype)initWithData:(NSData*)data
                scannerObject:(id)scannerObject
                  imageWidth:(UInt32)imageWidth
                 imageHeight:(UInt32)imageHeight;

@end
