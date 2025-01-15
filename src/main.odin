package main

import "core:fmt"
import tga "core:image/tga"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:slice"
import rl "vendor:raylib"

PIXEL_SIZE :: 3
screen_width: u32 = 800
screen_height: u32 = 600
color_buff: []u8
z_buff: []f32
fov :: 640.0
camera_pos: Vec3 = {0, 0, 0}
delta_sum: f32

//mesh_vertices: [dynamic]Vec3
//mesh_faces: [dynamic]Face

meshes: [dynamic]Mesh

Color :: struct {
    r, g, b: u8,
}

Triangle :: [3]Vec3

populate_points :: proc() {
    mesh_vertices: [dynamic]Vec3
    mesh_faces: [dynamic]Face

    append(
        &mesh_vertices,
        Vec3{-1, -1, -1},
        Vec3{-1, 1, -1},
        Vec3{1, 1, -1},
        Vec3{1, -1, -1},
        Vec3{1, 1, 1},
        Vec3{1, -1, 1},
        Vec3{-1, 1, 1},
        Vec3{-1, -1, 1},
    )
    append(
        &mesh_faces,
        // front
        Face{1, 2, 3},
        Face{1, 2, 4},
        // right
        Face{4, 3, 5},
        Face{4, 5, 6},
        // back
        Face{6, 5, 7},
        Face{6, 7, 8},
        // left
        Face{8, 7, 2},
        Face{8, 2, 1},
        // top
        Face{2, 7, 5},
        Face{2, 5, 3},
        // bottom
        Face{6, 8, 1},
        Face{6, 1, 4},
    )

    append(&meshes, load_obj("./teapot.obj"))

    //append(&meshes, Mesh{vertices = mesh_vertices[:], faces = mesh_faces[:]})
}

project_point :: proc(v: Vec3) -> Vec2 {
    res: Vec2
    res.x = (fov * v.x) / v.z
    res.y = (fov * v.y) / v.z
    return res
}

main :: proc() {
    rl.SetConfigFlags({.BORDERLESS_WINDOWED_MODE})
    rl.InitWindow(800, 600, "Raycaster")
    defer rl.CloseWindow()
    screen_width = u32(rl.GetMonitorWidth(0))
    screen_height = u32(rl.GetMonitorHeight(0))
    rl.SetWindowSize(i32(screen_width), i32(screen_height))
    rl.SetWindowPosition(0, 0)
    rl.SetTargetFPS(0)

    color_buff = make([]u8, screen_width * screen_height * 3)
    z_buff = make([]f32, screen_width * screen_height)
    defer delete(color_buff)
    defer delete(z_buff)

    img := rl.Image {
        data    = raw_data(color_buff),
        width   = i32(screen_width),
        height  = i32(screen_height),
        mipmaps = 1,
        format  = .UNCOMPRESSED_R8G8B8,
    }

    front_buff := rl.LoadTextureFromImage(img)
    defer rl.UnloadTexture(front_buff)
    slice.fill(color_buff, 0)

    rotation: f32 = 0

    populate_points()
    defer clear_raster_data()

    for !rl.WindowShouldClose() {
        delta_sum += rl.GetFrameTime()
        rl.BeginDrawing()
        //rl.ClearBackground(rl.BLACK)
        clear_color_buffer_black()
        rotation += rl.GetFrameTime()

        wireframe_rendering()

        rl.UpdateTexture(front_buff, raw_data(color_buff))
        rl.DrawTexture(front_buff, 0, 0, rl.WHITE)
        rl.DrawFPS(16, 16)
        rl.EndDrawing()
    }
}

wireframe_rendering :: proc() {
    for mesh in meshes {
        for &face in mesh.faces {
            transformed_verts: [3]Vec3

            for vert_idx, i in face {
                transformed_points := mesh.vertices[vert_idx - 1]
                transformed_points = vec3_rotate_x(
                    transformed_points,
                    mesh.rotation.x + delta_sum,
                )
                transformed_points = vec3_rotate_y(
                    transformed_points,
                    mesh.rotation.y + delta_sum,
                )
                transformed_points = vec3_rotate_z(
                    transformed_points,
                    mesh.rotation.z + delta_sum,
                )
                transformed_points.z += 5
                transformed_verts[i] = transformed_points
            }

            // backface culling
            vert_a := transformed_verts[0]
            vert_b := transformed_verts[1]
            vert_c := transformed_verts[2]
            vector_ab := vert_b - vert_a
            vector_ac := vert_c - vert_a
            normal_vector := cross_vec3(vector_ab, vector_ac)
            camera_ray := camera_pos - vert_a
            fmt.println(camera_ray)
            dot_product := dot_vec3(camera_ray, normal_vector)
            if dot_product < 0 do continue

            projected_points: [3]Vec2
            for &vert, i in transformed_verts {
                projected_points[i] = project_point(vert)
                projected_points[i].x += f32(screen_width / 2)
                projected_points[i].y += f32(screen_height / 2)
            }

            draw_triangle(projected_points, {255, 255, 255})
        }
    }

}

clear_raster_data :: proc() {
    delete(meshes)
}

draw_triangle :: proc(t: [3]Vec2, color: Color) {
    draw_line(t[0], t[1], color)
    draw_line(t[1], t[2], color)
    draw_line(t[2], t[0], color)
}

draw_line :: proc(a: Vec2, b: Vec2, color: Color) {
    delta_x := b.x - a.x
    delta_y := b.y - a.y
    slide_length :=
        math.abs(delta_x) < math.abs(delta_y) ? math.abs(delta_y) : math.abs(delta_x)
    step_x := delta_x / slide_length
    step_y := delta_y / slide_length
    x := a.x
    y := a.y
    for i: u32 = 0; i < u32(slide_length); i += 1 {
        draw_pixel(i32(math.round(x)), i32(math.round(y)), color)
        x += step_x
        y += step_y
    }
}

draw_pixel :: #force_inline proc(x, y: i32, color: Color) #no_bounds_check {
    if 0 <= x && x < i32(screen_width) && 0 <= y && y < i32(screen_height) {
        offset := (x + y * i32(screen_width)) * PIXEL_SIZE
        color_buff[offset] = color.r
        color_buff[offset + 1] = color.g
        color_buff[offset + 2] = color.b
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
    slice.fill(color_buff, 0)
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
