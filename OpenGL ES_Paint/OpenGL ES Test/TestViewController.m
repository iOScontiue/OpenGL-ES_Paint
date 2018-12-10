//
//  TestViewController.m
//  OpenGL ES Test
//
//  Created by 卢育彪 on 2018/11/29.
//  Copyright © 2018年 luyubiao. All rights reserved.
//

#import "TestViewController.h"
#import "TestView.h"
#import "SoundEffect.h"

//颜色亮度
#define kBrightness 1.0
//颜色饱和度
#define kSaturation 0.45
//最小擦除区间
#define kMinEraseInterval 0.5

//调色板设置
#define kPaletteHeight 30//高度
#define kPaletteSize 5//大小
#define kLeftMargin 10.0//左边缘
#define kTopMargin 10.0//上边缘
#define kRightMargin 10.0//右边缘

@interface TestViewController ()
{
    //清楚屏幕声音
    SoundEffect *erasingSound;
    //选择屏幕声音
    SoundEffect *selectSound;
    CFTimeInterval lastTime;
}

@end


@implementation TestViewController

-(void)viewDidLoad
{
    [super viewDidLoad];
    [self configUI];
}

- (void)configUI
{
    UIButton *clearBtn = [[UIButton alloc] initWithFrame:CGRectMake((self.view.frame.size.width-150)/2.0, 50, 150, 50)];
    clearBtn.backgroundColor = [UIColor purpleColor];
    [clearBtn setTitle:@"清空" forState:UIControlStateNormal];
    [clearBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.view addSubview:clearBtn];
    [clearBtn addTarget:self action:@selector(clearClick:) forControlEvents:UIControlEventTouchUpInside];
    
    //调色板颜色图片
    UIImage *redImg = [[UIImage imageNamed:@"Red"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    UIImage *yellowImg = [[UIImage imageNamed:@"Yellow"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    UIImage *greenImg = [[UIImage imageNamed:@"Green"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    UIImage *blueImg = [[UIImage imageNamed:@"Blue"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    NSArray *selectColorImgArr = @[redImg, yellowImg, greenImg, blueImg];
    
    //分段控件
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:selectColorImgArr];
    CGRect rect = [[UIScreen mainScreen] bounds];
    CGRect frame = CGRectMake(rect.origin.x+kLeftMargin, rect.size.height-kPaletteHeight-kTopMargin, rect.size.width-kLeftMargin-kRightMargin, kPaletteHeight);
    segmentedControl.frame = frame;
    //改变画笔颜色
    [segmentedControl addTarget:self action:@selector(changeBrushColor:) forControlEvents:UIControlEventValueChanged];
    segmentedControl.tintColor = [UIColor darkGrayColor];
    segmentedControl.selectedSegmentIndex = 2;
    [self.view addSubview:segmentedControl];
    
    //定义起始颜色：色调、饱和度、亮度
    CGColorRef color = [UIColor colorWithHue:(CGFloat)2.0/(CGFloat)kPaletteSize saturation:kSaturation brightness:kBrightness alpha:1.0].CGColor;
    //根据颜色h值，返回相关的颜色组件RGBA
    const CGFloat *components = CGColorGetComponents(color);
    //根据OpenGL视图设置画笔颜色
    [(TestView *)self.view setBrushColorWithRed:components[0] green:components[1] blue:components[2]];
    
    //加载系统声音：选择颜色/清空
    NSString *erasePath = [[NSBundle mainBundle] pathForResource:@"Erase" ofType:@"caf"];
    NSString *selectPath = [[NSBundle mainBundle] pathForResource:@"Select" ofType:@"caf"];
    selectSound = [[SoundEffect alloc] initWithContentsOfFile:selectPath];
    erasingSound = [[SoundEffect alloc] initWithContentsOfFile:erasePath];
}

- (void)changeBrushColor:(UISegmentedControl *)sender
{
    [selectSound play];
    //定义新的画笔颜色：创建并返回一个颜色对象使用指定的不透明的HSB颜色空间的分量值
    CGColorRef color = [UIColor colorWithHue:(CGFloat)sender.selectedSegmentIndex/(CGFloat)kPaletteSize saturation:kSaturation brightness:kBrightness alpha:1.0].CGColor;
    const CGFloat *components = CGColorGetComponents(color);
    [(TestView *)self.view setBrushColorWithRed:components[0] green:components[1] blue:components[2]];
}

- (void)clearClick:(UIButton *)sender
{
    //防止一直不停地点击
    if (CFAbsoluteTimeGetCurrent() > lastTime + kMinEraseInterval) {
        //播放声音
        [erasingSound play];
        //清理屏幕
        [(TestView *)self.view erase];
        //保存当前时间
        lastTime = CFAbsoluteTimeGetCurrent();
    }
}

@end
