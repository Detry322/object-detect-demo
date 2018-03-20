// Some Code Sections Copyright 2015 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//  TensorFlowProcessor.mm
//  ObjectDetect
//
//  Created by diego @ webelectric
//
//

#import "TensorFlowProcessor.h"
#import "ios_image_load.h"

#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

#include <sys/time.h>
#include <memory>

#include "tensorflow_utils.h"
#include "tensorflow/core/public/session.h"
#include "tensorflow/core/util/memmapped_file_system.h"

const int wanted_input_width = 299;
const int wanted_input_height = 299;
const int wanted_input_channels = 3;
const int input_mean = 128;
const int input_std = 128;
const bool model_uses_memory_mapping = false;

@interface TensorFlowProcessor (Private) {

}

@end

@implementation TensorFlowProcessor

std::unique_ptr<tensorflow::Session> tf_session;
std::unique_ptr<tensorflow::MemmappedEnv> tf_memmapped_env;
std::vector<std::string> labels;
NSMutableDictionary *oldPredictionValues;
BOOL isConfigured = NO;

void PopulateArrayOfPredictions(std::vector<tensorflow::Tensor>& outputs, int image_width, int image_height, NSMutableArray** outputArray) {
    auto result = [NSMutableArray new];
//    "detection_boxes", "detection_scores", "detection_classes", "num_detections"
    tensorflow::Tensor& boxes = outputs[0];
    tensorflow::Tensor& scores = outputs[1];
    tensorflow::Tensor& classes = outputs[2];
    
    tensorflow::TTypes<float>::Flat boxes_flat = boxes.flat<float>();
    tensorflow::TTypes<float>::Flat scores_flat = scores.flat<float>();
    tensorflow::TTypes<float>::Flat classes_flat = classes.flat<float>();
    
    int num_detections = (int) outputs[3].flat<float>()(0);
    
    NSLog(@"%@: %d", @"Detections", num_detections);
    
    for (int i = 0; i < num_detections; i++) {
        const float score = scores_flat(i);
        const int top = (int) (boxes_flat(4*i) * image_height);
        const int left = (int) (boxes_flat(4*i + 1) * image_width);
        const int bottom = (int) (boxes_flat(4*i + 2) * image_height);
        const int right = (int) (boxes_flat(4*i + 3) * image_width);
        const int class_idx = (int) classes_flat(i);
        NSString* class_name = [NSString stringWithUTF8String:labels[class_idx].c_str()];
        
        NSDictionary* detection = @{
                                      @"score" : @(score),
                                      @"class_name" : class_name,
                                      @"top" : @(top),
                                      @"left" : @(left),
                                      @"bottom" : @(bottom),
                                      @"right" : @(right),
                                      @"class_index" : @(class_idx),
        };
        
        NSLog(@"Detection %d: %@ %.02f, TL: (%d, %d), BR: (%d, %d)", i, class_name, score, top, left, bottom, right);

        [result addObject:detection];
    }
    
    *outputArray = result;
}

- (void)prepareWithLabelsFile:(NSString*)labelsFilename andGraphFile:(NSString*)graphFilename {
    tensorflow::Status load_status;
    
    NSString *graphFname = [graphFilename stringByDeletingPathExtension];
    NSString *graphFextension = [graphFilename pathExtension];

    if (model_uses_memory_mapping) {
        load_status = LoadMemoryMappedModel(
                                            graphFname, graphFextension, &tf_session, &tf_memmapped_env);
    } else {
        load_status = LoadModel(graphFname, graphFextension, &tf_session);
    }
    if (!load_status.ok()) {
        LOG(FATAL) << "Couldn't load model: " << load_status;
    }
    
    NSString *labelsFname = [labelsFilename stringByDeletingPathExtension];
    NSString *labelsFextension = [labelsFilename pathExtension];
    
    tensorflow::Status labels_status =
    LoadLabels(labelsFname, labelsFextension, &labels);
//    LoadLabels(labels_file_name, labels_file_type, &labels);
    oldPredictionValues = [[NSMutableDictionary alloc] init];
    
    isConfigured = YES;

}

- (NSArray* _Nullable)processImage:(NSString* _Nonnull)imageFilename {
    NSString* file_name = [imageFilename stringByDeletingPathExtension];
    NSString* file_type = [imageFilename pathExtension];
    NSString* labels_path = FilePathForResourceName(file_name, file_type);
    int width, height, channels;
    std::vector<unsigned char> result = LoadImageFromFile([labels_path UTF8String], &width, &height, &channels);
    int bytesPerRow = width*channels;
    return [self processBuffer:result.data() withBytesPerRow:bytesPerRow andWidth:width andHeight:height andNumChannels:channels];
}

- (NSArray* _Nullable)processFrame:(CVPixelBufferRef _Nonnull)frame {
    const int sourceRowBytes = (int)CVPixelBufferGetBytesPerRow(frame);
    const int image_width = (int)CVPixelBufferGetWidth(frame);
    const int fullHeight = (int)CVPixelBufferGetHeight(frame);
    CVPixelBufferLockBaseAddress(frame, kCVPixelBufferLock_ReadOnly);
    unsigned char *sourceBaseAddr = (unsigned char *)(CVPixelBufferGetBaseAddress(frame));
    auto result = [self processBuffer:sourceBaseAddr withBytesPerRow:sourceRowBytes andWidth:image_width andHeight:fullHeight andNumChannels:4];
    CVPixelBufferUnlockBaseAddress(frame, kCVPixelBufferLock_ReadOnly);
    return result;
}

- (NSArray* _Nullable)processBuffer:(unsigned char* _Nonnull)pixelBuffer withBytesPerRow:(int)bytesPerRow andWidth:(int)width andHeight:(int)height andNumChannels:(int)numChannels {
    
    if (!isConfigured) {
        return nil;
    }
    
    assert(pixelBuffer != NULL);
    
    NSMutableArray *result = nil;
    
    const int sourceRowBytes = bytesPerRow; //(int)CVPixelBufferGetBytesPerRow(pixelBuffer);
    const int image_width = width; //(int)CVPixelBufferGetWidth(pixelBuffer);
    const int fullHeight = height; //(int)CVPixelBufferGetHeight(pixelBuffer);
    //CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    unsigned char *sourceBaseAddr = pixelBuffer; //(unsigned char *)(CVPixelBufferGetBaseAddress(pixelBuffer));
    int image_height;
    unsigned char *sourceStartAddr;
    if (fullHeight <= image_width) {
        image_height = fullHeight;
        sourceStartAddr = sourceBaseAddr;
    } else {
        image_height = image_width;
        const int marginY = ((fullHeight - image_width) / 2);
        sourceStartAddr = (sourceBaseAddr + (marginY * sourceRowBytes));
    }
    const int image_channels = numChannels;
    
    
//    NSLog(@"Img w = %d h= %d", image_width, fullHeight);
    
    assert(image_channels >= wanted_input_channels);
    tensorflow::Tensor image_tensor(
                                    tensorflow::DT_UINT8,
                                    tensorflow::TensorShape(
                                                            {1, wanted_input_height, wanted_input_width, wanted_input_channels}));
    auto image_tensor_mapped = image_tensor.tensor<tensorflow::uint8, 4>();
    tensorflow::uint8 *in = sourceStartAddr;
    tensorflow::uint8 *out = image_tensor_mapped.data();
    for (int y = 0; y < wanted_input_height; ++y) {
        tensorflow::uint8 *out_row = out + (y * wanted_input_width * wanted_input_channels);
        for (int x = 0; x < wanted_input_width; ++x) {
            const int in_x = (y * image_width) / wanted_input_width;
            const int in_y = (x * image_height) / wanted_input_height;
            tensorflow::uint8 *in_pixel =
            in + (in_y * image_width * image_channels) + (in_x * image_channels);
            tensorflow::uint8 *out_pixel = out_row + (x * wanted_input_channels);
            for (int c = 0; c < wanted_input_channels; ++c) {
                out_pixel[c] = in_pixel[c];
            }
        }
    }
    
    if (!tf_session.get()) {
        return result;
    }
    double a = CFAbsoluteTimeGetCurrent();
    std::vector<tensorflow::Tensor> outputs;
    tensorflow::Status run_status = tf_session->Run(
                                                    {{"image_tensor", image_tensor}},
                                                    {"detection_boxes", "detection_scores", "detection_classes", "num_detections"},
                                                    {},
                                                    &outputs);
    if (!run_status.ok()) {
        LOG(FATAL) << "Running model failed:" << run_status;
        return result;
    }
    
    double b = CFAbsoluteTimeGetCurrent();
    unsigned int m = ((b-a) * 1000.0f); // convert from seconds to milliseconds
    NSLog(@"%@: %d ms", @"Run Model Time taken", m);
    
    PopulateArrayOfPredictions(outputs, wanted_input_width, wanted_input_height, &result);
    return result;
}


@end
