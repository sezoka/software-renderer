package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"


load_obj :: proc(path: string) -> Mesh {
    file_bytes, _ := os.read_entire_file(path)
    //defer delete(file_bytes)
    file := string(file_bytes)

    lines_iter := file
    faces: [dynamic]Face
    vertices: [dynamic]Vec3
    for line in strings.split_lines_iterator(&lines_iter) {
        if len(strings.trim_space(line)) < 2 do continue
        if line[0:2] == "v " {
            vert: Vec3
            nums_iter := line[2:]
            i := 0
            for num_str in strings.split_iterator(&nums_iter, " ") {
                coord, ok := strconv.parse_f32(num_str)
                assert(ok)
                vert[i] = coord
                i += 1
            }
            append(&vertices, vert)
        } else if line[0:2] == "f " {
            face: Face

            indices_groups_iter := line[2:]
            i := 0
            for indices_group in strings.split_iterator(
                &indices_groups_iter,
                " ",
            ) {
                indices: [3]u32

                indices_iter := indices_group
                j := 0
                for index_str in strings.split_iterator(&indices_iter, "/") {
                    if len(index_str) != 0 {
                        index, ok := strconv.parse_int(index_str)
                        assert(ok)
                        indices[j] = u32(index)
                    }
                    j += 1
                }

                face[i] = indices[0]

                i += 1
            }

            append(&faces, face)
        }
    }

    model: Mesh = {
        vertices    = vertices[:],
        faces       = faces[:],
        rotation    = {0, 0, 0},
        scale       = {1, 1, 1},
    }

    return model
}
