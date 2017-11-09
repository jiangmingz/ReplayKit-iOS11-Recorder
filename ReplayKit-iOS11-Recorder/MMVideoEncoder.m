//
// Created by Jiangmingz on 2017/10/11.
// Copyright (c) 2017 Anthony Agatiello. All rights reserved.
// https://stackoverflow.com/questions/36457884/why-doesnt-my-audio-in-my-game-record-in-replaykit


#import "MMVideoEncoder.h"

@interface MMVideoEncoder () {
    
}

@property(strong, nonatomic) AVAssetWriter *assetWriter;
@property(strong, nonatomic) AVAssetWriterInput *videoInput;
@property(strong, nonatomic) AVAssetWriterInput *audioInput;
@property(assign, nonatomic) BOOL hasStart;

@end

@implementation MMVideoEncoder

+ (instancetype)videoEncoder {
    return [MMVideoEncoder videoEncoderWithPath:nil];
}

+ (instancetype)videoEncoderWithPath:(NSString *)path {
    return [MMVideoEncoder videoEncoderWithPath:path height:0 width:0 channels:0 samplesRate:0.0];
}

+ (instancetype)videoEncoderWithPath:(NSString *)path height:(NSUInteger)height width:(NSUInteger)width channels:(UInt32)channels samplesRate:(Float64)samplesRate {
    return [[MMVideoEncoder alloc] initWithPath:path height:height width:width channels:channels samplesRate:samplesRate];
}

- (instancetype)initWithPath:(NSString *)path height:(NSUInteger)height width:(NSUInteger)width channels:(UInt32)channels samplesRate:(Float64)samplesRate {
    self = [super init];
    if (self) {
        NSError *error = nil;
        if ([path length] == 0) {
            NSString *directoryPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            path = [directoryPath stringByAppendingPathComponent:@"screen.mp4"];
        }

        if (height <= 0) {
            height = 960;
        }

        if (width <= 0) {
            width = 540;
        }

        if (channels <= 0) {
            channels = 1;
        }

        if (samplesRate <= 0) {
            samplesRate = 44100.0;
        }

        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:path]) {
            [fileManager removeItemAtPath:path error:NULL];
        }

        NSURL *url = [NSURL fileURLWithPath:path];
        self.assetWriter = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeMPEG4 error:&error];
        self.assetWriter.shouldOptimizeForNetworkUse = YES;

        // 码率和帧率设置
        NSDictionary *compressionProperties = @{AVVideoAverageBitRateKey: @(height * width * 2),
                                                AVVideoExpectedSourceFrameRateKey: @(30), // 帧率
                                                AVVideoMaxKeyFrameIntervalKey: @(10), // 帧间隔
                                                AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel};
        
        NSDictionary *videoSettings = @{AVVideoCodecKey: AVVideoCodecTypeH264,
                                        AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
                                        AVVideoWidthKey: @(width),
                                        AVVideoHeightKey: @(height),
                                        AVVideoCompressionPropertiesKey: compressionProperties};

        self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
        self.videoInput.expectsMediaDataInRealTime = YES;
        if ([self.assetWriter canAddInput:self.videoInput]) {
            [self.assetWriter addInput:self.videoInput];
        }

        AudioChannelLayout acl;
        bzero(&acl, sizeof(acl));
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;

        NSDictionary *audioSettings = @{AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                AVEncoderBitRateKey: @64000,
                AVSampleRateKey: @(samplesRate),
                AVNumberOfChannelsKey: @(channels),
                AVChannelLayoutKey: [NSData dataWithBytes:&acl length:sizeof(acl)]};

        self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
        self.audioInput.expectsMediaDataInRealTime = YES;
        if ([self.assetWriter canAddInput:self.audioInput]) {
            [self.assetWriter addInput:self.audioInput];
        }
    }

    return self;
}

- (void)encoderSampleBuffer:(CMSampleBufferRef)sampleBuffer bufferType:(MMBufferType)bufferType {
    NSLog(@"bufferType->%zd", bufferType);

        if (!CMSampleBufferDataIsReady(sampleBuffer)) {
            return;
        }

        if (!self.hasStart && self.assetWriter.status == AVAssetWriterStatusUnknown) {
            self.hasStart = YES;
            self.hasStart = [self.assetWriter startWriting];
            [self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
        }

        if (self.assetWriter.status == AVAssetWriterStatusFailed) {
            NSLog(@"An error occured.");
            return;
        }

        if (bufferType == BufferTypeVideo) {
            if (self.videoInput.isReadyForMoreMediaData) {
                [self.videoInput appendSampleBuffer:sampleBuffer];
            }
        } else if (bufferType == BufferTypeAudioMic) {
            if (self.audioInput.isReadyForMoreMediaData) {
                [self.audioInput appendSampleBuffer:sampleBuffer];
            }
        }
}

- (void)finishedEncoder:(void (^)(void))handler {
    [self.videoInput markAsFinished];
    [self.audioInput markAsFinished];
    [self.assetWriter finishWritingWithCompletionHandler:^{
        self.videoInput = nil;
        self.audioInput = nil;
        self.assetWriter = nil;
        
        if (handler) {
            handler();
        }
    }];
}

@end
