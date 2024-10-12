package raycaster

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:slice"
import rl "vendor:raylib"

SCREEN_WIDTH :: 600
SCREEN_HEIGHT :: 600
SCREEN_RATIO :: SCREEN_WIDTH / SCREEN_HEIGHT
Vw :: 1
Vh :: 1
DIST: f32 = 1.0
BACKGROUND_COLOR :: [3]u8{0, 0, 0}

viewport_size :: 1 * 1
projection_plane_d :: 1

vec3 :: [3]f32

Sphere :: struct {
    center:     [3]f32,
    radius:     f32,
    color:      [3]u8,
    specular:   i16,
    reflective: f32,
}
spheres := [?]Sphere {
    Sphere {
        center = {0, -1, 3},
        radius = 1,
        color = {255, 0, 0},
        specular = 500,
        reflective = 0.2,
    },
    Sphere {
        center = {2, 0, 4},
        radius = 1,
        color = {0, 0, 255},
        specular = 500,
        reflective = 0.3,
    },
    Sphere {
        center = {-2, 0, 4},
        radius = 1,
        color = {0, 255, 0},
        specular = 10,
        reflective = 0.4,
    },
    Sphere {
        color = {255, 255, 0},
        center = {0, -5001, 0},
        radius = 5000,
        specular = 1000,
        reflective = 0.5,
    },
}

Light :: struct {
    type:      enum {
        Ambient,
        Point,
        Directional,
    },
    intensity: f32,
    vector:    [3]f32,
}
lights := [?]Light {
    Light{type = .Ambient, intensity = 0.2},
    Light{type = .Point, intensity = 0.6, vector = {2, 1, 0}},
    Light{type = .Directional, intensity = 0.2, vector = {1, 4, 4}},
}

RECURSION_DEPTH :: 3

data: [SCREEN_WIDTH * SCREEN_HEIGHT * 4]u8

prev_log_timestamp: f64

log :: proc(args: ..any) {
    if prev_log_timestamp + 0.2 < rl.GetTime() {
        prev_log_timestamp = rl.GetTime()
        fmt.println(..args)
    }
}

put_pixel :: proc(x, y: int, color: [3]f32) {
    buff_x := SCREEN_WIDTH / 2 + x
    buff_y := SCREEN_HEIGHT / 2 - y
    base := (buff_y * SCREEN_WIDTH + buff_x) * 4
    if (0 <= base && base + 4 < len(data)) {
        data[base + 0] = u8(color[0])
        data[base + 1] = u8(color[1])
        data[base + 2] = u8(color[2])
        data[base + 3] = 255
    }
}

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "test")

    image := rl.LoadImageFromScreen()
    texture := rl.LoadTextureFromImage(image)
    // rl.SetTargetFPS(120)
    fmt.println(texture)

    // rl.SetTargetFPS(60)

    b := [3]f32{-200, -250, 1}
    a := [3]f32{200, 50, 1}
    c := [3]f32{20, 250, 1}

    cnt := 0
    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        rl.ClearBackground(rl.WHITE)

        if rl.IsKeyDown(.LEFT) do b.x -= 1
        if rl.IsKeyDown(.RIGHT) do b.x += 1
        if rl.IsKeyDown(.UP) do b.y += 1
        if rl.IsKeyDown(.DOWN) do b.y -= 1

        if rl.IsKeyDown(.A) do a.x -= 1
        if rl.IsKeyDown(.D) do a.x += 1
        if rl.IsKeyDown(.W) do a.y += 1
        if rl.IsKeyDown(.S) do a.y -= 1

        data = {}

        // if rl.IsKeyDown(.W) {
        //     DIST += 0.01
        // }
        // if rl.IsKeyDown(.S) {
        //     DIST -= 0.01
        // }

        // run_raytracing()
        triangle(a, b, c, {{255, 0, 0}, {0, 255, 0}, {0, 0, 255}})

        rl.UpdateTexture(texture, &data)
        rl.DrawTexture(texture, 0, 0, rl.WHITE)

        rl.DrawFPS(0, 0)
        rl.EndDrawing()
        cnt += 1
    }

    rl.CloseWindow()
}
