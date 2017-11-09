//
//  MMAudioRecord.h
//  MMLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol MMAudioRecordDelegate <NSObject>

- (void)audioSampleBuffer:(CMSampleBufferRef)sampleBuffer recordTime:(NSTimeInterval)recordTime;

@end

@interface MMAudioRecord : NSObject

@property(nullable, nonatomic, weak) id <MMAudioRecordDelegate> delegate;

- (void)startRunning;

- (void)stopRunning;

@end
