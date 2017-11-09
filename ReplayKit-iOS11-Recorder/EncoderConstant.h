//
// Created by Jiangmingz on 2017/10/11.
// Copyright (c) 2017 Anthony Agatiello. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReplayKit/ReplayKit.h>

typedef NS_ENUM(NSInteger, MMBufferType) {
    BufferTypeVideo = RPSampleBufferTypeVideo, // 1
    BufferTypeAudioApp = RPSampleBufferTypeAudioApp, // 2
    BufferTypeAudioMic = RPSampleBufferTypeAudioMic, // 3
};

@interface EncoderConstant : NSObject

@end
