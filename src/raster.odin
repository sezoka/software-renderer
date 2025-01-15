package main
//
//import "core:fmt"
//import "core:math"
//import "core:math/ease"
//import "core:math/linalg"
//import rl "vendor:raylib"
//
//// draw_line :: proc(p0, p1: [2]f32, color: [3]f32) {
////     x0, x1 := p0.x, p1.x
////     y0, y1 := p0.y, p1.y
//
////     dx := x1 - x0
////     dy := y1 - y0
//
////     if abs(dx) > abs(dy) {
////         if x0 > x1 {
////             x0, x1, y0, y1 = x1, x0, y1, y0
////         }
////         a := dy / dx
////         y := y0
////         for x := x0; x <= x1; x += 1 {
////             put_pixel(int(x), int(y), color)
////             y = y + a
////         }
////     } else {
////         if y0 > y1 {
////             x0, x1, y0, y1 = x1, x0, y1, y0
////         }
////         a := dx / dy
////         x := x0
////         for y := y0; y <= y1; y += 1 {
////             put_pixel(int(x), int(y), color)
////             x = x + a
////         }
////     }
//// }
//
//// wraw_wireframe_triangle :: proc(p0, p1, p2: [2]f32, color: [3]u8) {
////     draw_line(p0, p1, color)
////     draw_line(p1, p2, color)
////     draw_line(p2, p0, color)
//// }
//
//is_triangle_facing_camera :: proc(a, b, c, camera: vec3) -> bool {
//    // Calculate the edges of the triangle
//    edge1 := vec3{b.x - a.x, b.y - a.y, b.z - a.z}
//    edge2 := vec3{c.x - a.x, c.y - a.y, c.z - a.z}
//
//    // Calculate the normal of the triangle
//    normal := linalg.cross(edge1, edge2)
//    normal = linalg.normalize(normal)
//
//    // Calculate the vector from the triangle to the camera
//    to_camera: vec3 = {camera.x - a.x, camera.y - a.y, camera.z - a.z}
//
//    // Calculate the dot product
//    dot: f32 = linalg.dot(normal, to_camera)
//
//    // If the dot product is positive, the triangle is facing the camera
//    return dot > 0
//}
//
//draw_triangle :: proc(
//    points: [3][3]f32,
//    intensitys: [3]f32,
//    uvs: [3][2]f32,
//    tex: Texture,
//) {
//    bboxmin: [2]f32 = {f32(screen_width - 1), f32(screen_height - 1)}
//    bboxmax: [2]f32 = {0, 0}
//    clamp := bboxmin
//
//    p0 := points[0]
//    p1 := points[1]
//    p2 := points[2]
//
//    normalize_bbox :: proc(bboxmin, bboxmax, clamp: ^[2]f32, p: [2]f32) {
//        bboxmin.x = math.max(0, math.min(bboxmin.x, p.x))
//        bboxmin.y = math.max(0, math.min(bboxmin.y, p.y))
//        bboxmax.x = math.min(clamp.x, math.max(bboxmax.x, p.x))
//        bboxmax.y = math.min(clamp.y, math.max(bboxmax.y, p.y))
//    }
//
//    // fmt.println(bboxmin, bboxmax, clamp)
//
//    normalize_bbox(&bboxmin, &bboxmax, &clamp, p0.xy)
//    normalize_bbox(&bboxmin, &bboxmax, &clamp, p1.xy)
//    normalize_bbox(&bboxmin, &bboxmax, &clamp, p2.xy)
//
//    for x in i32(bboxmin.x) ..= i32(bboxmax.x) {
//        for y in i32(bboxmin.y) ..= i32(bboxmax.y) {
//            u, v, w := barycentric(p0.xy, p1.xy, p2.xy, {f32(x), f32(y)})
//
//            if u < 0 || v < 0 || w < 0 do continue
//
//            // fmt.println(">", u, v, w)
//
//            uv_sum := u + v + w
//            uv := (uvs[0] * u + uvs[1] * v + uvs[2] * w) / uv_sum
//            intensity :=
//                (intensitys[0] * u + intensitys[1] * v + intensitys[2] * w) /
//                uv_sum
//
//            tex_x := i32(uv[0] * f32(tex.w))
//            tex_y := i32(uv[1] * f32(tex.h))
//
//
//            // if (tex_y * tex.w + tex_x) < 1024 * 10 {
//            //     fmt.println(tex_y * tex.w + tex_x)
//            // }
//
//            // fmt.println(intensity)
//
//            pixel_offset := (tex_y * tex.w + tex_x) * 3
//            tex_color := [3]u8 {
//                tex.data[pixel_offset + 0],
//                tex.data[pixel_offset + 1],
//                tex.data[pixel_offset + 2],
//            }
//
//            z := p0.z * u + p1.z * v + p2.z * w
//
//            z_buff_pixel := &z_buffer[i32(y) * screen_width + i32(x)]
//            if z_buff_pixel^ < z {
//                z_buff_pixel^ = z
//                put_pixel(x, y, {50, 0, 200})
//            }
//        }
//    }
//
//    //    Vec2i P;
//    //    for (P.x=bboxmin.x; P.x<=bboxmax.x; P.x++) {
//    //        for (P.y=bboxmin.y; P.y<=bboxmax.y; P.y++) {
//    //            Vec3f bc_screen  = barycentric(pts, P);
//    //            if (bc_screen.x<0 || bc_screen.y<0 || bc_screen.z<0) continue;
//    //            image.set(P.x, P.y, color);
//    //        }
//    // }
//}
//
//barycentric :: #force_inline proc(
//    a: [2]f32,
//    b: [2]f32,
//    c: [2]f32,
//    P: [2]f32,
//) -> (
//    u: f32,
//    v: f32,
//    w: f32,
//) {
//    s: [2][3]f32 = {
//        {c.x - a.x, b.x - a.x, a.x - P.x},
//        {c.y - a.y, b.y - a.y, a.y - P.y},
//    }
//    tmp := linalg.cross(s[0], s[1])
//    if (abs(tmp[2]) > 1e-2) {
//        return 1 - (tmp.x + tmp.y) / tmp.z, tmp.y / tmp.z, tmp.x / tmp.z
//    }
//    return -1, 0, 0
//}
//
//viewport_to_canvas :: #force_inline proc(x: f32, y: f32) -> [2]f32 {
//    return {
//        x * f32(screen_width) / VIEWPORT_WIDTH,
//        y * f32(screen_height) / VIEWPORT_HEIGHT,
//    }
//}
//
//project_vertex :: #force_inline proc(v: [3]f32) -> [2]f32 {
//    return viewport_to_canvas(v.x * DIST / v.z, v.y * DIST / v.z)
//}
//
//
//// draw_cube :: proc() {
////     // The four "front" vertices
////     vAf: [3]f32 = {-2, -0.5, 5}
////     vBf: [3]f32 = {-2, 0.5, 5}
////     vCf: [3]f32 = {-1, 0.5, 5}
////     vDf: [3]f32 = {-1, -0.5, 5}
//
////     // The four "back" vertices
////     vAb: [3]f32 = {-2, -0.5, 6}
////     vBb: [3]f32 = {-2, 0.5, 6}
////     vCb: [3]f32 = {-1, 0.5, 6}
////     vDb: [3]f32 = {-1, -0.5, 6}
//
////     BLUE: [3]f32 : {0, 0, 255}
////     RED: [3]f32 : {255, 0, 0}
////     GREEN: [3]f32 : {0, 255, 0}
//
////     // The front face
////     draw_line(project_vertex(vAf), project_vertex(vBf), BLUE)
////     draw_line(project_vertex(vBf), project_vertex(vCf), BLUE)
////     draw_line(project_vertex(vCf), project_vertex(vDf), BLUE)
////     draw_line(project_vertex(vDf), project_vertex(vAf), BLUE)
//
////     // The back face
////     draw_line(project_vertex(vAb), project_vertex(vBb), RED)
////     draw_line(project_vertex(vBb), project_vertex(vCb), RED)
////     draw_line(project_vertex(vCb), project_vertex(vDb), RED)
////     draw_line(project_vertex(vDb), project_vertex(vAb), RED)
//
////     // The front-to-back edges
////     draw_line(project_vertex(vAf), project_vertex(vAb), GREEN)
////     draw_line(project_vertex(vBf), project_vertex(vBb), GREEN)
////     draw_line(project_vertex(vCf), project_vertex(vCb), GREEN)
////     draw_line(project_vertex(vDf), project_vertex(vDb), GREEN)
//
//// }
