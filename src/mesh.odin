package main


Face :: struct {
    vert_ids: [3]u32,
    uv_ids:   [3]u32,
}

Mesh :: struct {
    faces:       []Face,
    vertices:    []Vec3,
    uvs:         []Vec2,
    rotation:    Vec3,
    scale:       Vec3,
    translation: Vec3,
}
