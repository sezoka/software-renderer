package main

import "../../sz/sc"
import "core:fmt"
import tga "core:image/tga"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:slice"
import "core:sys/linux"
import sdl "vendor:sdl2"
//import rl "vendor:raylib"

PIXEL_SIZE :: 4

screen_width: u32 = 1024
screen_height: u32 = 720
//color_buff: []u8
z_buff: []f32
fov :: math.PI
camera: Fps_Camera
delta_sum: f32
window: ^sdl.Window
window_surface: ^sdl.Surface
prev_timestamp: u32
delta: f32
frame_counter: u64
light: Light = {
    direction = {0, 0, 1},
}
model_texture: sc.Image

meshes: [dynamic]Mesh

Light :: struct {
    direction: Vec3,
    color:     Color,
}

Color :: [3]u8

Triangle :: [3]Vec3

populate_points :: proc() {
    append(&meshes, load_obj("./assets/player.obj"))
    cube_texture := sc.load_image("./assets/player.png", flip = true)
    model_texture = cube_texture
    fmt.println("VERTS: ", len(meshes[0].vertices))
    fmt.println("FACES: ", len(meshes[0].faces))
    fmt.println(">>", meshes[0].vertices)
    fmt.println(">>", meshes[0].faces)
}

is_running := true

main :: proc() {
    assert(0 <= sdl.Init({}))
    defer sdl.Quit()

    window = sdl.CreateWindow(
        "Rasterizer",
        0,
        0,
        800,
        600,
        {.MAXIMIZED, .BORDERLESS},
    )
    assert(window != nil)

    sdl.SetRelativeMouseMode(true)

    display_mode: sdl.DisplayMode
    sdl.GetCurrentDisplayMode(0, &display_mode)
    // HER
    screen_width = u32(display_mode.w)
    screen_height = u32(display_mode.h)

    sdl.SetWindowSize(window, i32(screen_width), i32(screen_height))
    sdl.SetWindowPosition(window, 0, 0)

    window_surface = sdl.GetWindowSurface(window)
    defer sdl.DestroyWindow(window)

    z_buff = make([]f32, screen_width * screen_height)

    defer delete(z_buff)

    populate_points()
    defer clear_raster_data()

    prev_timestamp = sdl.GetTicks()

    camera = make_fps_camera(screen_width, screen_height)

    for is_running {
        timestamp := sdl.GetTicks()
        delta = f32(timestamp - prev_timestamp) / 1000
        prev_timestamp = timestamp

        event: sdl.Event
        // Poll for events
        for sdl.PollEvent(&event) {
            // Check for quit event
            if event.type == .QUIT {
                is_running = false // Set running to false to exit the loop
            }
        }

        delta_sum += delta

        frame_counter += 1
        if 50 < frame_counter {
            frame_counter = 0
            fmt.println("FPS:", 1 / delta, "MS:", math.trunc(delta * 1000))
            fmt.println("POS: ", camera.pos.x, camera.pos.y, camera.pos.z)
        }


        sdl.LockSurface(window_surface)
        sdl.FillRect(window_surface, nil, 0)
        slice.fill(z_buff, math.F32_MAX)

        mouse_x, mouse_y: i32
        sdl.GetRelativeMouseState(&mouse_x, &mouse_y)

        state := sdl.GetKeyboardState(nil)
        process_mouse_fps_camera(&camera, f32(mouse_x), f32(mouse_y))
        camera_dir: Direction_Set
        if (state[sdl.SCANCODE_W] != 0) do camera_dir += {.Forward}
        if (state[sdl.SCANCODE_S] != 0) do camera_dir += {.Backward}
        if (state[sdl.SCANCODE_A] != 0) do camera_dir += {.Left}
        if (state[sdl.SCANCODE_D] != 0) do camera_dir += {.Right}
        if (state[sdl.SCANCODE_SPACE] != 0) do camera_dir += {.Up}
        if (state[sdl.SCANCODE_LSHIFT] != 0) do camera_dir += {.Down}
        process_keyboard_fps_camera(&camera, delta, camera_dir)

        update_fps_camera(&camera)

        render_meshes()

        //Uint32* pixels = (Uint32*)surface->pixels;
        //for (int i = 0; i < WIDTH * HEIGHT; ++i) {
        //    pixels[i] = 0xFF000000; // Black color (ARGB)
        //}
        //
        //// Example: Draw a red rectangle
        //for (int y = 100; y < 200; ++y) {
        //    for (int x = 100; x < 300; ++x) {
        //        pixels[y * surface->w + x] = 0xFFFF0000; // Red color (ARGB)
        //    }
        //}
        sdl.UnlockSurface(window_surface)

        sdl.UpdateWindowSurface(window)


        //delta_sum += rl.GetFrameTime()
        //rl.BeginDrawing()
        ////rl.ClearBackground(rl.BLACK)
        //clear_color_buffer_black()
        //rotation += rl.GetFrameTime()
        //
        //wireframe_rendering()
        //
        //rl.UpdateTexture(front_buff, raw_data(color_buff))
        //rl.DrawTexture(front_buff, 0, 0, rl.WHITE)
        //rl.DrawFPS(16, 16)
        //rl.EndDrawing()
    }
}

look_at :: proc(eye: Vec3, target: Vec3, up: Vec3) -> Mat4 {
    z := linalg.normalize(target - eye)
    x := linalg.normalize(linalg.cross(up, z))
    y := linalg.cross(z, x)

    return matrix[4, 4]f32{
        x.x, x.y, x.z, -dot_vec3(x, eye), 
        y.x, y.y, y.z, -dot_vec3(y, eye), 
        z.x, z.y, z.z, -dot_vec3(z, eye), 
        0, 0, 0, 1, 
    }
}

find_barycentric_coords :: #force_inline proc(
    a: [2]f32,
    b: [2]f32,
    c: [2]f32,
    p: [2]f32,
) -> (
    u: f32,
    v: f32,
    w: f32,
) {
    tmp := #force_inline linalg.cross(
        [3]f32{c.x - a.x, b.x - a.x, a.x - p.x},
        [3]f32{c.y - a.y, b.y - a.y, a.y - p.y},
    )
    return 1 - (tmp.x + tmp.y) / tmp.z, tmp.y / tmp.z, tmp.x / tmp.z
}


render_meshes :: proc() {
    projection_matrix := make_projection_matrix(
        1,
        f32(screen_height) / f32(screen_width),
        0.1,
        100,
    )

    for &mesh in meshes {
        //mesh.rotation.y += delta
        //mesh.translation.y = 5
        mesh.translation.z = 100

        view_matrix := look_at(
            camera.pos,
            camera.pos + camera.front,
            {0, 1, 0},
        )


        world_matrix :=
            linalg.matrix4_translate_f32(mesh.translation) *
            make_rotation_matrix(mesh.rotation) *
            linalg.matrix4_scale_f32(mesh.scale)

        //if true {
        //    fmt.println(">>>", make_scale_matrix(mesh.scale))
        //    is_running = false
        //    return
        //}

        for &face in mesh.faces {
            transformed_verts: [3]Vec3
            uvs: [3]Vec2

            for i in 0 ..< 3 {
                vert_idx := face.vert_ids[i] - 1
                uv_idx := face.uv_ids[i] - 1

                uvs[i] = mesh.uvs[uv_idx]
                vert_points := mesh.vertices[vert_idx]
                transformed_vert: Vec4 = {
                    vert_points.x,
                    vert_points.y,
                    vert_points.z,
                    1,
                }

                transformed_vert =
                    view_matrix * world_matrix * transformed_vert
                //transformed_points = vec3_rotate_x(
                //    transformed_points,
                //    mesh.rotation.x + delta_sum,
                //)
                //transformed_points = vec3_rotate_y(
                //    transformed_points,
                //    mesh.rotation.y + delta_sum,
                //)
                //transformed_points = vec3_rotate_z(
                //    transformed_points,
                //    mesh.rotation.z + delta_sum,
                //)
                transformed_verts[i] = transformed_vert.xyz
            }

            // backface culling
            vert_a := transformed_verts[0]
            vert_b := transformed_verts[1]
            vert_c := transformed_verts[2]
            vector_ab := vert_b - vert_a
            vector_ac := vert_c - vert_a
            normal_vector := linalg.normalize(cross_vec3(vector_ab, vector_ac))
            vert_to_camera_ray := Vec3{0, 0, 0} - vert_a
            dot_product := dot_vec3(vert_to_camera_ray, normal_vector)
            if dot_product < 0 do continue

            projected_points: [3]Vec4
            for &vert, i in transformed_verts {
                projected_point :=
                    (projection_matrix * Vec4{vert.x, vert.y, vert.z, 1})
                projected_points[i] = do_perspective_divide(projected_point)
                projected_points[i].y *= -1
                projected_points[i].x *= f32(screen_width / 2)
                projected_points[i].y *= f32(screen_height / 2)
                projected_points[i].x += f32(screen_width / 2)
                projected_points[i].y += f32(screen_height / 2)
            }

            light_intensity := -linalg.dot(normal_vector, light.direction)

            color := clamp_color(
                {
                    light_intensity * 255,
                    light_intensity * 255,
                    light_intensity * 255,
                },
            )

            //fmt.println(color, dot_product)

            //draw_triangle_wireframe(projected_points, {255, 255, 0})
            //draw_triangle(projected_points, color)
            draw_textured_triangle(
                {
                    {pos = projected_points[0], uv = uvs[0]},
                    {pos = projected_points[1], uv = uvs[1]},
                    {pos = projected_points[2], uv = uvs[2]},
                },
                model_texture,
            )
        }
    }

    //draw_triangle_wireframe(projected_points, {255, 255, 255})
    //draw_triangle(
    //    {{200, 200, 0, 0}, {300, 400, 0, 0}, {100, 500, 1, 0}},
    //    {100, 100, 100},
    //)

}

clamp_color :: proc(clr: Vec3) -> Color {
    return {
        u8(math.clamp(clr.r, 0, 255)),
        u8(math.clamp(clr.g, 0, 255)),
        u8(math.clamp(clr.b, 0, 255)),
    }
}

clear_raster_data :: proc() {
    delete(meshes)
}

draw_triangle_wireframe :: proc(t: [3]Vec4, color: Color) {
    t := t
    //t[0].z = math.floor(t[0].z - 0.01)
    //t[1].z = math.floor(t[1].z - 0.01)
    //t[2].z = math.floor(t[2].z - 0.01)
    draw_line(t[0].xyz, t[1].xyz, color)
    draw_line(t[1].xyz, t[2].xyz, color)
    draw_line(t[2].xyz, t[0].xyz, color)
}

draw_triangle :: proc(t: [3]Vec4, color: Color) {
    p0: Vec3 = {math.round(t[0].x), math.round(t[0].y), t[0].z}
    p1: Vec3 = {math.round(t[1].x), math.round(t[1].y), t[1].z}
    p2: Vec3 = {math.round(t[2].x), math.round(t[2].y), t[2].z}

    if p0.y > p1.y do p0, p1 = p1, p0
    if p1.y > p2.y do p1, p2 = p2, p1
    if p0.y > p1.y do p0, p1 = p1, p0
    assert(p0.y <= p1.y && p1.y <= p2.y && p0.y <= p2.y)

    x0, y0, z0 := p0.x, p0.y, p0.z
    x1, y1, z1 := p1.x, p1.y, p1.z
    x2, y2, z2 := p2.x, p2.y, p2.z

    mX := math.round(((x2 - x0) * (y1 - y0)) / (y2 - y0)) + x0
    mY := y1

    if y0 != y1 {
        triangle_slope_a := (x1 - x0) / (y1 - y0)
        triangle_slope_b := (mX - x0) / (mY - y0)
        z_slope_a := (z1 - z0) / (y1 - y0)
        z_slope_b := (z2 - z0) / (mY - y0)
        start_x := x0
        end_x := x0
        start_z := z0
        end_z := z0
        for y := y0; y <= y1; y += 1 {
            draw_line({start_x, y, start_z}, {end_x, y, end_z}, color)
            start_x += triangle_slope_a
            end_x += triangle_slope_b
            start_z += z_slope_a
            end_z += z_slope_b
        }
    }

    if y1 != y2 {
        triangle_slope_a := (x2 - x1) / (y2 - y1)
        triangle_slope_b := (x2 - mX) / (y2 - mY)
        z_slope_a := (z2 - z1) / (y2 - y1)
        z_slope_b := (z2 - z0) / (y2 - mY)
        start_x := x2
        end_x := x2
        start_z := z0
        end_z := z0
        for y := y2; y >= y1; y -= 1 {
            draw_line({start_x, y, start_z}, {end_x, y, end_z}, color)
            start_x -= triangle_slope_a
            end_x -= triangle_slope_b
            //start_z = z_slope_a
            //end_z = z_slope_b
        }
    }
}

Vertex :: struct {
    pos: Vec4,
    uv:  Vec2,
}

round_vec4 :: #force_inline proc(v: Vec4) -> Vec4 {
    return {math.round(v.x), math.round(v.y), v.z, v.w}
}

draw_texel :: #force_inline proc(
    x: f32,
    y: f32,
    p0: Vec4,
    p1: Vec4,
    p2: Vec4,
    uv0: Vec2,
    uv1: Vec2,
    uv2: Vec2,
    texture: sc.Image,
) {
    alpha, beta, gama := find_barycentric_coords(p0.xy, p1.xy, p2.xy, {x, y})

    interpolated_uv :=
        ((uv0 / p0.w) * alpha + (uv1 / p1.w) * beta + (uv2 / p2.w) * gama) *
        {f32(texture.w), f32(texture.h)}
    interpolated_recipocal_w :=
        (1 / p0.w) * alpha + (1 / p1.w) * beta + (1 / p2.w) * gama

    pixel_position_x := math.abs(interpolated_uv[0] / interpolated_recipocal_w)
    pixel_position_y := math.abs(interpolated_uv[1] / interpolated_recipocal_w)
    //fmt.println(tex_coord)
    pixel_color_offset :=
        (i32(pixel_position_x) + i32(pixel_position_y) * texture.w) * 4
    if uint(pixel_color_offset) < len(texture.data) {
        pixel_color: Color
        pixel_color[0] = texture.data[pixel_color_offset]
        pixel_color[1] = texture.data[pixel_color_offset + 1]
        pixel_color[2] = texture.data[pixel_color_offset + 2]


        x := i32(math.round(x))
        y := i32(math.round(y))
        //fmt.println(interpolated_recipocal_w)
        if check_z_buff(x, y, 1 - interpolated_recipocal_w) {
            draw_pixel(x, y, pixel_color)
        }
    }
}

draw_textured_triangle :: proc(t: [3]Vertex, texture: sc.Image) {
    t := t

    if t[0].pos.y > t[1].pos.y do t[0], t[1] = t[1], t[0]
    if t[1].pos.y > t[2].pos.y do t[1], t[2] = t[2], t[1]
    if t[0].pos.y > t[1].pos.y do t[0], t[1] = t[1], t[0]
    assert(
        t[0].pos.y <= t[1].pos.y &&
        t[1].pos.y <= t[2].pos.y &&
        t[0].pos.y <= t[2].pos.y,
    )

    p0 := round_vec4(t[0].pos)
    p1 := round_vec4(t[1].pos)
    p2 := round_vec4(t[2].pos)
    x0, y0, z0 := p0.x, p0.y, p0.z
    x1, y1, z1 := p1.x, p1.y, p1.z
    x2, y2, z2 := p2.x, p2.y, p2.z
    uv0 := t[0].uv
    uv1 := t[1].uv
    uv2 := t[2].uv

    if y1 - y0 != 0 {
        inv_slope_1: f32
        inv_slope_2: f32
        if y1 - y0 != 0 do inv_slope_1 = (x1 - x0) / math.abs(y1 - y0)
        if y2 - y0 != 0 do inv_slope_2 = (x2 - x0) / math.abs(y2 - y0)
        for y := y0; y < y1; y += 1 {
            x_start := x1 + (y - y1) * inv_slope_1
            x_end := x0 + (y - y0) * inv_slope_2
            if x_end < x_start {
                x_start, x_end = x_end, x_start
            }
            for x := x_start; x < x_end; x += 1 {
                draw_texel(x, y, p0, p1, p2, uv0, uv1, uv2, texture)
            }
        }
    }

    if y2 - y1 != 0 {
        inv_slope_1: f32
        inv_slope_2: f32
        if y2 - y1 != 0 do inv_slope_1 = (x2 - x1) / math.abs(y2 - y1)
        if y2 - y0 != 0 do inv_slope_2 = (x2 - x0) / math.abs(y2 - y0)

        for y := y1; y < y2; y += 1 {
            x_start := x1 + (y - y1) * inv_slope_1
            x_end := x0 + (y - y0) * inv_slope_2
            if x_end < x_start {
                x_start, x_end = x_end, x_start
            }
            for x := x_start; x < x_end; x += 1 {
                draw_texel(x, y, p0, p1, p2, uv0, uv1, uv2, texture)
            }
        }
    }

}

draw_line :: proc(a: Vec3, b: Vec3, color: Color) {
    a: Vec3 = {math.round(a.x), math.round(a.y), a.z}
    b: Vec3 = {math.round(b.x), math.round(b.y), b.z}
    delta_x := b.x - a.x
    delta_y := b.y - a.y
    slide_length :=
        math.abs(delta_x) < math.abs(delta_y) ? math.abs(delta_y) : math.abs(delta_x)
    step_x := delta_x / slide_length
    step_y := delta_y / slide_length
    step_z := (b.z - a.z) / slide_length
    x := a.x
    y := a.y
    z := a.z
    for i: u32 = 0; i <= u32(slide_length); i += 1 {
        if check_z_buff(i32(x), i32(y), z) {
            draw_pixel(i32(math.round(x)), i32(math.round(y)), color)
        }
        x += step_x
        y += step_y
        z += step_z
    }
}

check_z_buff :: #force_inline proc(x, y: i32, z: f32) -> bool {
    if 0 <= x && x < i32(screen_width) && 0 <= y && y < i32(screen_height) {
        ok := z < z_buff[u32(x) + u32(y) * screen_width]
        if ok {
            z_buff[u32(x) + u32(y) * screen_width] = z
        }
        return ok
    }
    return false
}

draw_pixel :: proc(x, y: i32, color: Color) #no_bounds_check {
    color_buff := cast([^]u8)window_surface.pixels
    if 0 <= x && x < i32(screen_width) && 0 <= y && y < i32(screen_height) {
        offset := (x + y * i32(screen_width)) * PIXEL_SIZE
        color_buff[offset] = color.b
        color_buff[offset + 1] = color.g
        color_buff[offset + 2] = color.r
        color_buff[offset + 3] = 255
    }
}

draw_rect :: proc(x, y, w, h: i32, color: Color) {
    for py in y ..< y + h {
        for px in x ..< x + w {
            draw_pixel(px, py, color)
        }
    }
}

clear_color_buffer_black :: proc() {
    mem.set(
        window_surface.pixels,
        0,
        int(window_surface.w * window_surface.h * PIXEL_SIZE),
    )
}

clear_color_buffer :: proc(color: Color) #no_bounds_check {
    for y in 0 ..< int(screen_height) {
        for x in 0 ..< int(screen_width) {
            draw_pixel(i32(x), i32(y), color)
        }
    }
}


//
//screen_width: i32 = 800
//screen_height: i32 = 800
//screen_ratio: f32 = f32(screen_width) / f32(screen_height)
//Vw :: 1
//Vh :: 1
//DIST: f32 = 1.0
//BACKGROUND_COLOR :: [3]u8{0, 0, 0}
//
//VIEWPORT_WIDTH :: 1
//VIEWPORT_HEIGHT :: 1
//
//viewport_size :: 1 * 1
//projection_plane_d :: 1
//depth: f32 = 255
//
//vec3 :: [3]f32
//
//Sphere :: struct {
//    center:     [3]f32,
//    radius:     f32,
//    color:      [3]u8,
//    specular:   i16,
//    reflective: f32,
//}
//spheres := [?]Sphere {
//    Sphere {
//        center = {0, -1, 3},
//        radius = 1,
//        color = {255, 0, 0},
//        specular = 500,
//        reflective = 0.2,
//    },
//    Sphere {
//        center = {2, 0, 4},
//        radius = 1,
//        color = {0, 0, 255},
//        specular = 500,
//        reflective = 0.3,
//    },
//    Sphere {
//        center = {-2, 0, 4},
//        radius = 1,
//        color = {0, 255, 0},
//        specular = 10,
//        reflective = 0.4,
//    },
//    Sphere {
//        color = {255, 255, 0},
//        center = {0, -5001, 0},
//        radius = 5000,
//        specular = 1000,
//        reflective = 0.5,
//    },
//}
//
//Light :: struct {
//    type:      enum {
//        Ambient,
//        Point,
//        Directional,
//    },
//    intensity: f32,
//    vector:    [3]f32,
//}
//lights := [?]Light {
//    Light{type = .Ambient, intensity = 0.2},
//    Light{type = .Point, intensity = 0.6, vector = {2, 1, 0}},
//    Light{type = .Directional, intensity = 0.2, vector = {1, 4, 4}},
//}
//
//RECURSION_DEPTH :: 3
//
//data: []u8
//z_buffer: []f32
//
//
//prev_log_timestamp: f64
//
//log :: proc(args: ..any) {
//    if prev_log_timestamp + 0.2 < rl.GetTime() {
//        prev_log_timestamp = rl.GetTime()
//        fmt.println(..args)
//    }
//}
//
//put_pixel :: #force_inline proc(x, y: i32, color: [3]u8) {
//    buff_x := x
//    buff_y := i32(screen_height) - y
//    base := (buff_y * screen_width + buff_x) * 4
//    if (0 <= base && int(base + 4) < len(data)) {
//        data[base + 0] = u8(color[0])
//        data[base + 1] = u8(color[1])
//        data[base + 2] = u8(color[2])
//        data[base + 3] = 255
//    }
//}
//
//
//Texture :: struct {
//    w, h: i32,
//    data: []u8,
//}
//
//viewport_projection :: proc(x, y, w, h: f32) -> matrix[4, 4]f32 {
//    // x, y, w, h := math.trunc(x), math.trunc(y), math.trunc(w), math.trunc(h)
//    return matrix[4, 4]f32{
//        w / 2, 0, 0, x + w / 2, 
//        0, h / 2, 0, y + h / 2, 
//        0, 0, depth / 2, depth / 2, 
//        0, 0, 0, 1, 
//    }
//}
//
//light_dir: [3]f32 = linalg.normalize([3]f32{1, -1, 1})
//
//m2v :: proc(m: matrix[4, 1]f32) -> vec3 {
//    return {m[0, 0] / m[3, 0], m[1, 0] / m[3, 0], m[2, 0] / m[3, 0]}
//}
//
//v2m :: proc(v: vec3) -> matrix[4, 1]f32 {
//    m: matrix[4, 1]f32
//    m[0, 0] = v.x
//    m[1, 0] = v.y
//    m[2, 0] = v.z
//    m[3, 0] = 1
//    return m
//}
//
//lookat :: proc(eye, center, up: vec3) -> matrix[4, 4]f32 {
//    z := linalg.normalize(eye - center)
//    x := linalg.normalize(linalg.cross(up, z))
//    y := linalg.normalize(linalg.cross(z, x))
//    res := linalg.MATRIX4F32_IDENTITY
//    for i in 0 ..< 3 {
//        res[0][i] = x[i]
//        res[1][i] = y[i]
//        res[2][i] = z[i]
//        res[i][3] = -center[i]
//    }
//    return res
//}
//
//main :: proc() {
//    screen_width, screen_height =
//        i32(800), i32(600)
//    rl.InitWindow(screen_width, screen_height, "test")
//    data = make([]u8, screen_width * screen_height)
//    z_buffer = make([]f32, screen_width * screen_height)
//    fmt.println("SDFSDF")
//
//    image := rl.LoadImageFromScreen()
//    texture := rl.LoadTextureFromImage(image)
//    // rl.SetTargetFPS(120)
//    // fmt.println(texture)
//
//    // rl.SetTargetFPS(60)
//
//    a := [3]f32{0, 250, 1}
//    b := [3]f32{-250, -250, 1}
//    c := [3]f32{250, -250, 1}
//
//    african_head_diffuse_tga := #load("./african_head_diffuse.tga")
//    african_head_diffuse, err := tga.load_from_bytes(african_head_diffuse_tga)
//    // fmt.println(">", african_head_diffuse.channels)
//    model := rl.LoadModel("./african_head.obj").meshes[0]
//
//    // fmt.println(model.normals[0:model.vertexCount * 3])
//    // fmt.println(model.texcoords[0:model.vertexCount * 2 + 10])
//
//    faces := make([][3][3]f32, model.vertexCount / 3)
//    normals := make([][3][3]f32, model.vertexCount / 3)
//    tex_uvss := make([][3][2]f32, model.vertexCount / 3)
//
//    i: int = 0
//    for vert_start: i32 = 0; vert_start < model.vertexCount; vert_start += 3 {
//        face: [3][3]f32
//        normal: [3][3]f32
//        tex_uvs: [3][2]f32
//
//        for point_start in 0 ..< i32(3) {
//            face[point_start] = {
//                model.vertices[(vert_start + point_start) * 3],
//                model.vertices[(vert_start + point_start) * 3 + 1],
//                model.vertices[(vert_start + point_start) * 3 + 2],
//            }
//
//            normal[point_start] = linalg.normalize(
//                [3]f32 {
//                    model.normals[(vert_start + point_start) * 3],
//                    model.normals[(vert_start + point_start) * 3 + 1],
//                    model.normals[(vert_start + point_start) * 3 + 2],
//                },
//            )
//
//            // fmt.println(vert_start, (vert_start * 3 + point_start) * 2)
//            tex_uvs[point_start] = {
//                model.texcoords[(vert_start + point_start) * 2],
//                model.texcoords[(vert_start + point_start) * 2 + 1],
//            }
//        }
//
//        faces[i] = face
//        normals[i] = normal
//        tex_uvss[i] = tex_uvs
//
//        i += 1
//    }
//
//    camera := sc.make_basic_camera(u32(screen_width), u32(screen_height))
//    camera.pos.z += 10
//
//
//    cnt := 0
//    for !rl.WindowShouldClose() {
//        // viewport := viewport_projection(
//        //     screen_width / 8,
//        //     screen_height / 8,
//        //     screen_width * 3 / 4,
//        //     screen_height * 3 / 4,
//        // )
//
//        sc.update_basic_camera(&camera)
//        camera_proj_matrix :=
//            sc.calc_perspective_projection_matrix(&camera, true) *
//            sc.calc_view_matrix(&camera)
//        // camera_proj_matrix[3, 2] = -1
//        model_proj_matrix := sc.calc_model_matrix(
//            {1, 1, 1},
//            {0, 1, 0},
//            0, //f32(rl.GetTime() * 50),
//            1,
//        )
//        //     projection := linalg.MATRIX4F32_IDENTITY
//        // projection[3, 2] = -1 / camera.z
//        // model_view := lookat(eye, center, {0, 1, 0})
//
//
//        // rl.cursor()
//
//        rl.BeginDrawing()
//        rl.ClearBackground(rl.RAYWHITE)
//
//        dir: sc.Direction_Set
//        if rl.IsKeyDown(.W) do dir += {.Forward}
//        if rl.IsKeyDown(.S) do dir += {.Backward}
//        if rl.IsKeyDown(.A) do dir += {.Left}
//        if rl.IsKeyDown(.D) do dir += {.Right}
//        if rl.IsKeyDown(.SPACE) do dir += {.Up}
//        if rl.IsKeyDown(.LEFT_SHIFT) do dir += {.Down}
//        sc.process_keyboard_basic_camera(&camera, rl.GetFrameTime(), dir)
//        mouse_delta := rl.GetMouseDelta()
//        bound_mouse()
//        // mouse_delta_x: f32 = 0
//        // mouse_delta_y: f32 = 0
//        // if rl.IsKeyDown(.LEFT) do mouse_delta_x -= 1
//        // if rl.IsKeyDown(.RIGHT) do mouse_delta_x += 1
//        // if rl.IsKeyDown(.UP) do mouse_delta_y += 1
//        // if rl.IsKeyDown(.DOWN) do mouse_delta_y -= 1
//        sc.process_mouse_basic_camera(&camera, mouse_delta.x, mouse_delta.y)
//
//        data = {}
//
//        // if rl.IsKeyDown(.W) {
//        //     DIST += 0.01
//        // }
//        // if rl.IsKeyDown(.S) {
//        //     DIST -= 0.01
//        // }
//
//        // run_raytracing()
//        // triangle(a, b, c, {{255, 0, 0}, {0, 255, 0}, {0, 0, 255}})
//        // draw_cube()
//
//        // triangle = 3 vertices
//        // vertex = 2floats
//
//        slice.fill(z_buffer[:], -math.F32_MAX)
//
//
//        for face_idx: int = 0; face_idx < len(faces); face_idx += 1 {
//            face := faces[face_idx]
//            normal := normals[face_idx]
//            tex_uvs := tex_uvss[face_idx]
//
//            // fmt.println(tex_uvs)
//
//
//            screen_coords: [3][3]f32
//            n := 0
//            // world_coords: [3][3]f32
//            intensity: [3]f32
//            for j: i32 = 0; j < 3; j += 1 {
//                v := face[j]
//                normalized_coords := m2v(
//                    camera_proj_matrix * model_proj_matrix * matrix[4, 1]f32{
//                            v.x, 
//                            v.y, 
//                            v.z, 
//                            1, 
//                        },
//                )
//                // screen_coords[j] = normalized_coords
//                screen_coords[j] = vec3 {
//                    (normalized_coords.x + 1) / 2 * f32(screen_width),
//                    (normalized_coords.y + 1) / 2 * f32(screen_height),
//                    -normalized_coords.z,
//                }
//
//
//                if face_idx == 0 {
//                    fmt.println(screen_coords[j])
//                    fmt.println(camera.pos)
//                }
//
//
//                if screen_coords[j].z > 1 {
//                    n += 1
//                }
//
//                // fmt.print
//
//                // if screen_coords[j].z <= -1 || 0 <= screen_coords[j].z {
//                //     n += 1
//                // }
//
//                // fmt.println(screen_coords[0].z)
//
//                // world_coords[j] = v
//                // intensity = normal[j] * light_dir
//            }
//
//            if n != 0 {
//                continue
//            }
//
//            // n := linalg.vector_cross3(
//            //     (world_coords[2] - world_coords[0]),
//            //     (world_coords[1] - world_coords[0]),
//            // )
//            // n = linalg.vector_normalize(n)
//
//            // fmt.println(screen_coords)
//
//            // if !is_triangle_facing_camera(
//            //     screen_coords[0],
//            //     screen_coords[1],
//            //     screen_coords[2],
//            //     {0.5 * screen_width, 0.5 * screen_height, 10000},
//            // ) {
//            //     continue
//            // }
//
//            // fmt.println(screen_coords)
//            draw_triangle(
//                screen_coords,
//                intensity,
//                tex_uvs,
//                Texture {
//                    w = i32(african_head_diffuse.width),
//                    h = i32(african_head_diffuse.height),
//                    data = african_head_diffuse.pixels.buf[:],
//                },
//            )
//        }
//
//        // triangle := [3][3]f32{{0, 0.5, 1}, {-0.5, -0.5, 1}, {0.5, -0.5, 1}}
//        // triangle[0].x = (triangle[0].x + 1) / 2
//        // triangle[0].y = (triangle[0].y + 1) / 2
//        // triangle[1].x = (triangle[1].x + 1) / 2
//        // triangle[1].y = (triangle[1].y + 1) / 2
//        // triangle[2].x = (triangle[2].x + 1) / 2
//        // triangle[2].y = (triangle[2].y + 1) / 2
//        // // triangle[0] = linalg.normalize(triangle[0])
//        // // triangle[1] = linalg.normalize(triangle[1])
//        // // triangle[2] = linalg.normalize(triangle[2])
//        // triangle[0].x = triangle[0].x * screen_width
//        // triangle[0].y = triangle[0].y * screen_height
//        // triangle[1].x = triangle[1].x * screen_width
//        // triangle[1].y = triangle[1].y * screen_height
//        // triangle[2].x = triangle[2].x * screen_width
//        // triangle[2].y = triangle[2].y * screen_height
//
//        // draw_triangle(
//        //     triangle,
//        //     1,
//        //     {{0, 0.5}, {0.5, 0.5}, {0.5, 0.5}},
//        //     Texture {
//        //         w = i32(african_head_diffuse.width),
//        //         h = i32(african_head_diffuse.height),
//        //         data = african_head_diffuse.pixels.buf[:],
//        //     },
//        // )
//
//        rl.UpdateTexture(texture, &data)
//        rl.DrawTexture(texture, 0, 0, rl.WHITE)
//
//        rl.DrawFPS(0, 0)
//        rl.EndDrawing()
//        cnt += 1
//    }
//
//    rl.CloseWindow()
//}
//
//bound_mouse :: proc() {
//    mousePosition := rl.GetMousePosition()
//
//    // rl.SetMouseOffset(screen_width / 2, screen_height / 2)
//    rl.SetMousePosition(screen_width / 2, screen_height / 2)
//    rl.HideCursor()
//
//    // // Check if the mouse is outside the window
//    // if (mousePosition.x < 0) {
//    //     rl.SetMousePosition(0, i32(mousePosition.y)) // Reset to left edge
//    // } else if (mousePosition.x > screen_width) {
//    //     rl.SetMousePosition(i32(screen_width - 1), i32(mousePosition.y)) // Reset to right edge
//    // }
//
//    // if (mousePosition.y < 0) {
//    //     rl.SetMousePosition(i32(mousePosition.x), 0) // Reset to top edge
//    // } else if (mousePosition.y > screen_height) {
//    //     rl.SetMousePosition(i32(mousePosition.x), screen_height - 1) // Reset to bottom edge
//    // }
//}
