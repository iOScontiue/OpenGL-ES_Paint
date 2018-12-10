//
//  TestView.m
//  OpenGL ES Test
//
//  Created by 卢育彪 on 2018/11/29.
//  Copyright © 2018年 luyubiao. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <GLKit/GLKit.h>

#import "TestView.h"
#import "debug.h"
#import "shaderUtil.h"
#import "fileUtil.h"

//画笔透明度
#define kBrushOpacity (1.0/2.0)
//画笔像素点
#define kBrushPixelStep 2
//画笔比例
#define kBrushScale 2

enum{
    PROGRAME_POINT,
    NUM_PROGRAMS
};

enum{
    UNIFORM_MVP,
    UNIFORM_POINT_SIZE,
    UNIFORM_VERTEX_COLOR,
    UNIFORM_TEXTURE,
    NUM_UNIFORMS
};

enum{
    ATTRIB_VERTEX,
    NUM_ATTRIBS
};

typedef struct {
    //vert、frag分别指向顶点、片元着色器程序文件
    char *vert, *frag;
    GLint uniform[NUM_UNIFORMS];
    GLuint id;
}programInfo_t;

programInfo_t program[NUM_PROGRAMS] = {
    {"point.vsh", "point.fsh"}
};

//纹理
typedef struct {
    GLuint id;
    GLsizei width, height;
}textureInfo_t;

@implementation TestPoint

- (instancetype)initWithCGPoint:(CGPoint)point
{
    self = [super init];
    if (self) {
        self.mX = [NSNumber numberWithDouble:point.x];
        self.mY = [NSNumber numberWithDouble:point.y];
    }
    return self;
}

@end

@interface TestView()
{
    //后备缓冲区像素尺寸
    GLint backingWidth;
    GLint backingHeight;
    
    EAGLContext *context;
    
    GLuint viewRenderBuffer, viewFrameBuffer;
    
    //画笔纹理、颜色
    textureInfo_t brushTexture;
    GLfloat brushColor[4];
    
    Boolean firstTouch;
    Boolean needsErase;
    
    //顶点着色器、片元着色器、着色器总线
    GLuint vertexShader;
    GLuint fragmentShader;
    GLuint shaderProgram;
    
    //顶点缓冲区
    GLuint vboID;
    
    BOOL initialized;
    NSMutableArray *CCArr;
}

@end

@implementation TestView

//改变layer类型
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

//从nib文件加载
- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;
        
        /*设置layer属性
         kEAGLDrawablePropertyRetainedBacking：表示绘图表面显示后，是否保留其内容；
         kEAGLDrawablePropertyColorFormat：绘制表面内部缓冲区颜色格式
         */
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!context || ![EAGLContext setCurrentContext:context]) {
            NSLog(@"Error:set context fail");
            return nil;
        }
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
        needsErase = YES;
    }
    return self;
}

- (void)layoutSubviews
{
    [EAGLContext setCurrentContext:context];
    
    if (!initialized) {
        //如果没有初始化，则对OpenGL初始化
        initialized = [self initGL];
    } else {
        //如果已经初始化，则调整layer
        [self resizeFromLayer:(CAEAGLLayer *)self.layer];
    }
    
    //清楚帧第一次分配
    if (needsErase) {
        [self erase];
        needsErase = NO;
    }
}

- (BOOL)initGL
{
    //渲染缓存区配置：申请标志符、绑定标志符、分配内存
    glGenRenderbuffers(1, &viewRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderBuffer);
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(id<EAGLDrawable>)self.layer];
    
    //帧缓存区配置：申请标志符、绑定标志符、绑定渲染缓存区到GL_COLOR_ATTACHMENT0上
    glGenFramebuffers(1, &viewFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, viewFrameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, viewRenderBuffer);
    
    //获取渲染缓存区的像素宽高并将其存储在backingWidth和backingHeight上
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    //检查帧缓存区状态
    GLenum result = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (result != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Check frameBuffer complete failed!");
        return NO;
    }
    
    //设置视口
    glViewport(0, 0, backingWidth, backingHeight);
    
    //申请顶点缓存区标志
    glGenBuffers(1, &vboID);
    //加载画笔纹理
    brushTexture = [self textureFromName:@"Particle.png"];
    //加载着色器
    [self setupShaders];
    
    //设置点模糊效果：开启混合模式并设置混合函数
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    //回放“加油”字样！
    NSString *path = [[NSBundle mainBundle] pathForResource:@"abc" ofType:@"string"];
    NSString *str = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    CCArr = [NSMutableArray array];
    NSArray *jsonArr = [NSJSONSerialization JSONObjectWithData:[str dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
    for (NSDictionary *dict in jsonArr) {
        TestPoint *point = [TestPoint new];
        point.mX = [dict objectForKey:@"mX"];
        point.mY = [dict objectForKey:@"mY"];
        [CCArr addObject:point];
    }
    
    //延时0.5秒绘制“加油”字样
    [self performSelector:@selector(paint) withObject:nil afterDelay:0.5];
    
    return YES;
    
}

- (void)paint
{
    //从0开始遍历顶点，步长2
    for (int i = 0; i < CCArr.count-1; i += 2) {
        TestPoint *cp1 = CCArr[i];
        TestPoint *cp2 = CCArr[i+1];
        CGPoint p1,p2;
        p1.x = cp1.mX.floatValue;
        p1.y = cp1.mY.floatValue;
        p2.x = cp2.mX.floatValue;
        p2.y = cp2.mY.floatValue;
        //触摸绘制线条
        [self renderLineFromPoint:p1 toPoint:p2];
    }
}

- (void)renderLineFromPoint:(CGPoint)start toPoint:(CGPoint)end
{
    //顶点缓存区
    static GLfloat *vertexBuffer = NULL;
    //顶点Max
    static NSUInteger vertexMax = 64;
    //顶点个数
    NSUInteger vertexCount = 0,count;
    CGFloat scale = self.contentScaleFactor;
    
    //点到像素转换：乘以比例因子
    start.x *= scale;
    start.y *= scale;
    end.x *= scale;
    end.y *= scale;
    
    //开辟顶点缓存区
    if (vertexBuffer == NULL) {
        vertexBuffer = malloc(vertexMax*2*sizeof(GLfloat));
    }
    
    //求得两点之间的距离
    float seq = sqrtf((end.x-start.x)*(end.x-start.x)+(end.y-start.y)*(end.y-start.y));
    /*向上取整：求得距离要产生多少个点
     kBrushPixelStep值越大，笔触越细；值越小，笔触越粗
     */
    NSInteger pointCount = ceil(seq/kBrushPixelStep);
    count = MAX(pointCount, 1);
    
    for (int i = 0; i < count; i++) {
        if (vertexCount == vertexMax) {
            //修改2倍增长
            vertexMax = 2*vertexMax;
            vertexBuffer = realloc(vertexBuffer, vertexMax*2*sizeof(GLfloat));
        }
        
        //计算两个之间的距离有多少个点，并存储在顶点缓存区中
        vertexBuffer[2*vertexCount+0] = start.x+(end.x-start.x)*((GLfloat)i/(GLfloat)count);
        vertexBuffer[2*vertexCount+1] = start.y+(end.y-start.y)*((GLfloat)i/(GLfloat)count);
        
        vertexCount++;
    }
    
    //绑定顶点数据
    glBindBuffer(GL_ARRAY_BUFFER, vboID);
    //将数据从CPU中复制到GPU中提供给OpenGL使用
    glBufferData(GL_ARRAY_BUFFER, vertexCount*2*sizeof(GLfloat), vertexBuffer, GL_DYNAMIC_DRAW);
    
    //启用指定属性
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    //链接顶点属性
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 2*sizeof(GLfloat), 0);
    
    //使用数据总线：传递顶点数据到顶点着色器
    glUseProgram(program[PROGRAME_POINT].id);
    //绘制顶点：绘制模型、起始点、顶点个数
    glDrawArrays(GL_POINTS, 0, (int)vertexCount);
    //绑定渲染缓存区到特定标志符上
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderBuffer);
    //开始渲染
    [context presentRenderbuffer:GL_RENDERBUFFER];
    
}

- (textureInfo_t)textureFromName:(NSString *)name
{
    CGImageRef brushImage;
    CGContextRef brushContext;
    GLubyte *brushData;
    size_t width, height;
    GLuint texID;
    textureInfo_t texture;
    
    brushImage = [UIImage imageNamed:name].CGImage;
    width = CGImageGetWidth(brushImage);
    height = CGImageGetHeight(brushImage);
    //开辟纹理图片内存
    brushData = (GLubyte *)calloc(width*height*4, sizeof(GLubyte));
    
    /*创建位图上下文
     参数：图片内存地址、图片宽、图片高、像素组件位数（一般设置8），每一行所占比特数、颜色空间、颜色通道
     */
    brushContext = CGBitmapContextCreate(brushData, width, height, 8, width*4, CGImageGetColorSpace(brushImage), kCGImageAlphaPremultipliedLast);
    
    //绘图
    CGContextDrawImage(brushContext, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height), brushImage);
    //释放上下文
    CGContextRelease(brushContext);
    
    //申请纹理标志符
    glGenTextures(1, &texID);
    //绑定纹理
    glBindTexture(GL_TEXTURE_2D, texID);
    //设置纹理属性：缩小滤波器、线性滤波器
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    /*生成2D纹理图片
     参数：纹理目标、图像级别（0为基本级别）、颜色组件（GL_RGBA、GL_ALPHA）、图像宽、图像高、边框宽度（一般为0）、像素数据颜色格式、像素数据类型、内存中指向图像数据指针
     */
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, brushData);
    
    free(brushData);
    
    //配置纹理属性
    texture.id = texID;
    texture.width = (int)width;
    texture.height = (int)height;
    
    return texture;
}

- (void)setupShaders
{
    for (int i = 0; i < NUM_PROGRAMS; i++) {
        
        //读取顶点着色器程序
        char *vsrc = readFile(pathForResource(program[i].vert));
        //读取片元着色器程序
        char *fsrc = readFile(pathForResource(program[i].frag));
        NSString *vsrcStr = [[NSString alloc] initWithBytes:vsrc length:strlen(vsrc)-1 encoding:NSUTF8StringEncoding];
        NSString *fsrcStr = [[NSString alloc] initWithBytes:fsrc length:strlen(fsrc)-1 encoding:NSUTF8StringEncoding];
        NSLog(@"vsrcStr------%@", vsrcStr);
        NSLog(@"fsrcStr------%@", fsrcStr);
        
        GLsizei attribCt = 0;
        GLchar *attribUsed[NUM_ATTRIBS];
        GLint attrib[NUM_ATTRIBS];
        GLchar *attribName[NUM_ATTRIBS] = {
            "inVertex"
        };
        
        const char *uniformName[NUM_UNIFORMS] = {
            "MVP","pointSize","vertexColor", "texture"
        };
        
        for (int j = 0; j < NUM_ATTRIBS; j++) {
            if (strstr(vsrc, attribName[j])) {
                attrib[attribCt] = j;
                attribUsed[attribCt++] = attribName[j];
            }
        }
        
        //program处理：创建、链接、生成
        glueCreateProgram(vsrc, fsrc, attribCt, (const char **)&attribUsed[0], attrib, NUM_UNIFORMS, &uniformName[0], program[i].uniform, &program[i].id);
        
        free(vsrc);
        free(fsrc);
        
        if (i == PROGRAME_POINT) {
            glUseProgram(program[PROGRAME_POINT].id);
           //为当前程序指定uniform变量
            glUniform1i(program[PROGRAME_POINT].uniform[UNIFORM_TEXTURE], 0);
            
            //设置正射投影矩阵
            GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
            //创建模型视图矩阵：单元矩阵
            GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
            //正射投影矩阵与模型视图矩阵相乘，结果保存在MVPMatrix矩阵中
            GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
           
           /*为当前程序指定Uniform变量值
            参数：指明要更改的Uniform变量的位置、将要被修改的矩阵的数量、矩阵值被载入变量时是否要对举证进行变换（如转置）、将要用于更新uniform变量MVP的数组指针
            */
            glUniformMatrix4fv(program[PROGRAME_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
           //为当前程序对象Uniform变量的pointSize赋值
            glUniform1f(program[PROGRAME_POINT].uniform[UNIFORM_POINT_SIZE], brushTexture.width/kBrushScale);
            //为当前程序对象Uniform变量顶点颜色赋值
            glUniform4fv(program[PROGRAME_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor);
            
        }
    }
    
    glError();
}

- (BOOL)resizeFromLayer:(CAEAGLLayer *)layer
{
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderBuffer);
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    GLenum result = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (result != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Check frameBuffer complete failed! %x", result);
        return NO;
    }
    
    GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, backingWidth, 0, backingHeight, -1, 1);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    /*为当前成秀对象指定uniform变量
     参数：指明要更改的uniform变量的位置（MVP）、将要被修改的矩阵数量、矩阵值被载入变量时是否要对举证进行变换（如转置）、用于更新uniform变量的数组指针
     */
    glUniformMatrix4fv(program[PROGRAME_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
    
    //更新视口
    glViewport(0, 0, backingWidth, backingHeight);
    
    return YES;
}

- (void)erase
{
    //清楚帧缓存区
    glBindFramebuffer(GL_FRAMEBUFFER, viewFrameBuffer);
    //设置窗口背景颜色
    glClearColor(0.0, 0.0, 0.0, 1.0);
    //清楚颜色缓存
    glClear(GL_COLOR_BUFFER_BIT);
    
    //绑定渲染缓存区
    glBindRenderbuffer(GL_RENDERBUFFER, viewRenderBuffer);
    //提交渲染
    [context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)setBrushColorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue
{
    //更新画笔颜色：颜色*透明度
    brushColor[0] = red*kBrushOpacity;
    brushColor[1] = green*kBrushOpacity;
    brushColor[2] = blue*kBrushOpacity;
    brushColor[3] = kBrushOpacity;
    
    if (initialized) {
        //使用数据总线：将顶点数据传递到顶点着色器
        glUseProgram(program[PROGRAME_POINT].id);
        //为当前程序对象uniform变量顶点颜色赋值
        glUniform4fv(program[PROGRAME_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, brushColor);
    }
}

- (void)dealloc
{
    //释放缓存区并置空
    if (viewRenderBuffer) {
        glDeleteBuffers(1, &viewRenderBuffer);
        viewRenderBuffer = 0;
    }
    
    if (viewFrameBuffer) {
        glDeleteBuffers(1, &viewFrameBuffer);
        viewFrameBuffer = 0;
    }
    
    //释放顶点缓存区
    if (vboID) {
        glDeleteBuffers(1, &vboID);
        vboID = 0;
    }
    
    //释放纹理
    if (brushTexture.id) {
        glDeleteTextures(1, &brushTexture.id);
        brushTexture.id = 0;
    }
    
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
}

#pragma mark -
#pragma mark - touch clicks

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [[event touchesForView:self] anyObject];
    _location = [touch locationInView:self];
    //获取当前点击位置
    _location.y = self.bounds.size.height-_location.y;
    firstTouch = YES;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [[event touchesForView:self] anyObject];
    if (firstTouch) {
        firstTouch = NO;
    } else {
        _location = [touch locationInView:self];
        _location.y = self.bounds.size.height - _location.y;
    }
    //获取上一个顶点
    _previousLocation = [touch previousLocationInView:self];
    _previousLocation.y = self.bounds.size.height - _previousLocation.y;
    
    //将_previousLocation和_location两个顶点绘制成线条
    [self renderLineFromPoint:_previousLocation toPoint:_location];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [[event touchesForView:self] anyObject];
    if (firstTouch) {
        firstTouch = NO;
        _previousLocation = [touch previousLocationInView:self];
        _previousLocation.y = self.bounds.size.height-_previousLocation.y;
        [self renderLineFromPoint:_previousLocation toPoint:_location];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    NSLog(@"Touch cancelled");
}

- (BOOL)canBecomeFirstResponder
{
    //复写方法：设置成第一响应者
    return YES;
}

@end
