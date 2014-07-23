precision highp float;

varying highp vec2 TexCoordOut;
uniform highp sampler2D Texture;

void main(void) {
    gl_FragColor = texture2D(Texture, TexCoordOut);
}