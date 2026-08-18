#import "KMScannedImage.h"

@implementation KMScannedImage

- (instancetype)initWithData:(NSData*)data
                scannerObject:(id)scannerObject
                  imageWidth:(UInt32)imageWidth
                 imageHeight:(UInt32)imageHeight {
  if ((self = [super init])) {
    _data = [data copy];
    _imageWidth = imageWidth;
    _imageHeight = imageHeight;
    _scannerObject = scannerObject;  // weak reference to the device module
  }
  return self;
}

@end
