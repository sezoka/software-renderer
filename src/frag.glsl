#version 330 core
out vec4 frag;

uniform sampler2D texture_1;
in vec2 tex_coord;

void main() {
    frag = texture(texture_1, tex_coord);
}
