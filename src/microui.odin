package main

import mu "vendor:microui"
import "vendor:raylib"
import "core:unicode/utf8"

@(private="file")
mu_atlas_texture: raylib.Texture

mu_init :: proc(ctx: ^mu.Context) {
    pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
    defer delete(pixels)

    for alpha, i in mu.default_atlas_alpha {
        pixels[i].rgb = 0xff
        pixels[i].a = alpha
    }

    image: raylib.Image
    image.data = &pixels[0]
    image.width = mu.DEFAULT_ATLAS_WIDTH
    image.height = mu.DEFAULT_ATLAS_HEIGHT
    image.mipmaps = 1
    image.format = .UNCOMPRESSED_R8G8B8A8

    mu_atlas_texture = raylib.LoadTextureFromImage(image)

    mu.init(ctx)

    ctx.text_width = mu.default_atlas_text_width
    ctx.text_height = mu.default_atlas_text_height
}

mu_input :: proc(ctx: ^mu.Context) {
    mpos := raylib.GetMousePosition()
    mu.input_mouse_move(ctx, i32(mpos.x), i32(mpos.y))

    raylib_mouse_buttons := [?]raylib.MouseButton{ .LEFT, .MIDDLE, .RIGHT }
    microui_mouse_buttons := [?]mu.Mouse{ .LEFT, .MIDDLE, .RIGHT }
    #assert(len(raylib_mouse_buttons) == len(microui_mouse_buttons))
    for _, i in raylib_mouse_buttons {
        if raylib.IsMouseButtonPressed(raylib_mouse_buttons[i]) do mu.input_mouse_down(ctx, i32(mpos.x), i32(mpos.y), microui_mouse_buttons[i])
        if raylib.IsMouseButtonReleased(raylib_mouse_buttons[i]) do mu.input_mouse_up(ctx, i32(mpos.x), i32(mpos.y), microui_mouse_buttons[i])
    }

    raylib_keys := [?]raylib.KeyboardKey{ .LEFT_SHIFT, .RIGHT_SHIFT, .LEFT_CONTROL, .RIGHT_CONTROL, .LEFT_ALT, .RIGHT_ALT, .ENTER, .KP_ENTER, .BACKSPACE }
    microui_keys := [?]mu.Key{ .SHIFT, .SHIFT, .CTRL, .CTRL, .ALT, .ALT, .RETURN, .RETURN, .BACKSPACE }
    #assert(len(raylib_keys) == len(microui_keys))
    for _, i in raylib_keys {
        if raylib.IsKeyPressed(raylib_keys[i]) do mu.input_key_down(ctx, microui_keys[i])
        if raylib.IsKeyReleased(raylib_keys[i]) do mu.input_key_up(ctx, microui_keys[i])
    }

    // TODO: Text input
    rune_count: int
    rune_buffer: [512]rune
    for {
        rune_entered := raylib.GetCharPressed()
        if rune_entered == 0 do break
        rune_buffer[rune_count] = rune_entered
        rune_count += 1
    }
    if rune_count > 0 {
        text_input := utf8.runes_to_string(rune_buffer[:rune_count], context.temp_allocator)
        mu.input_text(ctx, text_input)
    }
}

mu_render :: proc(ctx: ^mu.Context) {
    render_texture :: proc(texture: raylib.Texture, dst: ^raylib.Rectangle, src: mu.Rect, color: mu.Color) {
        dst.width = f32(src.w)
        dst.height = f32(src.h)

        rsrc: raylib.Rectangle = {
            x = f32(src.x), y = f32(src.y),
            width = f32(src.w), height = f32(src.h),
        }
        rcolor: raylib.Color = { r = color.r, g = color.g, b = color.b, a = color.a }

        raylib.DrawTexturePro(texture, rsrc, dst^, {}, 0.0, rcolor)
    }

    raylib.BeginScissorMode(0, 0, raylib.GetScreenWidth(), raylib.GetScreenHeight())

    command_backing: ^mu.Command
    for variant in mu.next_command_iterator(ctx, &command_backing) {
        switch cmd in variant {
            case ^mu.Command_Text:
                dst := raylib.Rectangle{f32(cmd.pos.x), f32(cmd.pos.y), 0, 0}
                for ch in cmd.str do if ch&0xc0 != 0x80 {
                    r := min(int(ch), 127)
                    src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
                    render_texture(mu_atlas_texture, &dst, src, cmd.color)
                    dst.x += dst.width
                }
            case ^mu.Command_Rect:
                color := raylib.Color{cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a }
                raylib.DrawRectangle(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h, color)
            case ^mu.Command_Icon:
                src := mu.default_atlas[cmd.id]
                x := cmd.rect.x + (cmd.rect.w - src.w)/2
                y := cmd.rect.y + (cmd.rect.h - src.h)/2
                render_texture(mu_atlas_texture, &raylib.Rectangle{f32(x), f32(y), 0, 0}, src, cmd.color)
            case ^mu.Command_Clip:
                raylib.EndScissorMode()
                raylib.BeginScissorMode(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h)
            case ^mu.Command_Jump:
                unreachable()
        }
    }

    raylib.EndScissorMode()
}

mu_hovered_id :: proc(ctx: ^mu.Context) -> (id: mu.Id, ok: bool) {
    if ctx.hover_root != nil do return ctx.hover_id, true
    return
}

mu_button_id :: proc(ctx: ^mu.Context, label: string, icon: mu.Icon = .NONE) -> (id: mu.Id) {
    id = len(label) > 0 ? mu.get_id(ctx, label) : mu.get_id(ctx, uintptr(icon))
    return
}

mu_move_container :: proc(container: ^mu.Container, x, y: i32) {
    body_offset_x := container.body.x - container.rect.x
    body_offset_y := container.body.y - container.rect.y
    container.rect.x = x
    container.rect.y = y
    container.body.x = x + body_offset_x
    container.body.y = y + body_offset_y
}