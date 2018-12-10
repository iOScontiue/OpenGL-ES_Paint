//
//  SoundEffect.m
//  OpenGL ES Test
//
//  Created by 卢育彪 on 2018/12/6.
//  Copyright © 2018年 luyubiao. All rights reserved.
//

#import "SoundEffect.h"

@implementation SoundEffect

+ (id)soundEffectWithContentsOfFile:(NSString *)path
{
    if (path) {
        return [[SoundEffect alloc] initWithContentsOfFile:path];
    }
    return nil;
}

- (id)initWithContentsOfFile:(NSString *)path
{
    self = [super init];
    if (self != nil) {
        NSURL *fileURL = [NSURL fileURLWithPath:path isDirectory:NO];
        if (fileURL != nil) {
            SystemSoundID aSoundID;
            OSStatus error = AudioServicesCreateSystemSoundID((__bridge CFURLRef _Nonnull)(fileURL), &aSoundID);
            if (error == kAudioServicesNoError) {
                _soundID = aSoundID;
            } else {
                NSLog(@"Error:loading sound path,%d, %@", (int)error, path);
                self = nil;
            }
        } else {
            NSLog(@"URL is nil for path %@", path);
            self = nil;
        }
    }
    
    return self;
}

- (void)dealloc
{
    AudioServicesDisposeSystemSoundID(_soundID);
}

- (void)play
{
    AudioServicesPlaySystemSound(_soundID);
}

@end
