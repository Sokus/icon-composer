package main

import "core:math/rand"
import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/linalg"
import "core:strconv"

import "vendor:raylib"
import mu "vendor:microui"

main :: proc() {
    CONFIG_PANEL_WIDTH: i32 : 350
    CONFIG_PANEL_MIN_HEIGHT: i32 : 540
    PREVIEW_AREA_MIN_WIDTH: i32 : 450
    WINDOW_MIN_WIDTH: i32 : PREVIEW_AREA_MIN_WIDTH + CONFIG_PANEL_WIDTH
    WINDOW_MIN_HEIGHT: i32 : CONFIG_PANEL_MIN_HEIGHT

    MAX_ICON_COUNT :: 512
    MAX_RENDER_WIDTH :: 10000
    MAX_RENDER_HEIGHT :: 10000

    raylib.SetTraceLogLevel(raylib.TraceLogLevel.WARNING)
    raylib.InitWindow(max(WINDOW_MIN_WIDTH, 960), max(WINDOW_MIN_HEIGHT, 540), "Icon Composer")
    raylib.SetWindowState({.WINDOW_RESIZABLE})
    raylib.SetWindowMinSize(WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT)

    ctx := new(mu.Context)
    defer free(ctx)
    mu_init(ctx)

    icon_count: int
    filepaths: [MAX_ICON_COUNT]string
    textures: [MAX_ICON_COUNT]raylib.Texture

    input: struct {
        tile_size: f32,
        filtering: bool,
        spacing: f32,
        rotation: f32,
        should_sieve: bool,
        sieve_percent: f32,
        should_avoid_matching_neighbours_hv: bool,
        should_avoid_matching_neighbours_diag: bool,

        image_size_x_text_buf: [64]u8,
        image_size_x_text_len: int,
        image_size_y_text_buf: [64]u8,
        image_size_y_text_len: int,
        image_size: [2]uint,
    }
    input.tile_size = 50
    input.filtering = true
    input.image_size = { 256, 256 }
    image_size_default := "256"
    copy_slice(input.image_size_x_text_buf[:], transmute([]u8)image_size_default)
    input.image_size_x_text_len = len(image_size_default)
    copy_slice(input.image_size_y_text_buf[:], transmute([]u8)image_size_default)
    input.image_size_y_text_len = len(image_size_default)
    mu_err_color := mu.Color{255, 51, 51, 255}
    rand_seed: u64 = 0

    render_texture := raylib.LoadRenderTexture(MAX_RENDER_WIDTH, MAX_RENDER_HEIGHT)

    for !raylib.WindowShouldClose() {
        mu_input(ctx)

        if raylib.IsFileDropped() {
            dropped_files := raylib.LoadDroppedFiles()

            for i in 0..<dropped_files.count {
                if icon_count < MAX_ICON_COUNT {
                    textures[icon_count] = raylib.LoadTexture(dropped_files.paths[i])
                    texture_filter: raylib.TextureFilter = .BILINEAR if input.filtering else .POINT
                    raylib.SetTextureFilter(textures[icon_count], texture_filter)
                    filepaths[icon_count] = strings.clone_from_cstring(dropped_files.paths[i])
                    icon_count += 1
                }
            }
            raylib.UnloadDroppedFiles(dropped_files)
        }

        mu.begin(ctx)

        config_label := "Config"
        config_opts := mu.Options{.NO_RESIZE, .NO_CLOSE, .NO_TITLE}
        config_container := mu.get_container(ctx, config_label, config_opts)
        mu_move_container(config_container, raylib.GetScreenWidth() - CONFIG_PANEL_WIDTH, 0)
        if mu.window(ctx, config_label, { 0, 0, CONFIG_PANEL_WIDTH, CONFIG_PANEL_MIN_HEIGHT }, config_opts) {
        mu.layout_row(ctx, { 60, 200 + ctx.style.spacing })
            config_width_no_padding := CONFIG_PANEL_WIDTH - 2*ctx.style.padding - ctx.style.scrollbar_size
            label_column_width: i32 = 60
            signle_column_width: i32 = config_width_no_padding - label_column_width - ctx.style.spacing
            double_column_width: i32 = (config_width_no_padding - label_column_width - 2*ctx.style.spacing)
            half_width: i32 = config_width_no_padding/2 - ctx.style.spacing
            label_width: i32 = 60

            mu.layout_row(ctx, { label_width, double_column_width/2, double_column_width/2 })
            {
                mu.text(ctx, "Target size:")

                mu_text_color := ctx.style.colors[.TEXT]

                image_size_x, image_size_x_ok := strconv.parse_uint(string(input.image_size_x_text_buf[:input.image_size_x_text_len]))
                if image_size_x > MAX_RENDER_WIDTH do image_size_x_ok = false
                if image_size_x_ok do input.image_size.x = image_size_x
                if !image_size_x_ok do ctx.style.colors[.TEXT] = mu_err_color
                mu.textbox(ctx, input.image_size_x_text_buf[:], &input.image_size_x_text_len)
                ctx.style.colors[.TEXT] = mu_text_color

                image_size_y, image_size_y_ok := strconv.parse_uint(string(input.image_size_y_text_buf[:input.image_size_y_text_len]))
                if image_size_y > MAX_RENDER_HEIGHT do image_size_y_ok = false
                if image_size_y_ok do input.image_size.y = image_size_y
                if !image_size_y_ok do ctx.style.colors[.TEXT] = mu_err_color
                mu.textbox(ctx, input.image_size_y_text_buf[:], &input.image_size_y_text_len)
                ctx.style.colors[.TEXT] = mu_text_color
            }

            mu.layout_row(ctx, { config_width_no_padding })
            if .SUBMIT in mu.button(ctx, "Save in working directory") {
                image := raylib.LoadImageFromTexture(render_texture.texture)

                crop_rect := raylib.Rectangle{ 0, f32(MAX_RENDER_HEIGHT - input.image_size.y), f32(input.image_size.x), f32(input.image_size.y) }
                raylib.ImageCrop(&image, crop_rect)
                raylib.ImageFlipVertical(&image)
                raylib.ExportImage(image, "result.png")
                raylib.UnloadImage(image)
            }

            mu.draw_rect(ctx, mu.layout_next(ctx), {})

            mu.layout_row(ctx, { label_width, signle_column_width })
            {
                mu.text(ctx, "Tile size:")
                mu.slider(ctx, &input.tile_size, 16.0, 1024.0, 1.0, "%.0f")
                mu.text(ctx, "Spacing:")
                mu.slider(ctx, &input.spacing, 0.0, 256.0, 1.0, "%.0f")
            }

            mu.layout_row(ctx, { label_width, signle_column_width })
            {
                mu.text(ctx, "Rotation:")
                mu.slider(ctx, &input.rotation, 0.0, 360.0, 0.1, "%.1f")
            }

            mu.layout_row(ctx, { half_width, half_width })
            {
                mu.checkbox(ctx, "Sieve", &input.should_sieve)
                slider_opt: mu.Options = {.ALIGN_CENTER}
                if !input.should_sieve do slider_opt += {.NO_INTERACT}
                mu.slider(ctx, &input.sieve_percent, 0.0, 1.0, 0.01, "%.2f", slider_opt, )
            }

            mu.layout_row(ctx, { half_width, half_width })
            {
                mu.text(ctx, "Avoid matching neighbours:")
                mu.draw_rect(ctx, mu.layout_next(ctx), {})
                mu.checkbox(ctx, "Horizontal/Vertical", &input.should_avoid_matching_neighbours_hv)
                mu.checkbox(ctx, "Diagonal", &input.should_avoid_matching_neighbours_diag)
            }

            mu.layout_row(ctx, { config_width_no_padding })
            if .SUBMIT in mu.button(ctx, "Randomize seed") {
                rand_seed = rand.uint64()
            }

            mu.draw_rect(ctx, mu.layout_next(ctx), {})

            mu.layout_row(ctx, { signle_column_width, label_width })
            {
                if icon_count > 0 {
                    mu.text(ctx, "Files:");
                    mu.draw_rect(ctx, mu.layout_next(ctx), {})
                }

                for i in 0..<icon_count {
                    i := i
                    mu.push_id_rawptr(ctx, &i, size_of(i))
                    filepath := filepaths[i]
                    mu.text(ctx, filepath[max(0, len(filepath)-100):])
                    if .SUBMIT in mu.button(ctx, "", .CLOSE) {
                        delete_string(filepaths[i])
                        raylib.UnloadTexture(textures[i])
                        for j in i..<icon_count-1 {
                            filepaths[j] = filepaths[j+1]
                            textures[j] = textures[j+1]
                        }
                        icon_count -= 1
                    }
                    mu.pop_id(ctx)
                }
            }
        }
        mu.end(ctx)

        tile_size := math.round(input.tile_size)
        spacing := math.round(input.spacing)
        cell_count: linalg.Vector2f32
        {
            diagonal := linalg.vector_length(
                linalg.Vector2f32{ f32(input.image_size.x), f32(input.image_size.y) }
            )
            min_cell_count := (diagonal + spacing) / (tile_size + spacing)
            cell_count = linalg.Vector2f32{ linalg.ceil(min_cell_count), linalg.ceil(min_cell_count) }
        }
        icon_history_len := int(cell_count.x) + 2
        icon_history := make([]int, icon_history_len, context.temp_allocator)
        for _, i in icon_history {
            icon_history[i] = -1
        }

        raylib.BeginTextureMode(render_texture)
        {
            raylib.ClearBackground({})
            raylib.BeginScissorMode(0, 0, i32(input.image_size.x), i32(input.image_size.y))
            {
                raylib.rlPushMatrix()
                content_size := cell_count*tile_size + (cell_count-1)*spacing
                raylib.rlTranslatef(f32(input.image_size.x)/2.0, f32(input.image_size.y)/2.0, 0.0)
                raylib.rlRotatef(input.rotation, 0.0, 0.0, 1.0)
                raylib.rlTranslatef(-content_size.x/2.0, -content_size.y/2.0, 0.0)
                if icon_count > 0 {

                    rand_icon_gen := rand.create(rand_seed)
                    rand_sieve_gen := rand.create(rand_seed)

                    for y in 0..<int(cell_count.y) {
                        for x in 0..<int(cell_count.x) {
                            icons_drawn := y * int(cell_count.x) + x
                            neighbour_top_left := icon_history[(icons_drawn + icon_history_len - int(cell_count.x) - 1) % icon_history_len]
                            neighbour_top := icon_history[(icons_drawn + icon_history_len - int(cell_count.x)) % icon_history_len]
                            neighbour_top_right := icon_history[(icons_drawn + icon_history_len - int(cell_count.x) + 1) % icon_history_len]
                            neighbour_left := icon_history[(icons_drawn + icon_history_len - 1) % icon_history_len]

                            available_icons := make([dynamic]int, 0, 6, context.temp_allocator)
                            for i in 0..<icon_count {
                                if (input.should_avoid_matching_neighbours_hv) {
                                    if ((x > 0) && (i == neighbour_left)) do continue
                                    if (i == neighbour_top) do continue
                                }
                                if (input.should_avoid_matching_neighbours_diag) {
                                    if((x > 0) && (i == neighbour_top_left)) do continue
                                    if((x < int(cell_count.x) - 1) && (i == neighbour_top_right)) do continue
                                }
                                append(&available_icons, i)
                            }

                            icon_to_draw := available_icons[rand.int_max(len(available_icons), &rand_icon_gen)]
                            sieve_value := rand.float32(&rand_sieve_gen)

                            if (len(available_icons) > 0) && (!input.should_sieve || sieve_value > input.sieve_percent) {
                                icon_history[icons_drawn % icon_history_len] = icon_to_draw

                                source := raylib.Rectangle{ 0.0, 0.0, f32(textures[icon_to_draw].width), f32(textures[icon_to_draw].height)}

                                rounded_tile_size := linalg.Vector2f32{ 1.0, 1.0 } * max(source.width, source.height)

                                raylib.rlPushMatrix()
                                raylib.rlTranslatef(tile_size*(rounded_tile_size.x-source.width)/rounded_tile_size.x/2.0, tile_size*(rounded_tile_size.y-source.height)/rounded_tile_size.y/2.0, 0.0)
                                dest := raylib.Rectangle{ f32(x)*(tile_size+spacing), f32(y)*(tile_size+spacing), tile_size*source.width/rounded_tile_size.x, tile_size*source.height/rounded_tile_size.y }
                                raylib.DrawTexturePro(textures[icon_to_draw], source, dest, {}, 0.0, raylib.WHITE)
                                raylib.rlPopMatrix()
                            } else {
                                icon_history[icons_drawn % icon_history_len] = -1
                            }
                        }
                    }
                }
                raylib.rlPopMatrix()
            }
            raylib.EndScissorMode()
        }
        raylib.EndTextureMode()

        raylib.BeginDrawing()
        {
            raylib.ClearBackground(raylib.Color{25, 25, 25, 255})
            source := raylib.Rectangle{ 0, f32(MAX_RENDER_HEIGHT - input.image_size.y), f32(input.image_size.x), -f32(input.image_size.y) }

            border := f32(2)
            available_space: [2]f32 = { f32(raylib.GetScreenWidth() - CONFIG_PANEL_WIDTH), f32(raylib.GetScreenHeight()) }
            dest := raylib.Rectangle{ 0, 0, f32(input.image_size.x), f32(input.image_size.y) }
            if dest.width > available_space.x {
                size_reduction := available_space.x / dest.width
                dest.width *= size_reduction
                dest.height *= size_reduction
            }

            if dest.height > available_space.y {
                size_reduction := available_space.y / dest.height
                dest.width *=  size_reduction
                dest.height *= size_reduction
            }

            extra_space := available_space - { dest.width, dest.height }
            dest.x = extra_space.x/2.0
            dest.y = extra_space.y/2.0

            raylib.DrawRectangleLinesEx(dest, border, raylib.YELLOW)
            dest.x += border
            dest.y += border
            dest.width -= 2.0*border
            dest.height -= 2.0*border
            raylib.DrawRectangleRec(dest, {20, 20, 20, 255})
            raylib.DrawTexturePro(render_texture.texture, source, dest, {}, 0.0, raylib.WHITE)

            mu_render(ctx)
        }
        raylib.EndDrawing()

        free_all(context.temp_allocator)
    }

    raylib.CloseWindow()
}