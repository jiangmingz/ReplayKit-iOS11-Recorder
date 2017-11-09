//
// Created by 赵江明 on 2017/9/28.
// Copyright (c) 2017 Dmytro Nosulich. All rights reserved.
//

#import "MMVideoCapture.h"
#import "MMVideoEncoder.h"
#import "MMAudioRecord.h"

@interface MMVideoCapture () <MMAudioRecordDelegate, MMAudioRecordDelegate> {
    CMTime _timeOffset;
    CMTime _lastVideo;
    CMTime _lastAudio;

    NSTimeInterval _firstAudioTime;
    dispatch_queue_t _writingQueue;

    CMSampleTimingInfo *_firstTimingInfo;
    CMItemCount _fistItemCount;
}

@property(strong, nonatomic) MMVideoEncoder *videoEncoder;
@property(strong, nonatomic) MMAudioRecord *audioRecord;

//正在录制
@property(atomic, assign) BOOL isCapturing;

//是否暂停
@property(atomic, assign) BOOL isPaused;

//是否中断
@property(atomic, assign) BOOL discont;

//开始录制的时间
@property(atomic, assign) CMTime startTime;

//当前录制时间
@property(atomic, assign) Float64 currentRecordTime;

@end

@implementation MMVideoCapture

- (instancetype)init {
    self = [super init];
    if (self) {
        _writingQueue = dispatch_queue_create("com.waqu.encoder.writing", DISPATCH_QUEUE_SERIAL);
        self.audioRecord = [[MMAudioRecord alloc] init];
        self.audioRecord.delegate = self;
    }

    return self;
}

#pragma mark - 公开的方法

//开始录制
- (void)startCapture {
    @synchronized (self) {
        if (!self.isCapturing) {
            self.videoEncoder = nil;
            self.isPaused = NO;
            self.discont = NO;
            _timeOffset = CMTimeMake(0, 0);
            self.isCapturing = YES;

            [self.audioRecord startRunning];
        }
    }
}

//暂停录制
- (void)pauseCapture {
    @synchronized (self) {
        if (self.isCapturing) {
            self.isPaused = YES;
            self.discont = YES;
        }
    }
}

//继续录制
- (void)resumeCapture {
    @synchronized (self) {
        if (self.isPaused) {
            self.isPaused = NO;
        }
    }
}

//停止录制
- (void)stopCapture {
    @synchronized (self) {
        if (self.isCapturing) {
            self.isCapturing = NO;
            [self.audioRecord stopRunning];

            dispatch_async(_writingQueue, ^{
                [self.videoEncoder finishedEncoder:^{
                    self.isCapturing = NO;
                    self.videoEncoder = nil;
                    self.startTime = CMTimeMake(0, 0);
                    self.currentRecordTime = 0;
                }];
            });
        }
    }
}

- (CMSampleBufferRef)adjustTime:(CMSampleBufferRef)sample offset:(CMTime)offset {
    CMItemCount itemCount;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &itemCount);
    CMSampleTimingInfo *pInfo = malloc(sizeof(CMSampleTimingInfo) * itemCount);
    CMSampleBufferGetSampleTimingInfoArray(sample, itemCount, pInfo, &itemCount);
    for (CMItemCount i = 0; i < itemCount; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, itemCount, pInfo, &sout);
    free(pInfo);
    return sout;
}

- (CMSampleTimingInfo *)firstTimingInfo:(CMSampleBufferRef)sample {
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &_fistItemCount);
    CMSampleTimingInfo *timingInfo = malloc(sizeof(CMSampleTimingInfo) * _fistItemCount);
    CMSampleBufferGetSampleTimingInfoArray(sample, _fistItemCount, timingInfo, &_fistItemCount);
    return timingInfo;
}

- (void)audioSampleBuffer:(CMSampleBufferRef)sampleBuffer recordTime:(NSTimeInterval)recordTime {
    if (_startTime.value == 0) {
        _firstAudioTime = recordTime;
        return;
    }

    NSTimeInterval duration = recordTime - _firstAudioTime;
    CMTime offset = CMTimeMake(duration, _startTime.timescale);
    for (CMItemCount i = 0; i < _fistItemCount; i++) {
        _firstTimingInfo[i].decodeTimeStamp = CMTimeSubtract(_firstTimingInfo[i].decodeTimeStamp, offset);
        _firstTimingInfo[i].presentationTimeStamp = CMTimeSubtract(_firstTimingInfo[i].presentationTimeStamp, offset);
        _firstTimingInfo[i].duration = CMTimeMake(1, 44100);
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sampleBuffer, _fistItemCount, _firstTimingInfo, &sout);
    [self captureOutput:BufferTypeAudioMic didOutputSampleBuffer:sout];
}

#pragma mark - 写入数据

- (void)captureOutput:(MMBufferType)bufferType didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    @synchronized (self) {
        if (!self.isCapturing || self.isPaused) {
            return;
        }

        //初始化编码器，当有音频和视频参数时创建编码器
        if (self.videoEncoder == nil) {
            self.videoEncoder = [MMVideoEncoder videoEncoderWithPath:self.path
                                                              height:self.height
                                                               width:self.width
                                                            channels:0
                                                         samplesRate:0];
        }

        // 判断是否中断录制过
        if (self.discont) {
            if (bufferType == BufferTypeVideo) {
                return;
            }
            self.discont = NO;

            // 计算暂停的时间
            CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            CMTime last = bufferType == BufferTypeVideo ? _lastVideo : _lastAudio;
            if (last.flags & kCMTimeFlags_Valid) {
                if (_timeOffset.flags & kCMTimeFlags_Valid) {
                    pts = CMTimeSubtract(pts, _timeOffset);
                }
                CMTime offset = CMTimeSubtract(pts, last);
                if (_timeOffset.value == 0) {
                    _timeOffset = offset;
                } else {
                    _timeOffset = CMTimeAdd(_timeOffset, offset);
                }
            }
            _lastVideo.flags = (CMTimeFlags) 0;
            _lastAudio.flags = (CMTimeFlags) 0;
        }

        // 增加sampleBuffer的引用计时,这样我们可以释放这个或修改这个数据，防止在修改时被释放
        CFRetain(sampleBuffer);
        if (_timeOffset.value > 0) {
            CFRelease(sampleBuffer);
            //根据得到的timeOffset调整
            sampleBuffer = [self adjustTime:sampleBuffer offset:_timeOffset];
        }

        // 记录暂停上一次录制的时间
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMTime dur = CMSampleBufferGetDuration(sampleBuffer);

        // NSLog(@"%zd", pts.value);
        if (dur.value > 0) {
            pts = CMTimeAdd(pts, dur);
        }

        if (bufferType == BufferTypeVideo) {
            _lastVideo = pts;
        } else {
            _lastAudio = pts;
        }
    }

    dispatch_async(_writingQueue, ^{
        CMTime dur = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        if (self.startTime.value == 0) {
            self.startTime = dur;
            _firstTimingInfo = [self firstTimingInfo:sampleBuffer];
        }
        CMTime sub = CMTimeSubtract(dur, self.startTime);
        self.currentRecordTime = CMTimeGetSeconds(sub);

        // 进行数据编码
        [self.videoEncoder encoderSampleBuffer:sampleBuffer bufferType:bufferType];

        CFRelease(sampleBuffer);
    });
}

@end
