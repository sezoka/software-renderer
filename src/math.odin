package main
import "core:math"
import "core:math/linalg"

Vec2 :: [2]f32
Vec3 :: [3]f32

vec3_rotate_x :: proc(v: Vec3, angle: f32) -> Vec3 {
    return {
        v.x,
        v.y * math.cos(angle) - v.z * math.sin(angle),
        v.y * math.sin(angle) + v.z * math.cos(angle),
    }
}

vec3_rotate_y :: proc(v: Vec3, angle: f32) -> Vec3 {
    return {
        v.x * math.cos(angle) - v.z * math.sin(angle),
        v.y,
        v.x * math.sin(angle) + v.z * math.cos(angle),
    }
}

vec3_rotate_z :: proc(v: Vec3, angle: f32) -> Vec3 {
    return {
        v.x * math.cos(angle) - v.y * math.sin(angle),
        v.x * math.sin(angle) + v.y * math.cos(angle),
        v.z,
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
