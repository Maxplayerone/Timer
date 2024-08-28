package timer

import rl "vendor:raylib"

import "core:fmt"
import "core:strings"

slice_rect :: proc(
	rect: rl.Rectangle,
	rect_count: int,
	padding: rl.Vector2,
	space_btw_rects: f32,
	allocator := context.allocator,
) -> []rl.Rectangle {
	rects := make([dynamic]rl.Rectangle, allocator)
	rect_width :=
		(rect.width - f32(rect_count - 1) * space_btw_rects - padding.x * 2) / f32(rect_count)
	for i in 0 ..< rect_count {
		append(
			&rects,
			rl.Rectangle {
				rect.x + (rect_width + space_btw_rects) * f32(i) + padding.x,
				rect.y + padding.y,
				rect_width,
				rect.height - padding.y * 2,
			},
		)
	}
	return rects[:]
}

fit_text_in_line :: proc(text: string, scale: int, width: f32, min_scale := 15) -> int {
	text_cstring := strings.clone_to_cstring(text, context.temp_allocator)
	if f32(rl.MeasureText(text_cstring, i32(min_scale))) > width {
		return 1000
	}
	scale := scale
	for scale > min_scale {
		if f32(rl.MeasureText(text_cstring, i32(scale))) < width {
			break
		}
		scale -= 1
	}
	return scale
}

fit_text_in_column :: proc(scale: int, height: f32, min_scale: f32 = 15) -> int {
	if f32(scale) < height {
		return scale
	} else if height >= min_scale {
		return int(height)
	} else {
		return 1000
	}
}

fit_text_in_rect :: proc(
	text: string,
	dims: rl.Vector2,
	wanted_scale: int,
	min_scale: f32 = 15,
) -> int {
	scale_x := fit_text_in_line(text, wanted_scale, dims.x, int(min_scale))
	scale_y := fit_text_in_column(wanted_scale, dims.y, min_scale)

	if scale_x < scale_y && scale_y != 1000 {
		return scale_x
	} else if scale_y < scale_x && scale_x != 1000 {
		return scale_y
	} else if scale_x == scale_y && scale_x != 1000 {
		return scale_x
	} else {
		return 0
	}
}

adjust_and_draw_text :: proc(
	text: string,
	rect: rl.Rectangle,
	padding: rl.Vector2 = {10.0, 10.0},
	wanted_scale: int = 100,
	min_scale: f32 = 15,
	color := rl.WHITE,
) {
	scale := fit_text_in_rect(
		text,
		{rect.width - 2 * padding.x, rect.height - 2 * padding.y},
		wanted_scale,
	)

	if scale != 0 {
		rl.DrawText(
			strings.clone_to_cstring(text, context.temp_allocator),
			i32(rect.x + padding.x),
			i32(rect.y + padding.y),
			i32(scale),
			color,
		)
	}
}
