//
//  TensorFlowProcessor.h
//  ObjectDetect
//
//  Created by diego @ webelectric
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>


@interface TensorFlowProcessor : NSObject {

}

- (void)prepareWithLabelsFile:(NSString* _Nonnull)labelsFilename andGraphFile:(NSString* _Nonnull)graphFilename;
- (NSArray* _Nullable)processImage:(NSString* _Nonnull)imageFilename;
- (NSArray* _Nullable)processFrame:(CVPixelBufferRef _Nonnull)frame;
- (NSArray* _Nullable)processBuffer:(unsigned char* _Nonnull)pixelBuffer withBytesPerRow:(int)bytesPerRow andWidth:(int)width andHeight:(int)height andNumChannels:(int)numChannels andReverse:(bool)reverse;


@end
