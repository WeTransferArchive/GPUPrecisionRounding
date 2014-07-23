#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <OpenGLES/ES3/gl.h>
#include <OpenGLES/ES3/glext.h>

@interface OpenGLView : UIView {
    UIApplication *app;
    CAEAGLLayer* _eaglLayer;
    EAGLContext* _context;
    GLuint _colorRenderBuffer;
    GLuint _positionSlot;
    GLuint _colorSlot;
    GLuint _projectionUniform;
    GLuint _modelViewUniform;
    float  _currentRotation;
    GLuint _depthRenderBuffer;
    
    GLuint _mainFbo;
    GLuint _fbo0, _fbo1, _outputFbo;
    
    BOOL shouldDrawToFbo0;
    BOOL _firstFrame;
    
    GLuint _fboTexture0, _fboTexture1, _outputTexture, _colorTexture;
    GLuint _texCoordSlot;
    GLuint _textureUniform;
    GLuint _vertexBuffer;
    GLuint _indexBuffer;
    GLuint _vertexBuffer2;
    GLuint _indexBuffer2;
    GLuint _idleFrames;
    GLuint _totalFrames;
    
    GLuint _blitShader;
    GLuint _fractShader;
}

- (id)initWithFrame:(CGRect)frame withScaleFactor:(CGFloat)scale;

@end
