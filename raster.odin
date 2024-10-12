package raycaster

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

triangle :: proc(p0, p1, p2: [3]f32, color: [3]f32) {
    p0, p1, p2 := p0, p1, p2

    // sort the vertices, t0, t1, t2 lower−to−upper (bubblesort yay!)
    if p0.y > p1.y do p0, p1 = p1, p0
    if p0.y > p2.y do p0, p2 = p2, p0
    if p1.y > p2.y do p1, p2 = p2, p1

    h0, h1, h2 := p0.z, p1.z, p2.z
    y0, y1, y2 := p0.y, p1.y, p2.y
    x0, x1, x2 := p0.x, p1.x, p2.x
    top, mid, bottom := p0, p1, p2

    total_height := y2 - y0

    vector_between_top_and_bottom := p2 - p0
    vector_between_top_and_middle := p1 - p0
    vector_between_mid_and_bottom := p2 - p1

    top_segment_height := y1 - y0 + 1
    bottom_segment_height := y2 - y1 + 1

    for y := y0; y <= y1; y += 1 {
        downess_in_triangle := (y - y0) / total_height // % of progress of going down in triangle
        downess_in_segment := (y - y0) / top_segment_height // % of progress of going down in segment ; be careful with divisions by zero

        pos_in_longest := top + vector_between_top_and_bottom * downess_in_triangle
        pos_in_shortest := top + vector_between_top_and_middle * downess_in_segment
        start, end := pos_in_longest, pos_in_shortest
        if pos_in_longest.x > pos_in_shortest.x do start, end = pos_in_shortest, pos_in_longest

        for x := start.x; x <= end.x; x += 1 {
            dist_to_top := linalg.vector_length2([2]f32{x, y} - p0.xy)
            dist_to_mid := linalg.vector_length2([2]f32{x, y} - p1.xy)
            dist_to_bottom := linalg.vector_length2([2]f32{x, y} - p2.xy)
            sum := dist_to_top + dist_to_mid + dist_to_bottom
            color_h := ((dist_to_top / sum) * h0) + ((dist_to_mid / sum) * h1) + ((dist_to_bottom / sum) * h2)
            log(color_h)

            put_pixel(int(x), int(y), color * color_h) // attention, due to int casts y0+i != A.y
        }
    }
    for y := y1; y <= y2; y += 1 {
        downess_in_triangle := (y - y0) / total_height
        downess_in_segment := (y - y1) / bottom_segment_height
    start := top + vector_between_top_and_bottom * downess_in_triangle

        end := mid + vector_between_mid_and_bottom * downess_in_segment
        if (start.x > end.x) do start, end = end, start

        for x := start.x; x <= end.x; x += 1 {
            dist_to_top := linalg.vector_length2([2]f32{x, y} - p0.xy)
            dist_to_mid := linalg.vector_length2([2]f32{x, y} - p1.xy)
            dist_to_bottom := linalg.vector_length2([2]f32{x, y} - p2.xy)
            sum := dist_to_top + dist_to_mid + dist_to_bottom
            color_h := ((dist_to_top / sum) * h0) + ((dist_to_mid / sum) * h1) + ((dist_to_bottom / sum) * h2)

            put_pixel(int(x), int(y), color * color_h) // attention, due to int casts y0+i != A.y
        }
    }
}
