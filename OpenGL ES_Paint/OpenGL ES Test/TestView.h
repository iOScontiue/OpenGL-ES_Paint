//
//  TestView.h
//  OpenGL ES Test
//
//  Created by 卢育彪 on 2018/11/29.
//  Copyright © 2018年 luyubiao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface TestPoint : NSObject

@property (nonatomic, strong) NSNumber *mX;
@property (nonatomic, strong) NSNumber *mY;

@end

@interface TestView : UIView

@property (nonatomic, readwrite) CGPoint location;
@property (nonatomic, readwrite) CGPoint previousLocation;

- (void)erase;
- (void)setBrushColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue;
- (void)paint;

@end

