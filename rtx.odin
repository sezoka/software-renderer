package raycaster

// import "core:fmt"
// import "core:math"
// import "core:math/linalg"
// import "core:slice"
// import rl "vendor:raylib"

// reflect_ray :: proc(ray, normal: vec3) -> vec3 {
//     return 2 * normal * linalg.dot(normal, ray) - ray
// }

// compute_lighting :: proc(point, normal, V: [3]f32, s: i16) -> f32 {
//     i: f32 = 0.0
//     for light in lights {
//         if light.type == .Ambient {
//             i += light.intensity
//         } else {
//             L: vec3
//             t_max: f32
//             if light.type == .Point {
//                 L = light.vector - point
//                 t_max = 1
//             } else {
//                 L = light.vector
//                 t_max = math.INF_F32
//             }

//             // shadow check
//             shadow_sphere, shadow_t := closest_intersection(point, L, 0.001, t_max)
//             if shadow_sphere != (Sphere{}) {
//                 continue
//             }

//             // diffuse
//             n_dot_l := linalg.dot(normal, L)
//             if n_dot_l > 0 {
//                 i += light.intensity * n_dot_l / (linalg.length(normal) * linalg.length(L))
//             }

//             // specular
//             if s != -1 {
//                 ray := reflect_ray(L, normal)
//                 r_dot_v := linalg.dot(ray, V)
//                 if 0 < r_dot_v {
//                     i += light.intensity * math.pow_f32(r_dot_v / (linalg.length(ray) * linalg.length(V)), f32(s))
//                 }
//             }
//         }
//     }
//     return i
// }

// canvas_to_viewport :: proc(x, y: int) -> [3]f32 {
//     return {f32(x) * Vw / SCREEN_WIDTH, f32(y) * Vh / SCREEN_HEIGHT, DIST}
// }

// closest_intersection :: proc(O, D: vec3, t_min, t_max: f32) -> (Sphere, f32) {
//     closest_t := math.INF_F32
//     closest_sphere: Sphere
//     for sphere in spheres {
//         t1, t2 := intersect_ray_sphere(O, D, sphere)
//         if (t_min <= t1 && t1 <= t_max) && t1 < closest_t {
//             closest_t = t1
//             closest_sphere = sphere
//         }
//         if (t_min <= t2 && t2 <= t_max) && t2 < closest_t {
//             closest_t = t2
//             closest_sphere = sphere
//         }
//     }
//     return closest_sphere, closest_t
// }

// trace_ray :: proc(O, D: [3]f32, t_min, t_max: f32, recursion_depth: i8) -> [3]u8 {
//     closest_sphere, closest_t := closest_intersection(O, D, t_min, t_max)
//     if closest_sphere == (Sphere{}) {
//         return BACKGROUND_COLOR
//     }

//     P := O + closest_t * D // Compute intersection
//     N := P - closest_sphere.center // Compute sphere normal at intersection
//     N = N / linalg.length(N)
//     clr: [3]f32 = color_to_vec3(closest_sphere.color)
//     local_color := clr * compute_lighting(P, N, -D, closest_sphere.specular)

//     // if we hit the recursion limit or the object is not reflective, we're done
//     if recursion_depth <= 0 || closest_sphere.reflective == 0 {
//         return clamp_color(local_color)
//     }

//     // compute the reflected color
//     ray := reflect_ray(-D, N)
//     reflected_color := color_to_vec3(trace_ray(P, ray, 0.001, math.INF_F32, recursion_depth - 1))


//     return clamp_color((local_color * (1 - closest_sphere.reflective)) + (reflected_color * closest_sphere.reflective))
// }

// color_to_vec3 :: proc(clr: [3]u8) -> vec3 {
//     return {f32(clr.r), f32(clr.g), f32(clr.b)}
// }

// clamp_color :: proc(clr: vec3) -> [3]u8 {
//     return {u8(math.clamp(clr.r, 0, 255)), u8(math.clamp(clr.g, 0, 255)), u8(math.clamp(clr.b, 0, 255))}
// }

// intersect_ray_sphere :: proc(O, D: [3]f32, sphere: Sphere) -> (f32, f32) {
//     r := sphere.radius
//     CO := O - sphere.center

//     a := linalg.dot(D, D)
//     b := 2 * linalg.dot(CO, D)
//     c := linalg.dot(CO, CO) - r * r

//     discriminant := b * b - 4 * a * c
//     if discriminant < 0 {
//         return math.INF_F32, math.INF_F32
//     }

//     t1 := (-b + math.sqrt(discriminant)) / (2 * a)
//     t2 := (-b - math.sqrt(discriminant)) / (2 * a)
//     return t1, t2
// }


// run_raytracing :: proc() {
//     O: [3]f32 = {0, 0, 0}

//     for x in -SCREEN_WIDTH / 2 ..< SCREEN_WIDTH / 2 {
//         for y in -SCREEN_HEIGHT / 2 ..< SCREEN_HEIGHT / 2 {
//             D := canvas_to_viewport(x, y)
//             color := trace_ray(O, D, 1, math.INF_F32, RECURSION_DEPTH)
//             put_pixel(x, y, color)
//         }
//     }
// }
