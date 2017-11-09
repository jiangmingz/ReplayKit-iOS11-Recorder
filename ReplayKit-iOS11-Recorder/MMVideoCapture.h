//
// Created by 赵江明 on 2017/9/28.
// Copyright (c) 2017 Dmytro Nosulich. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "EncoderConstant.h"

@interface MMVideoCapture : NSObject

@property(nonatomic, copy) NSString *path;
@property(nonatomic, assign) NSUInteger height;
@property(nonatomic, assign) NSUInteger width;

//当前录制时间
@property(atomic, assign, readonly) Float64 currentRecordTime;

//开始录制
- (void)startCapture;

//暂停录制
- (void)pauseCapture;

//继续录制
- (void)resumeCapture;

//停止录制
- (void)stopCapture;

- (void)captureOutput:(MMBufferType)bufferType didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end