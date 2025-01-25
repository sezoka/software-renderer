package main

import "core:fmt"
import "core:math"
import "core:math/linalg"

DEFAULT_YAW: f32 : 90

DEFAULT_PITCH: f32 : 0
DEFAULT_SPEED :: 3
DEFAULT_FOV :: 90

Direction :: enum {
    Forward,
    Backward,
    Left,
    Right,
    Up,
    Down,
}
Direction_Set :: bit_set[Direction]

Camera :: struct {
    fov:          f32,
    pos:          Vec3,
    front:        Vec3,
    up:           Vec3,
    near_frustum: f32,
    far_frustum:  f32,
    viewport_w:   f32,
    viewport_h:   f32,
}

Fps_Camera :: struct {
    using base:     Camera,
    right:          Vec3,
    world_up:       Vec3,
    yaw:            f32,
    pitch:          f32,
    movement_speed: f32,
    mouse_sens:     f32,
    speed:          f32,
}

make_fps_camera :: proc(
    viewport_w: u32,
    viewport_h: u32,
    pos := Vec3{0, 0, 0},
    world_up := Vec3{0, 1, 0},
    yaw := DEFAULT_YAW,
    pitch := DEFAULT_PITCH,
    near_frustum: f32 = 0.01,
    far_frustum: f32 = 100,
    fov: f32 = DEFAULT_FOV,
    mouse_sensitivity: f32 = 0.1,
) -> (
    camera: Fps_Camera,
) {
    camera = Fps_Camera {
        pos          = pos,
        world_up     = world_up,
        yaw          = yaw,
        pitch        = pitch,
        fov          = fov,
        near_frustum = near_frustum,
        far_frustum  = far_frustum,
        viewport_w   = f32(viewport_w),
        viewport_h   = f32(viewport_h),
        mouse_sens   = mouse_sensitivity,
    }
    update_fps_camera(&camera)
    return camera
}

process_keyboard_fps_camera :: proc(
    c: ^Fps_Camera,
    delta: f32,
    direction: Direction_Set,
) {
    dir: Vec3
    flat_front := linalg.normalize(Vec3{c.front.x, 0, c.front.z})
    if .Forward in direction do dir += flat_front
    if .Backward in direction do dir -= flat_front
    if .Left in direction do dir -= c.right
    if .Right in direction do dir += c.right
    if .Up in direction do dir.y += 1
    if .Down in direction do dir.y -= 1
    if dir != {} {
        c.pos += DEFAULT_SPEED * delta * linalg.normalize(dir)
    }
}

process_mouse_fps_camera :: proc(c: ^Fps_Camera, xoffs, yoffs: f32) {
    xoffs, yoffs := xoffs, yoffs

    xoffs *= c.mouse_sens
    yoffs *= c.mouse_sens

    c.yaw -= xoffs
    c.pitch -= yoffs

    if c.pitch > 89.0 do c.pitch = 89.0
    if c.pitch < -89.0 do c.pitch = -89.0

    //c.front = calculate_camera_front(c)
    //fmt.println(c.front, c.yaw)
}

update_fps_camera :: proc(c: ^Fps_Camera) {
    // calculate the new Front vector
    c.front = calculate_camera_front(c)
    // also re-calculate the Right and Up vector
    c.right = linalg.normalize(linalg.cross(c.world_up, c.front)) // normalize the vectors, because their length gets closer to 0 the more you look up or down which results in slower movement.
    c.up = linalg.normalize(linalg.cross(c.right, c.front))
}

calculate_camera_front :: proc(c: ^Fps_Camera) -> Vec3 {
    return linalg.normalize(
        Vec3 {
            math.cos(math.to_radians(c.yaw)) *
            math.cos(math.to_radians(c.pitch)),
            math.sin(math.to_radians(c.pitch)),
            math.sin(math.to_radians(c.yaw)) *
            math.cos(math.to_radians(c.pitch)),
        },
    )

}
