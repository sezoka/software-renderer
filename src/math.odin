package main
import "core:math"
import "core:math/linalg"

Vec2 :: [2]f32
Vec2i :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

Mat4 :: matrix[4, 4]f32

vec3_rotate_x :: proc(v: Vec4, angle: f32) -> Vec4 {
    return {
        v.x,
        v.y * math.cos(angle) - v.z * math.sin(angle),
        v.y * math.sin(angle) + v.z * math.cos(angle),
        v.w,
    }
}

vec3_rotate_y :: proc(v: Vec4, angle: f32) -> Vec4 {
    return {
        v.x * math.cos(angle) - v.z * math.sin(angle),
        v.y,
        v.x * math.sin(angle) + v.z * math.cos(angle),
        v.w,
    }
}

vec3_rotate_z :: proc(v: Vec4, angle: f32) -> Vec4 {
    return {
        v.x * math.cos(angle) - v.y * math.sin(angle),
        v.x * math.sin(angle) + v.y * math.cos(angle),
        v.z,
        v.w,
    }
}

length_vec2 :: proc(v: Vec2) -> f32 {
    return math.sqrt(v.x * v.x + v.y * v.y)
}

length_vec3 :: proc(v: Vec3) -> f32 {
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
}

cross_vec3 :: proc(a, b: Vec3) -> Vec3 {
    return {
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
    }
}

dot_vec3 :: proc(a, b: Vec3) -> f32 {
    return (a.x * b.x) + (a.y * b.y) + (a.z * b.z)
}

dot_vec2 :: proc(a, b: Vec2) -> f32 {
    return (a.x * b.x) + (a.y * b.y)
}

make_scale_matrix :: proc(v: Vec3) -> Mat4 {
    return matrix[4, 4]f32{
        v.x, 0, 0, 0, 
        0, v.y, 0, 0, 
        0, 0, v.z, 0, 
        0, 0, 0, 1, 
    }
}

make_translation_matrix :: proc(v: Vec3) -> Mat4 {
    return matrix[4, 4]f32{
        1, 0, 0, v.x, 
        0, 1, 0, v.y, 
        0, 0, 1, v.z, 
        0, 0, 0, 1, 
    }
}

make_rotation_x_matrix :: proc(angle: f32) -> Mat4 {
    c := math.cos(angle)
    s := math.sin(angle)
    return matrix[4, 4]f32{
        1, 0, 0, 0, 
        0, c, -s, 0, 
        0, s, c, 0, 
        0, 0, 0, 1, 
    }
}

make_rotation_y_matrix :: proc(angle: f32) -> Mat4 {
    c := math.cos(angle)
    s := math.sin(angle)
    return matrix[4, 4]f32{
        c, 0, s, 0, 
        0, 1, 0, 0, 
        -s, 0, c, 0, 
        0, 0, 0, 1, 
    }
}

make_rotation_z_matrix :: proc(angle: f32) -> Mat4 {
    c := math.cos(angle)
    s := math.sin(angle)
    return matrix[4, 4]f32{
        c, -s, 0, 0, 
        s, c, 0, 0, 
        0, 0, 1, 0, 
        0, 0, 0, 1, 
    }
}

make_rotation_matrix :: proc(angle: Vec3) -> Mat4 {
    return(
        make_rotation_x_matrix(angle.x) *
        make_rotation_y_matrix(angle.y) *
        make_rotation_z_matrix(angle.z) \
    )
}

make_projection_matrix :: proc(fov, aspect_ratio, z_near, z_far: f32) -> Mat4 {
    perspective_scale_factor := 1 / math.tan(fov / 2)
    z_clipping_stuff := z_far / (z_far - z_near)
    return matrix[4, 4]f32{
        aspect_ratio * perspective_scale_factor, 0, 0, 0, 
        0, perspective_scale_factor, 0, 0, 
        0, 0, z_clipping_stuff, (-z_far * z_near) / (z_far - z_near), 
        0, 0, 1, 0, 
    }
}

do_perspective_divide :: proc(vec: Vec4) -> Vec4 {
    if vec.w != 0 {
        return {vec.x / vec.w, vec.y / vec.w, vec.z / vec.w, vec.w}
    }
    return vec
}
