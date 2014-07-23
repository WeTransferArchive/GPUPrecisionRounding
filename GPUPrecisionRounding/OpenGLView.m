#import "OpenGLView.h"
#import <GLKit/GLKit.h>

@implementation OpenGLView

const int nIdleFrames = 1;
const int nTotalFrames = 1;

NSString *filename = @"Art/ramp255.png";

enum
{
    UNIFORM_OFFSET,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

typedef struct {
    float Position[3];
    float Color[4];
    float TexCoord[2]; // New
} Vertex;

#define TEX_COORD_MAX   1
#define TEX_OFFSET 0.001

#define TEXTURE_FILTER GL_NEAREST

const Vertex Vertices[] = {
    {{ 1, -1, 0}, {1, 0, 0, 0}, {TEX_COORD_MAX, 0}},
    {{ 1,  1, 0}, {0, 1, 0, 0}, {TEX_COORD_MAX, TEX_COORD_MAX}},
    {{-1,  1, 0}, {0, 0, 1, 0}, {0, TEX_COORD_MAX}},
    {{-1, -1, 0}, {0, 0, 0, 0}, {0, 0}}
};

const GLubyte Indices[] = {
    0, 1, 2,
    2, 3, 0,
};

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)setupLayer {
    _eaglLayer = (CAEAGLLayer*) self.layer;
    _eaglLayer.opaque = YES;
}

- (void)setupContext {   
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
}

- (void)setupDisplayLink {
    CADisplayLink* displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render:)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)setupRenderBuffer {
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);        
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
}

- (GLuint) setupFrameBuffer {
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);   
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderBuffer);
    
    return framebuffer;
}

- (GLuint)compileShader:(NSString*)shaderName withType:(GLenum)shaderType {
    
    NSString* shaderPath;
    switch (shaderType)
    {
        case GL_VERTEX_SHADER:
            shaderPath = [[NSBundle mainBundle] pathForResource:shaderName ofType:@"vert"];
            break;
        case GL_FRAGMENT_SHADER:
            shaderPath = [[NSBundle mainBundle] pathForResource:shaderName ofType:@"frag"];
            break;
        default:
            break;
    }

    NSError* error;
    NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        exit(1);
    }
    
    GLuint shaderHandle = glCreateShader(shaderType);
    
    const char * shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = [shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    glCompileShader(shaderHandle);
    
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    return shaderHandle;
}

- (GLuint)compileShadersWithName:(NSString *) name {
    
    GLuint vertexShader = [self compileShader:name withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:name withType:GL_FRAGMENT_SHADER];
    
    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    glLinkProgram(programHandle);
    
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    glUseProgram(programHandle);
    
    uniforms[UNIFORM_OFFSET] = glGetUniformLocation(programHandle, "u_Offset");

    return programHandle;
}

- (void)setupVBOs {
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
    
    glGenBuffers(1, &_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
}


-(UIImage*)snapshot
{
    GLint backingWidth1, backingHeight1;
    
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth1);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight1);
    
    NSInteger x = 0, y = 0, width = backingWidth1, height = backingHeight1;
    NSInteger dataLength = width * height * 4;
    GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
    
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(x, y, width, height, GL_RGBA, GL_UNSIGNED_BYTE, data);
    
    CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef iref = CGImageCreate(width, height, 8, 32, width * 4, colorspace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                    ref, NULL, true, kCGRenderingIntentDefault);
    
    NSInteger widthInPoints, heightInPoints;
    if (NULL != UIGraphicsBeginImageContextWithOptions) {
        CGFloat scale = self.contentScaleFactor;
        widthInPoints = width / scale;
        heightInPoints = height / scale;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(widthInPoints, heightInPoints), NO, scale);
    }
    else
    {
        widthInPoints = width;
        heightInPoints = height;
        UIGraphicsBeginImageContext(CGSizeMake(widthInPoints, heightInPoints));
    }
    
    CGContextRef cgcontext = UIGraphicsGetCurrentContext();
    
    CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
    CGContextDrawImage(cgcontext, CGRectMake(0.0, 0.0, widthInPoints, heightInPoints), iref);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    free(data);
    CFRelease(ref);
    CFRelease(colorspace);
    CGImageRelease(iref);
    
    return image;
}

-(void) storeToPhotoAlbumWithFbo: (GLuint)fbo
{
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);

    UIImage *img = [self snapshot];
    
    NSData* imdata =  UIImagePNGRepresentation ( img ); // get PNG representation
    UIImage* im2 = [UIImage imageWithData:imdata]; // wrap UIImage around PNG representation
    UIImageWriteToSavedPhotosAlbum(im2, nil, nil, nil); // save to photo album
}

- (void)blitFromTexture:(GLuint)texture toFbo:(GLuint)fbo
{
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    
    GLuint program = _blitShader;
    glUseProgram(program);
    
    glEnableVertexAttribArray(glGetAttribLocation(program, "Position"));
    glEnableVertexAttribArray(glGetAttribLocation(program, "TexCoordIn"));
    glVertexAttribPointer(glGetAttribLocation(program, "Position"), 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
    glVertexAttribPointer(glGetAttribLocation(program, "TexCoordIn"), 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid*) (sizeof(float) * 7));
    
    glActiveTexture(GL_TEXTURE0);
    
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        
    glDisable(GL_BLEND);
    
    glDisable(GL_DEPTH_TEST);
        
    glBindTexture(GL_TEXTURE_2D, texture);
    
    glUniform1i(_textureUniform, 0);
    
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]), GL_UNSIGNED_BYTE, 0);
}

- (void)fractBlitFromTexture:(GLuint)texture toFbo:(GLuint)fbo withThreshold:(GLfloat)threshold
{
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    
    GLuint program = _fractShader;
    
    glUseProgram(program);
    
    glEnableVertexAttribArray(glGetAttribLocation(program, "Position"));
    glEnableVertexAttribArray(glGetAttribLocation(program, "TexCoordIn"));
    glVertexAttribPointer(glGetAttribLocation(program, "Position"),
                          3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
    glVertexAttribPointer(glGetAttribLocation(program, "TexCoordIn"),
                          2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid*) (sizeof(float) * 7));
    
    glActiveTexture(GL_TEXTURE0);
    
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    
    glDisable(GL_BLEND);
    
    glDisable(GL_DEPTH_TEST);
    
    glBindTexture(GL_TEXTURE_2D, texture);
    
    glUniform1f(glGetUniformLocation(program, "u_Threshold"), threshold);
    
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]), GL_UNSIGNED_BYTE, 0);
}



- (void)render:(CADisplayLink*)displayLink {
    
    glViewport(0, 0, self.contentScaleFactor * self.frame.size.width, self.contentScaleFactor * self.frame.size.height);
    
    if (_firstFrame)
    {
        [self fractBlitFromTexture:_colorTexture toFbo:_outputFbo withThreshold:0.0f];
        
        [self fractBlitFromTexture:_colorTexture toFbo:_outputFbo withThreshold:1.0f];
        [self storeToPhotoAlbumWithFbo:_outputFbo];

        [self blitFromTexture:_outputTexture toFbo:_mainFbo];

        
        _firstFrame = false;
    }
    
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (GLuint)loadTexture:(NSString *)fileName
{
    NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:NO],
                             GLKTextureLoaderOriginBottomLeft,
                             nil];
    
    NSError* error;
    NSString* path = [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
    GLKTextureInfo* texture = [GLKTextureLoader textureWithContentsOfFile:path options:options error:&error];
    if(texture == nil)
    {
        NSLog(@"Error loading file: %@", [error localizedDescription]);
    }
    
    glBindTexture(GL_TEXTURE_2D, texture.name);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, TEXTURE_FILTER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, TEXTURE_FILTER);

    return texture.name;
}

- (GLuint)createFramebufferWithTexture:(GLuint)texture
{
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    
    GLint width;
    GLint height;
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &width);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &height);
    
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER) ;
    if(status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete framebuffer object %x", status);
    }
    return framebuffer;
}

- (GLuint) createTexture8
{
    GLint width;
    GLint height;
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &width);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &height);
    
    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, TEXTURE_FILTER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, TEXTURE_FILTER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,  width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
    return texture;
}

- (id)initWithFrame:(CGRect)frame withScaleFactor:(CGFloat)scale
{
    self = [super initWithFrame:frame];
    if (self) {
        self.contentScaleFactor = scale;
        
        [self setupLayer];
        [self setupContext];
        [self setupRenderBuffer];
        _mainFbo = [self setupFrameBuffer];
        _blitShader = [self compileShadersWithName:@"blit"];
        _fractShader = [self compileShadersWithName:@"fract"];
        
        [self setupVBOs];
        [self setupDisplayLink];
        
        
        _colorTexture = [self loadTexture:filename];
        
        _outputTexture = [self createTexture8];
        _outputFbo = [self createFramebufferWithTexture:_outputTexture];
    }
    
    _idleFrames=nIdleFrames;
    _totalFrames=0;
    _firstFrame = TRUE;
    return self;
}

- (void)dealloc
{
    [_context release];
    _context = nil;
    [super dealloc];
}

@end
