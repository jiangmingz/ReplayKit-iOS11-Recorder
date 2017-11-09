//
// Created by Jiangmingz on 2017/10/11.
// Copyright (c) 2017 Anthony Agatiello. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "EncoderConstant.h"

@interface MMVideoEncoder : NSObject

+ (instancetype)videoEncoder;

+ (instancetype)videoEncoderWithPath:(NSString *)path;

+ (instancetype)videoEncoderWithPath:(NSString *)path height:(NSUInteger)height width:(NSUInteger)width channels:(UInt32)channels samplesRate:(Float64)samplesRate;

- (void)encoderSampleBuffer:(CMSampleBufferRef)sampleBuffer bufferType:(MMBufferType)bufferType;

- (void)finishedEncoder:(void (^)(void))handler;

@end