//
//  ViewController.m
//  ReplayKit-iOS11-Recorder
//
//  Created by Anthony Agatiello on 7/21/17.
//  Copyright © 2017 Anthony Agatiello. All rights reserved.
//

#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>

#import "MMVideoCapture.h"

@interface ViewController ()

@property(strong, nonatomic) AVAudioPlayer *player;
@property(strong, nonatomic) RPScreenRecorder *screenRecorder;

@property(strong, nonatomic) MMVideoCapture *videoCapture;
@property(strong, nonatomic) UILabel *timeLabel;
@property(strong, nonatomic) NSTimer *timer;
@property(assign, nonatomic) NSInteger count;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 0, [UIScreen mainScreen].bounds.size.width, 44.0f)];
    self.timeLabel.textColor = [UIColor redColor];
    self.timeLabel.font = [UIFont systemFontOfSize:14.0f];
    self.timeLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.timeLabel];

    self.videoCapture = [MMVideoCapture new];

    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
}

- (void)test {
    self.count = self.count + 1;
    self.timeLabel.text = [NSString stringWithFormat:@"%zd", _count];
}

- (IBAction)startRecording:(UIButton *)button {

    NSString *path = [[NSBundle mainBundle] pathForResource:@"PrettyBoy" ofType:@"mp3"];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
    [self.player play];

    self.count = 0;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(test) userInfo:nil repeats:YES];
    [self.timer fire];

    [self startVideoRecord];
}

- (IBAction)stopRecording:(UIButton *)button {
    [self.timer invalidate];
    self.timer = nil;
    [self.player stop];

    [self stopVideoRecord];
}

- (void)startVideoRecord {
    [self.videoCapture startCapture];

    self.screenRecorder = [RPScreenRecorder sharedRecorder];
    [self.screenRecorder startCaptureWithHandler:^(CMSampleBufferRef _Nonnull sampleBuffer, RPSampleBufferType bufferType, NSError *_Nullable error) {
        if (!error) {
            if (bufferType != RPSampleBufferTypeVideo) {
                return;
            }

            NSLog(@"type -- >%zd", bufferType);
            [self.videoCapture captureOutput:(MMBufferType) bufferType didOutputSampleBuffer:sampleBuffer];
        }
    }                          completionHandler:^(NSError *_Nullable error) {
        if (!error) {
            NSLog(@"Recording started successfully.");
        }
    }];
}

- (void)stopVideoRecord {
    [self.screenRecorder stopCaptureWithHandler:^(NSError *_Nullable error) {
        if (!error) {
            NSLog(@"Recording stopped successfully");
            [self.videoCapture stopCapture];
        }
    }];
}

@end
