//
//  SoundEffect.h
//  OpenGL ES Test
//
//  Created by 卢育彪 on 2018/12/6.
//  Copyright © 2018年 luyubiao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioServices.h>

NS_ASSUME_NONNULL_BEGIN

@interface SoundEffect : NSObject
{
    SystemSoundID _soundID;
}

+ (id)soundEffectWithContentsOfFile:(NSString *)path;
- (id)initWithContentsOfFile:(NSString *)path;
- (void)play;

@end

NS_ASSUME_NONNULL_END
