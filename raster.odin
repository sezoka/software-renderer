package raycaster

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

// draw_line :: proc(p0, p1: [2]f32, color: [3]f32) {
//     x0, x1 := p0.x, p1.x
//     y0, y1 := p0.y, p1.y

//     dx := x1 - x0
//     dy := y1 - y0

//     if abs(dx) > abs(dy) {
//         if x0 > x1 {
//             x0, x1, y0, y1 = x1, x0, y1, y0
//         }
//         a := dy / dx
//         y := y0
//         for x := x0; x <= x1; x += 1 {
//             put_pixel(int(x), int(y), color)
//             y = y + a
//         }
//     } else {
//         if y0 > y1 {
//             x0, x1, y0, y1 = x1, x0, y1, y0
//         }
//         a := dx / dy
//         x := x0
//         for y := y0; y <= y1; y += 1 {
//             put_pixel(int(x), int(y), color)
//             x = x + a
//         }
//     }
// }

// wraw_wireframe_triangle :: proc(p0, p1, p2: [2]f32, color: [3]u8) {
//     draw_line(p0, p1, color)
//     draw_line(p1, p2, color)
//     draw_line(p2, p0, color)
// }

triangle :: proc(
    points: [3][3]f32,
    colors: [3][3]f32,
    uvs: [3][2]f32,
    tex: Texture,
) {
    bboxmin: [2]f32 = {SCREEN_WIDTH - 1, SCREEN_HEIGHT - 1}
    bboxmax: [2]f32 = {0, 0}
    clamp := bboxmin

    p0 := points[0]
    p1 := points[1]
    p2 := points[2]

    normalize_bbox :: proc(bboxmin, bboxmax, clamp: ^[2]f32, p: [2]f32) {
        bboxmin.x = math.max(0, math.min(bboxmin.x, p.x))
        bboxmin.y = math.max(0, math.min(bboxmin.y, p.y))
        bboxmax.x = math.min(clamp.x, math.max(bboxmax.x, p.x))
        bboxmax.y = math.min(clamp.y, math.max(bboxmax.y, p.y))
    }

    // fmt.println(bboxmin, bboxmax, clamp)

    normalize_bbox(&bboxmin, &bboxmax, &clamp, p0.xy)
    normalize_bbox(&bboxmin, &bboxmax, &clamp, p1.xy)
    normalize_bbox(&bboxmin, &bboxmax, &clamp, p2.xy)

    for x in bboxmin.x ..= bboxmax.x {
        for y in bboxmin.y ..= bboxmax.y {
            u, v, w := barycentric(
                {p0.x, p0.y},
                {p1.x, p1.y},
                {p2.x, p2.y},
                {x, y},
            )

            if u < 0 || v < 0 || w < 0 do continue

            // fmt.println(">", u, v, w)

            sum := u + v + w

            // color :=
            //     ((u / sum) * colors[0]) +
            //     ((v / sum) * colors[1]) +
            //     ((w / sum) * colors[2])


            uv :=
                ((u / sum) * uvs[0]) +
                ((v / sum) * uvs[1]) +
                ((w / sum) * uvs[2])


            tex_x := i32(uv[0] * f32(tex.w))
            tex_y := i32(uv[1] * f32(tex.h))


            // if (tex_y * tex.w + tex_x) < 1024 * 10 {
            //     fmt.println(tex_y * tex.w + tex_x)
            // }

            tex_color := [3]u8 {
                tex.data[(tex_y * tex.w + tex_x) * 3 + 0],
                tex.data[(tex_y * tex.w + tex_x) * 3 + 1],
                tex.data[(tex_y * tex.w + tex_x) * 3 + 2],
            }

            z := p0.z * u
            z += p1.z * v
            z += p2.z * w

            z_buff_pixel := &z_buffer[i32(y) * SCREEN_WIDTH + i32(x)]
            if z_buff_pixel^ < z {
                z_buff_pixel^ = z
                put_pixel(int(x), int(y), tex_color)
            }
        }
    }

    //    Vec2i P;
    //    for (P.x=bboxmin.x; P.x<=bboxmax.x; P.x++) {
    //        for (P.y=bboxmin.y; P.y<=bboxmax.y; P.y++) {
    //            Vec3f bc_screen  = barycentric(pts, P);
    //            if (bc_screen.x<0 || bc_screen.y<0 || bc_screen.z<0) continue;
    //            image.set(P.x, P.y, color);
    //        }
    // }
}

barycentric :: proc(
    a: [2]f32,
    b: [2]f32,
    c: [2]f32,
    P: [2]f32,
) -> (
    u: f32,
    v: f32,
    w: f32,
) {
    s: [2][3]f32
    for i := 1; 0 <= i; i -= 1 {
        s[i].x = c[i] - a[i]
        s[i].y = b[i] - a[i]
        s[i].z = a[i] - P[i]
    }
    tmp := linalg.cross(s[0], s[1])
    if (abs(tmp[2]) > 1e-2) {
        // dont forget that u[2] is integer. If it is zero then triangle ABC is degenerate
        return 1 - (tmp.x + tmp.y) / tmp.z, tmp.y / tmp.z, tmp.x / tmp.z
    }
    return -1, 1, 1 // in this case generate negative coordinates, it will be thrown away by the rasterizator
}

viewport_to_canvas :: proc(x: f32, y: f32) -> [2]f32 {
    return {
        x * SCREEN_WIDTH / VIEWPORT_WIDTH,
        y * SCREEN_HEIGHT / VIEWPORT_HEIGHT,
    }
}

project_vertex :: proc(v: [3]f32) -> [2]f32 {
    return viewport_to_canvas(v.x * DIST / v.z, v.y * DIST / v.z)
}


// draw_cube :: proc() {
//     // The four "front" vertices
//     vAf: [3]f32 = {-2, -0.5, 5}
//     vBf: [3]f32 = {-2, 0.5, 5}
//     vCf: [3]f32 = {-1, 0.5, 5}
//     vDf: [3]f32 = {-1, -0.5, 5}

//     // The four "back" vertices
//     vAb: [3]f32 = {-2, -0.5, 6}
//     vBb: [3]f32 = {-2, 0.5, 6}
//     vCb: [3]f32 = {-1, 0.5, 6}
//     vDb: [3]f32 = {-1, -0.5, 6}

//     BLUE: [3]f32 : {0, 0, 255}
//     RED: [3]f32 : {255, 0, 0}
//     GREEN: [3]f32 : {0, 255, 0}

//     // The front face
//     draw_line(project_vertex(vAf), project_vertex(vBf), BLUE)
//     draw_line(project_vertex(vBf), project_vertex(vCf), BLUE)
//     draw_line(project_vertex(vCf), project_vertex(vDf), BLUE)
//     draw_line(project_vertex(vDf), project_vertex(vAf), BLUE)

//     // The back face
//     draw_line(project_vertex(vAb), project_vertex(vBb), RED)
//     draw_line(project_vertex(vBb), project_vertex(vCb), RED)
//     draw_line(project_vertex(vCb), project_vertex(vDb), RED)
//     draw_line(project_vertex(vDb), project_vertex(vAb), RED)

//     // The front-to-back edges
//     draw_line(project_vertex(vAf), project_vertex(vAb), GREEN)
//     draw_line(project_vertex(vBf), project_vertex(vBb), GREEN)
//     draw_line(project_vertex(vCf), project_vertex(vCb), GREEN)
//     draw_line(project_vertex(vDf), project_vertex(vDb), GREEN)

// }
