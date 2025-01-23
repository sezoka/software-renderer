#version 330 core
layout(location = 0) in vec2 a_pos;

out vec2 tex_coord;

void main() {
    gl_Position = vec4(a_pos, 0, 1.0);
    tex_coord = a_pos;
}
