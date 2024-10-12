package raycaster

import "core:fmt"
import "core:math"
import "core:math/linalg"

// draw_line :: proc(p0, p1: [2]f32, color: [3]u8) {
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

triangle :: proc(p0, p1, p2: [3]f32, colors: [3][3]f32) {
    bboxmin: [2]f32 = {SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}
    bboxmax: [2]f32 = {-SCREEN_WIDTH - 1, -SCREEN_HEIGHT - 1}
    clamp := bboxmin

    normalize_bbox :: proc(bboxmin, bboxmax, clamp: ^[2]f32, p: [2]f32) {
        bboxmin.x = math.max(SCREEN_WIDTH * -0.5, math.min(bboxmin.x, p.x))
        bboxmin.y = math.max(SCREEN_HEIGHT * -0.5, math.min(bboxmin.y, p.y))
        bboxmax.x = math.min(clamp.x, math.max(bboxmax.x, p.x))
        bboxmax.y = math.min(clamp.y, math.max(bboxmax.y, p.y))
    }

    // fmt.println(bboxmin, bboxmax, clamp)

    normalize_bbox(&bboxmin, &bboxmax, &clamp, p0.xy)
    normalize_bbox(&bboxmin, &bboxmax, &clamp, p1.xy)
    normalize_bbox(&bboxmin, &bboxmax, &clamp, p2.xy)


    for x in bboxmin.x ..= bboxmax.x {
        for y in bboxmin.y ..= bboxmax.y {
            u, v, w := barycentric(p0, p1, p2, {x, y, 1})
            sum := u + v + w
            color :=
                ((u / sum) * colors[0]) +
                ((v / sum) * colors[1]) +
                ((w / sum) * colors[2])

            if x == 0 && y == 0 {
                log(u, v, w)
            }

            if u < 0 || v < 0 || w < 0 {
                // put_pixel(int(x), int(y), {0, 0, 0})
            } else {
                put_pixel(int(x), int(y), color)
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
    a: [3]f32,
    b: [3]f32,
    c: [3]f32,
    P: [3]f32,
) -> (
    u: f32,
    v: f32,
    w: f32,
) {
    v0 := b - a
    v2 := P - a
    v1 := c - a
    d00 := linalg.dot(v0, v0)
    d01 := linalg.dot(v0, v1)
    d11 := linalg.dot(v1, v1)
    d20 := linalg.dot(v2, v0)
    d21 := linalg.dot(v2, v1)
    invDenom := 1.0 / (d00 * d11 - d01 * d01)
    v = (d11 * d20 - d01 * d21) * invDenom
    w = (d00 * d21 - d01 * d20) * invDenom
    u = 1.0 - v - w
    return
}
