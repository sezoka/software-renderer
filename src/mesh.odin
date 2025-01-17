package main


Face :: [3]u32

Mesh :: struct {
    faces:       []Face,
    vertices:    []Vec3,
    rotation:    Vec3,
    scale:       Vec3,
    translation: Vec3,
}
