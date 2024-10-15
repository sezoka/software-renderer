package raycaster

import "core:fmt"
import tga "core:image/tga"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:slice"
import rl "vendor:raylib"

SCREEN_WIDTH :: 640
SCREEN_HEIGHT :: 640
SCREEN_RATIO :: SCREEN_WIDTH / SCREEN_HEIGHT
Vw :: 1
Vh :: 1
DIST: f32 = 1.0
BACKGROUND_COLOR :: [3]u8{0, 0, 0}

VIEWPORT_WIDTH :: 1
VIEWPORT_HEIGHT :: 1

viewport_size :: 1 * 1
projection_plane_d :: 1
depth: f32 = 255

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

put_pixel :: proc(x, y: int, color: [3]u8) {
    buff_x := x
    buff_y := SCREEN_HEIGHT - y
    base := (buff_y * SCREEN_WIDTH + buff_x) * 4
    if (0 <= base && base + 4 < len(data)) {
        data[base + 0] = u8(color[0])
        data[base + 1] = u8(color[1])
        data[base + 2] = u8(color[2])
        data[base + 3] = 255
    }
}

z_buffer: [SCREEN_WIDTH * SCREEN_HEIGHT]f32

Texture :: struct {
    w, h: i32,
    data: []u8,
}

viewport_projection :: proc(x, y, w, h: f32) -> matrix[4, 4]f32 {
    // x, y, w, h := math.trunc(x), math.trunc(y), math.trunc(w), math.trunc(h)
    return matrix[4, 4]f32{
        w / 2, 0, 0, x + w / 2, 
        0, h / 2, 0, y + h / 2, 
        0, 0, depth / 2, depth / 2, 
        0, 0, 0, 1, 
    }
}

light_dir: [3]f32 = {0, 0, -1}
camera: [3]f32 = {0, 0, 3}

m2v :: proc(m: matrix[4, 1]f32) -> vec3 {
    return {
        math.trunc(m[0, 0] / m[3, 0]),
        math.trunc(m[1, 0] / m[3, 0]),
        math.trunc(m[2, 0] / m[3, 0]),
    }
}

v2m :: proc(v: vec3) -> matrix[4, 1]f32 {
    m: matrix[4, 1]f32
    m[0, 0] = v.x
    m[1, 0] = v.y
    m[2, 0] = v.z
    m[3, 0] = 1
    return m
}

main :: proc() {
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "test")

    image := rl.LoadImageFromScreen()
    texture := rl.LoadTextureFromImage(image)
    // rl.SetTargetFPS(120)
    // fmt.println(texture)

    // rl.SetTargetFPS(60)

    a := [3]f32{0, 250, 1}
    b := [3]f32{-250, -250, 1}
    c := [3]f32{250, -250, 1}

    african_head_diffuse_tga := #load("./african_head_diffuse.tga")
    african_head_diffuse, err := tga.load_from_bytes(african_head_diffuse_tga)
    fmt.println(">", african_head_diffuse.channels)
    model := rl.LoadModel("./african_head.obj").meshes[0]
    // fmt.println(model.texcoords[0:model.vertexCount * 2 + 10])


    cnt := 0
    for !rl.WindowShouldClose() {
        viewport := viewport_projection(
            SCREEN_WIDTH / 8,
            SCREEN_HEIGHT / 8,
            SCREEN_WIDTH * 3 / 4,
            SCREEN_HEIGHT * 3 / 4,
        )
        projection := linalg.MATRIX4F32_IDENTITY
        projection[3, 2] = -1 / camera.z

        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)

        if rl.IsKeyDown(.LEFT) do b.x -= 1
        if rl.IsKeyDown(.RIGHT) do b.x += 1
        if rl.IsKeyDown(.UP) do b.y += 1
        if rl.IsKeyDown(.DOWN) do b.y -= 1

        if rl.IsKeyDown(.W) do camera.z += 0.01
        if rl.IsKeyDown(.S) do camera.z -= 0.01
        if rl.IsKeyDown(.A) do camera.x -= 0.1
        if rl.IsKeyDown(.D) do camera.x += 0.1

        data = {}

        // if rl.IsKeyDown(.W) {
        //     DIST += 0.01
        // }
        // if rl.IsKeyDown(.S) {
        //     DIST -= 0.01
        // }

        // run_raytracing()
        // triangle(a, b, c, {{255, 0, 0}, {0, 255, 0}, {0, 0, 255}})
        // draw_cube()

        // triangle = 3 vertices
        // vertex = 2floats

        slice.fill(z_buffer[:], -math.F32_MAX)


        for vert_start: i32 = 0;
            vert_start < model.vertexCount;
            vert_start += 3 {

            face: [3][3]f32
            tex_uvs: [3][2]f32

            for point_start in 0 ..< i32(3) {
                face[point_start] = {
                    model.vertices[vert_start * 3 + point_start * 3],
                    model.vertices[vert_start * 3 + point_start * 3 + 1],
                    model.vertices[vert_start * 3 + point_start * 3 + 2],
                }
                // fmt.println(vert_start, (vert_start * 3 + point_start) * 2)
                tex_uvs[point_start] = {
                    model.texcoords[(vert_start + point_start) * 2],
                    model.texcoords[(vert_start + point_start) * 2 + 1],
                }
            }
            // fmt.println(tex_uvs)


            screen_coords: [3][3]f32
            world_coords: [3][3]f32
            for j: i32 = 0; j < 3; j += 1 {
                v := face[j]
                screen_coords[j] = m2v(viewport * projection * v2m(v))
                world_coords[j] = v
            }

            n := linalg.vector_cross3(
                (world_coords[2] - world_coords[0]),
                (world_coords[1] - world_coords[0]),
            )
            n = linalg.vector_normalize(n)

            // fmt.println(screen_coords)
            intensity := linalg.dot(n, light_dir)

            if 0 < intensity {
                triangle(
                    screen_coords,
                    {intensity * 255, intensity * 255, intensity * 255},
                    tex_uvs,
                    Texture {
                        w = i32(african_head_diffuse.width),
                        h = i32(african_head_diffuse.height),
                        data = african_head_diffuse.pixels.buf[:],
                    },
                )
            }
        }

        rl.UpdateTexture(texture, &data)
        rl.DrawTexture(texture, 0, 0, rl.WHITE)

        rl.DrawFPS(0, 0)
        rl.EndDrawing()
        cnt += 1
    }

    rl.CloseWindow()
}
