package timer

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

Width :: 1080
Height :: 720

collission_mouse_rect :: proc(rect: rl.Rectangle) -> bool {
	pos := rl.GetMousePosition()
	if pos.x > rect.x &&
	   pos.x < rect.x + rect.width &&
	   pos.y > rect.y &&
	   pos.y < rect.y + rect.height {
		return true
	}
	return false
}


//you should only modify secs_full
//time.secs_full += 3600 for adding an hour
//time.secs_full += 60 for adding a minute
Time :: struct {
	hours:     int,
	mins:      int,
	secs:      int,
	mili:      int,
	secs_full: f32,
}

update_time :: proc(time: ^Time) {
	time.secs_full += rl.GetFrameTime()
	time.mili = int((time.secs_full - math.floor(time.secs_full)) * 100)
	time.secs = int(time.secs_full) % 60
	time.mins = (int(math.floor(time.secs_full)) / 60) % 60
	time.hours = int(math.floor(time.secs_full)) / 3600
}

get_time_string :: proc(time: Time) -> string {
	b := strings.builder_make(context.temp_allocator)
	buf: [8]byte

	strings.write_string(&b, strconv.itoa(buf[:], time.hours))
	strings.write_rune(&b, ':')

	strings.write_string(&b, strconv.itoa(buf[:], time.mins))
	strings.write_rune(&b, ':')

	strings.write_string(&b, strconv.itoa(buf[:], time.secs))
	strings.write_rune(&b, ':')


	strings.write_string(&b, strconv.itoa(buf[:], time.mili))

	return strings.to_string(b)
}

Scene :: enum {
	Main,
	Log,
}

get_serialized_times :: proc(allocator := context.allocator) -> [dynamic]Time {
	times := make([dynamic]Time, allocator)

	data, ok := os.read_entire_file_from_filename("time.json", context.temp_allocator)

	if !ok {
		fmt.eprintln("Failed to load the file!")
	}

	json_data, err := json.parse(data, allocator = context.temp_allocator)
	if err != .None {
		fmt.eprintln("Failed to parse the json file.")
		fmt.eprintln("Error:", err)
	}

	for time_obj_unpacked in json_data.(json.Array) {
		tmp_time := Time{}

		//sometimes time_obj_unpacked isn't json.Object...for some reason
		#partial switch time_obj in time_obj_unpacked {
		case json.Object:
			//fmt.println(time_obj)
			tmp_time.hours = int(time_obj["hours"].(json.Float))
			tmp_time.mins = int(time_obj["mins"].(json.Float))
			tmp_time.secs = int(time_obj["secs"].(json.Float))
			tmp_time.mili = int(time_obj["mili"].(json.Float))
			append(&times, tmp_time)
		}
	}

	return times
}

main :: proc() {
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)

	rl.InitWindow(Width, Height, "timer")
	rl.SetTargetFPS(60)

	font := rl.GetFontDefault()
	time := Time{}

	dims := rl.MeasureTextEx(font, "0:00:00:00", 40.0, 10.0)
	pos := rl.Vector2{Width / 2 - dims.x / 2, Height / 2 - dims.y}

	pause_color := rl.Color{87, 215, 247, 255}
	start_color := rl.Color{255, 79, 79, 255}
	save_color := rl.Color{162, 245, 73, 255}

	buttons_area := rl.Rectangle{Width / 2 - 300, Height / 2 + 50, 600, 100}

	buttons := slice_rect(buttons_area, 3, rl.Vector2{10.0, 10.0}, 30.0)

	paused := false
	update_timer := false
	started := false

	saved_popup := rl.Rectangle{Width - 350.0, Height - 75.0, 300.0, 50.0}
	animation_time_max := 1.5
	animaton_time := 0.0
	play_popup_animation := false
	last_saved_time := Time{}
	saved_popup_color := rl.Color{0, 255, 0, 255}

	log_rect := rl.Rectangle{Width - 75.0, 25.0, 50.0, 50.0}
	log_color := rl.GRAY

	time_rect := rl.Rectangle{100.0, 100.0, Width - 200.0, 70.0}
	time_rect_y_increment := f32(90.0)
	time_log_cursor := 0

	scene := Scene.Main

	serialized_times := make([dynamic]Time, context.allocator)

	for !rl.WindowShouldClose() {

		if rl.IsKeyPressed(.I) {
			if scene == .Main {
				scene = .Log
				delete(serialized_times)
				serialized_times = get_serialized_times()
			} else {
				scene = .Main
			}
		}

		//update buttons
		switch scene {
		case .Main:
			if rl.IsKeyPressed(.S) {
				update_timer = false
				play_popup_animation = true

				buf, ok := json.marshal(time, allocator = context.temp_allocator)
				if ok != nil {
					fmt.println(ok)
				}
				fd, open_err := os.open("time.json", os.O_RDWR)
				defer os.close(fd)

				previous_data_tmp, _ := os.read_entire_file(
					"time.json",
					allocator = context.temp_allocator,
				)

				//skipping the opening and closing square bracket 
				previous_data := previous_data_tmp
				if len(previous_data_tmp) > 0 {
					previous_data = previous_data_tmp[1:]

					os.write_string(fd, "[")
					os.write_string(fd, string(buf))
					os.write_string(fd, ",\n")
					os.write_string(fd, string(previous_data))
				} else {

					os.write_string(fd, "[")
					os.write_string(fd, string(buf))
					os.write_string(fd, ",\n")
					os.write_string(fd, "]")
				}

				last_saved_time = time

				time.secs_full = 0.0
				time.mins = 0
				time.secs = 0
				time.mili = 0
				time.hours = 0

				started = false
			}

			if collission_mouse_rect(buttons[0]) {
				save_color = {211, 250, 127, 255}

				if rl.IsMouseButtonPressed(.LEFT) {
					update_timer = false
					play_popup_animation = true

					buf, ok := json.marshal(time, allocator = context.temp_allocator)
					if ok != nil {
						fmt.println(ok)
					}
					fd, open_err := os.open("time.json", os.O_RDWR)
					defer os.close(fd)

					previous_data_tmp, _ := os.read_entire_file(
						"time.json",
						allocator = context.temp_allocator,
					)

					//skipping the opening and closing square bracket 
					previous_data := previous_data_tmp
					if len(previous_data_tmp) > 0 {
						previous_data = previous_data_tmp[1:]

						os.write_string(fd, "[")
						os.write_string(fd, string(buf))
						os.write_string(fd, ",\n")
						os.write_string(fd, string(previous_data))
					} else {

						os.write_string(fd, "[")
						os.write_string(fd, string(buf))
						os.write_string(fd, ",\n")
						os.write_string(fd, "]")
					}

					last_saved_time = time

					time.secs_full = 0.0
					time.mins = 0
					time.secs = 0
					time.mili = 0
					time.hours = 0

					started = false
				}
			} else {
				save_color = {162, 245, 73, 255}
			}

			if started {
				if rl.IsKeyPressed(.F) {
					time.secs_full = 0.0
					time.mins = 0
					time.secs = 0
					time.mili = 0
					time.hours = 0
					update_timer = false
					started = false
				}

				if collission_mouse_rect(buttons[2]) {
					start_color = {245, 122, 122, 255}

					if rl.IsMouseButtonPressed(.LEFT) {
						time.secs_full = 0.0
						time.mins = 0
						time.secs = 0
						time.mili = 0
						time.hours = 0
						update_timer = false
						started = false
					}
				} else {
					start_color = {255, 79, 79, 255}
				}

			} else {

				if rl.IsKeyPressed(.F) {

					update_timer = true
					started = true
				}

				if collission_mouse_rect(buttons[2]) {
					start_color = {245, 122, 122, 255}
					if rl.IsMouseButtonPressed(.LEFT) {
						update_timer = true
						started = true
					}
				} else {
					start_color = {255, 79, 79, 255}
				}
			}


			if !paused {
				if rl.IsKeyPressed(.P) {
					update_timer = false
					paused = true
				}

				if collission_mouse_rect(buttons[1]) {
					pause_color = {139, 220, 240, 255}

					if rl.IsMouseButtonPressed(.LEFT) {
						update_timer = false
						paused = true
					}
				} else {
					pause_color = {87, 215, 247, 255}
				}
			} else {
				if rl.IsKeyPressed(.P) {
					update_timer = true
					paused = false
				}

				if collission_mouse_rect(buttons[1]) {
					pause_color = {139, 220, 240, 255}

					if rl.IsMouseButtonPressed(.LEFT) {
						update_timer = true
						paused = false
					}
				} else {
					pause_color = {87, 215, 247, 255}
				}

			}

		case .Log:
			if time_log_cursor < len(serialized_times) - 1 &&
			   (rl.IsKeyPressed(.K) || rl.IsKeyPressed(.DOWN)) {
				time_log_cursor += 1
			}

			if time_log_cursor > 0 && (rl.IsKeyPressed(.J) || rl.IsKeyPressed(.UP)) {
				time_log_cursor -= 1
			}
		}

		if collission_mouse_rect(log_rect) {
			log_color = rl.LIGHTGRAY

			if rl.IsMouseButtonPressed(.LEFT) {
				if scene == .Main {
					scene = .Log
					delete(serialized_times)
					serialized_times = get_serialized_times()
				} else {
					scene = .Main
				}
			}
		} else {
			log_color = rl.GRAY
		}

		if started && update_timer {
			update_time(&time)
		}

		//rendering
		rl.BeginDrawing()
		rl.ClearBackground({240, 240, 240, 255})

		switch scene {
		case .Main:
			if play_popup_animation {
				animaton_time += f64(rl.GetFrameTime())
				if animaton_time >= animation_time_max {
					animaton_time = 0.0
					play_popup_animation = false
					saved_popup_color.a = 255
				}

				saved_popup_color.a -= 2

				rl.DrawRectangleRec(saved_popup, saved_popup_color)
				adjust_and_draw_text(
					strings.concatenate(
						{"time spent: ", get_time_string(last_saved_time)},
						context.temp_allocator,
					),
					saved_popup,
				)
			}

			rl.DrawTextEx(
				font,
				strings.clone_to_cstring(get_time_string(time), context.temp_allocator),
				pos,
				40.0,
				10.0,
				rl.BLACK,
			)

			rl.DrawRectangleRec(buttons[0], save_color)
			adjust_and_draw_text("save", buttons[0])

			rl.DrawRectangleRec(buttons[2], start_color)
			if started {
				adjust_and_draw_text("stop", buttons[2])
			} else {
				adjust_and_draw_text("start", buttons[2])
			}

			rl.DrawRectangleRec(buttons[1], pause_color)
			if paused {
				adjust_and_draw_text("unpause", buttons[1])
			} else {
				adjust_and_draw_text("pause", buttons[1])
			}

		case .Log:
			for ser_time, i in serialized_times[time_log_cursor:] {
				cur_rect := time_rect
				cur_rect.y += f32(i) * time_rect_y_increment
				rl.DrawRectangleRec(cur_rect, rl.BLACK)
				adjust_and_draw_text(get_time_string(ser_time), cur_rect)
			}
		}

		rl.DrawRectangleRec(log_rect, log_color)
		adjust_and_draw_text(" i", log_rect)

		rl.EndDrawing()

		free_all(context.temp_allocator)
	}

	delete(buttons)
	delete(serialized_times)

	rl.CloseWindow()

	for key, value in tracking_allocator.allocation_map {
		fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
	}
}
