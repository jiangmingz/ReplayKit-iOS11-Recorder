//
//  MMAudioRecord.m
//  MMLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "MMAudioRecord.h"

@interface MMAudioRecord () {
    AudioStreamBasicDescription _desc;
    dispatch_queue_t _taskQueue;
    NSTimeInterval _startTime;
}

@property(nonatomic, assign) AudioComponentInstance componetInstance;
@property(nonatomic, assign) AudioComponent component;
@property(nonatomic, assign) BOOL isRunning;
@property(nonatomic, assign) BOOL running;

@end

@implementation MMAudioRecord

#pragma mark -- LiftCycle

- (instancetype)init {
    self = [super init];
    if (self) {
        self.isRunning = NO;
        _taskQueue = dispatch_queue_create("com.waqu.audio.Queue", NULL);

        AVAudioSession *session = [AVAudioSession sharedInstance];


        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:session];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleInterruption:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:session];

        AudioComponentDescription acd;
        acd.componentType = kAudioUnitType_Output;
        acd.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
        acd.componentSubType = kAudioUnitSubType_RemoteIO;
        acd.componentManufacturer = kAudioUnitManufacturer_Apple;
        acd.componentFlags = 0;
        acd.componentFlagsMask = 0;

        self.component = AudioComponentFindNext(NULL, &acd);

        OSStatus status = noErr;
        status = AudioComponentInstanceNew(self.component, &_componetInstance);

        if (noErr != status) {
            [self handleAudioComponentCreationFailure];
        }

        UInt32 flagOne = 1;

        AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &flagOne, sizeof(flagOne));

        AudioStreamBasicDescription desc = {0};
        desc.mSampleRate = 44100;
        desc.mFormatID = kAudioFormatLinearPCM;
        desc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        desc.mChannelsPerFrame = 2;
        desc.mFramesPerPacket = 1;
        desc.mBitsPerChannel = 16;
        desc.mBytesPerFrame = desc.mBitsPerChannel / 8 * desc.mChannelsPerFrame;
        desc.mBytesPerPacket = desc.mBytesPerFrame * desc.mFramesPerPacket;
        _desc = desc;

        AURenderCallbackStruct cb;
        cb.inputProcRefCon = (__bridge void *) (self);
        cb.inputProc = handleInputBuffer;
        AudioUnitSetProperty(self.componetInstance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &desc, sizeof(desc));
        AudioUnitSetProperty(self.componetInstance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &cb, sizeof(cb));

        const UInt32 zero = 0;
        const UInt32 one = 1;
        const UInt32 kInputBus = 1;
        AudioUnitSetProperty(self.componetInstance, kAUVoiceIOProperty_BypassVoiceProcessing, kAudioUnitScope_Global, kInputBus, &zero, sizeof(zero));
        AudioUnitSetProperty(self.componetInstance, kAUVoiceIOProperty_VoiceProcessingEnableAGC, kAudioUnitScope_Global, kInputBus, &one, sizeof(one));
        AudioUnitSetProperty(self.componetInstance, kAUVoiceIOProperty_DuckNonVoiceAudio, kAudioUnitScope_Global, kInputBus, &one, sizeof(one));

        status = AudioUnitInitialize(self.componetInstance);
        if (noErr != status) {
            [self handleAudioComponentCreationFailure];
        }

        [session setPreferredSampleRate:44100 error:nil];
        [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:nil];
        [session setActive:YES withOptions:kAudioSessionSetActiveFlag_NotifyOthersOnDeactivation error:nil];

        [session setActive:YES error:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    dispatch_sync(_taskQueue, ^{
        if (self.componetInstance) {
            self.isRunning = NO;
            AudioOutputUnitStop(self.componetInstance);
            AudioComponentInstanceDispose(self.componetInstance);
            self.componetInstance = nil;
            self.component = nil;
        }
    });
}

- (void)startRunning {
    [self setRunning:YES];
}

- (void)stopRunning {
    [self setRunning:NO];
}

#pragma mark -- Setter

- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    _running = running;
    if (_running) {
        dispatch_async(_taskQueue, ^{
            self.isRunning = YES;
            NSLog(@"MicrophoneSource: startRunning");
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionInterruptSpokenAudioAndMixWithOthers error:nil];
            AudioOutputUnitStart(self.componetInstance);
        });
    } else {
        dispatch_sync(_taskQueue, ^{
            self.isRunning = NO;
            NSLog(@"MicrophoneSource: stopRunning");
            AudioOutputUnitStop(self.componetInstance);
        });
    }
}

#pragma mark -- CustomMethod

- (void)handleAudioComponentCreationFailure {

}

#pragma mark -- NSNotification

- (void)handleRouteChange:(NSNotification *)notification {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSString *seccReason = @"";
    NSInteger reason = [[notification userInfo][AVAudioSessionRouteChangeReasonKey] integerValue];
    //  AVAudioSessionRouteDescription* prevRoute = [[notification userInfo] objectForKey:AVAudioSessionRouteChangePreviousRouteKey];
    switch (reason) {
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            seccReason = @"The route changed because no suitable route is now available for the specified category.";
            break;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            seccReason = @"The route changed when the device woke up from sleep.";
            break;
        case AVAudioSessionRouteChangeReasonOverride:
            seccReason = @"The output route was overridden by the app.";
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            seccReason = @"The category of the session object changed.";
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            seccReason = @"The previous audio output path is no longer available.";
            break;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            seccReason = @"A preferred new audio output path is now available.";
            break;
        case AVAudioSessionRouteChangeReasonUnknown:
        default:
            seccReason = @"The reason for the change is unknown.";
            break;
    }
    NSLog(@"handleRouteChange reason is %@", seccReason);

    AVAudioSessionPortDescription *input = ([session.currentRoute.inputs count] ? session.currentRoute.inputs : nil)[0];
    if (input.portType == AVAudioSessionPortHeadsetMic) {

    }
}

- (void)handleInterruption:(NSNotification *)notification {
    NSInteger reason = 0;
    NSString *reasonStr = @"";
    if ([notification.name isEqualToString:AVAudioSessionInterruptionNotification]) {
        //Posted when an audio interruption occurs.
        reason = [[notification userInfo][AVAudioSessionInterruptionTypeKey] integerValue];
        if (reason == AVAudioSessionInterruptionTypeBegan) {
            if (self.isRunning) {
                dispatch_sync(_taskQueue, ^{
                    NSLog(@"MicrophoneSource: stopRunning");
                    AudioOutputUnitStop(self.componetInstance);
                });
            }
        }

        if (reason == AVAudioSessionInterruptionTypeEnded) {
            reasonStr = @"AVAudioSessionInterruptionTypeEnded";
            NSNumber *seccondReason = [notification userInfo][AVAudioSessionInterruptionOptionKey];
            switch ([seccondReason integerValue]) {
                case AVAudioSessionInterruptionOptionShouldResume:
                    if (self.isRunning) {
                        dispatch_async(_taskQueue, ^{
                            NSLog(@"MicrophoneSource: startRunning");
                            AudioOutputUnitStart(self.componetInstance);
                        });
                    }
                    // Indicates that the audio session is active and immediately ready to be used. Your app can resume the audio operation that was interrupted.
                    break;
                default:
                    break;
            }
        }

    };
    NSLog(@"handleInterruption: %@ reason %@", [notification name], reasonStr);
}

#pragma mark -- CallBack

static OSStatus handleInputBuffer(void *inRefCon,
        AudioUnitRenderActionFlags *ioActionFlags,
        const AudioTimeStamp *inTimeStamp,
        UInt32 inBusNumber,
        UInt32 inNumberFrames,
        AudioBufferList *ioData) {
    @autoreleasepool {
        MMAudioRecord *source = (__bridge MMAudioRecord *) inRefCon;
        if (!source) return -1;

        AudioStreamBasicDescription asbd = source->_desc;
        CMSampleBufferRef buff = NULL;
        CMFormatDescriptionRef format = NULL;

        OSStatus status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &asbd, 0, NULL, 0, NULL, NULL, &format);
        if (status) {
            return status;
        }

        CMSampleTimingInfo timing = {CMTimeMake(1, 44100), kCMTimeZero, kCMTimeInvalid};
        status = CMSampleBufferCreate(kCFAllocatorDefault, NULL, false, NULL, NULL, format, (CMItemCount) inNumberFrames, 1, &timing, 0, NULL, &buff);
        if (status) { //失败
            return status;
        }

        AudioBuffer buffer;
        buffer.mData = NULL;
        buffer.mDataByteSize = 0;
        buffer.mNumberChannels = 2;

        AudioBufferList buffers;
        buffers.mNumberBuffers = 1;
        buffers.mBuffers[0] = buffer;

        status = AudioUnitRender(source.componetInstance,
                ioActionFlags,
                inTimeStamp,
                inBusNumber,
                inNumberFrames,
                &buffers);
        if (status) {
            return status;
        }

        status = CMSampleBufferSetDataBufferFromAudioBufferList(buff, kCFAllocatorDefault, kCFAllocatorDefault, 0, &buffers);
        if (!status) {
            NSTimeInterval recordTime = inTimeStamp->mSampleTime / asbd.mSampleRate;
            if ([source.delegate respondsToSelector:@selector(audioSampleBuffer:recordTime:)]) {
                [source.delegate audioSampleBuffer:buff recordTime:recordTime];
            }
        }

        return status;
    }
}

@end
