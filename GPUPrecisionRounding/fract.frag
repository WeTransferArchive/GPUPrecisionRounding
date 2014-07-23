#extension GL_EXT_shader_framebuffer_fetch : require

precision highp float;

varying highp vec2 TexCoordOut;
uniform highp sampler2D Texture;

uniform highp float u_Threshold;

void main(void) {
    vec4 color = texture2D(Texture, TexCoordOut);
    
    float threshold = float(abs(color.x - gl_LastFragData[0].x) >= 0.5/255.0);
    
    color = color + TexCoordOut.y / 255.0;
    
    // uncomment the following line for correct rounding on A7 GPUs
    // color = (color * 255.0 + 0.5) / 256.0;
    
    gl_FragColor = (1.0 - u_Threshold) * color + u_Threshold * vec4(threshold, threshold, threshold, 1.0);
}