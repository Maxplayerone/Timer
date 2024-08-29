package timer

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"
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
Timer :: struct {
	hours:     int,
	mins:      int,
	secs:      int,
	mili:      int,
	secs_full: f32,
	_nsec:     i64,
}

clock_speed: f32 = 1.0

update_timer_ :: proc(time: ^Timer) {
	time.secs_full += rl.GetFrameTime() * clock_speed
	time.mili = int((time.secs_full - math.floor(time.secs_full)) * 100)
	time.secs = int(time.secs_full) % 60
	time.mins = (int(math.floor(time.secs_full)) / 60) % 60
	time.hours = int(math.floor(time.secs_full)) / 3600
}

get_timer_string :: proc(time: Timer) -> string {
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
	QueTower,
}

get_serialized_times :: proc(allocator := context.allocator) -> [dynamic]Timer {
	times := make([dynamic]Timer, allocator)

	data, ok := os.read_entire_file_from_filename("time.json", context.temp_allocator)

	if !ok {
		fmt.eprintln("Failed to load the file!")
	}

	json_data, err := json.parse(data, allocator = context.temp_allocator)
	if err != .None {
		fmt.eprintln("Failed to parse the json file.")
		fmt.eprintln("Error:", err)
	}

	#partial switch t in json_data {
	case json.Array:
		for time_obj_unpacked in t {
			tmp_time := Timer{}

			//sometimes time_obj_unpacked isn't json.Object...for some reason
			#partial switch time_obj in time_obj_unpacked {
			case json.Object:
				//fmt.println(time_obj)
				tmp_time.hours = int(time_obj["hours"].(json.Float))
				tmp_time.mins = int(time_obj["mins"].(json.Float))
				tmp_time.secs = int(time_obj["secs"].(json.Float))
				tmp_time.mili = int(time_obj["mili"].(json.Float))
				tmp_time._nsec = i64(time_obj["_nsec"].(json.Float))

				append(&times, tmp_time)
			}
		}
	}

	return times
}

save_time_to_json :: proc(timer: ^Timer, filename := "time.json") {
	timer._nsec = time.now()._nsec

	buf, ok := json.marshal(timer^, allocator = context.temp_allocator)
	if ok != nil {
		fmt.println(ok)
		fmt.println("marshalling didn't go well")
	}
	fd, open_err := os.open(filename, os.O_RDWR)
	defer os.close(fd)

	previous_data_tmp, _ := os.read_entire_file(filename, allocator = context.temp_allocator)

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
}

save_total_time :: proc(time_collector: Timer, filename := "total_time.json") {
	buf, err := json.marshal(time_collector, allocator = context.temp_allocator)
	if err != nil {
		fmt.println("json marshal error ", err)
	}

	os.write_entire_file(filename, buf)
}

get_total_time_from_json :: proc(filename := "total_time.json") -> Timer {
	data, ok := os.read_entire_file_from_filename(filename, context.temp_allocator)
	if !ok {
		fmt.eprintln("Failed to load the file!")
	}

	json_data, err := json.parse(data, allocator = context.temp_allocator)
	if err != .None {
		fmt.eprintln("Failed to parse the json file.")
		fmt.eprintln("Error:", err)
	}

	total_timer: Timer
	#partial switch t in json_data {
	case json.Object:
		total_timer.hours = int(t["hours"].(json.Float))
		total_timer.mins = int(t["mins"].(json.Float))
		total_timer.secs = int(t["secs"].(json.Float))
		total_timer.mili = int(t["mili"].(json.Float))
	}

	return total_timer
}

generate_random_colour :: proc() -> rl.Color {
	rand_num := rand.uint32() % 13
	color := rl.Color{}

	switch rand_num {
	case 0:
		color = rl.LIGHTGRAY
	case 1:
		color = rl.YELLOW
	case 2:
		color = rl.ORANGE
	case 3:
		color = rl.PINK
	case 4:
		color = rl.RED
	case 5:
		color = rl.GREEN
	case 6:
		color = rl.LIME
	case 7:
		color = rl.DARKGREEN
	case 8:
		color = rl.SKYBLUE
	case 9:
		color = rl.BLUE
	case 10:
		color = rl.PURPLE
	case 11:
		color = rl.VIOLET
	case 12:
		color = rl.WHITE
	case 13:
		color = rl.MAGENTA
	}
	return color
}

add_time_to_time_collector :: proc(timer_collector: ^Timer, timer: Timer) {
	timer_collector.hours += timer.hours
	timer_collector.mins += timer.mins
	timer_collector.secs += timer.secs
	timer_collector.mili += timer.mili

	for timer_collector.mili >= 1000 {
		timer_collector.secs += 1
		timer_collector.mili -= 1000
	}
	for timer_collector.secs >= 60 {
		timer_collector.mins += 1
		timer_collector.secs -= 60
	}
	for timer_collector.mins >= 60 {
		timer_collector.hours += 1
		timer_collector.mins -= 60
	}
}

main :: proc() {
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)

	rl.InitWindow(Width, Height, "timer")
	rl.SetTargetFPS(60)

	font := rl.GetFontDefault()
	timer := Timer{}

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
	last_saved_time := Timer{}
	saved_popup_color := rl.Color{0, 255, 0, 255}

	log_rect := rl.Rectangle{Width - 75.0, 25.0, 50.0, 50.0}
	log_color := rl.GRAY

	time_rect := rl.Rectangle{100.0, 100.0, Width - 200.0, 70.0}
	time_rect_y_increment := f32(90.0)
	time_log_cursor := 0

	scene := Scene.Main

	serialized_times := make([dynamic]Timer, context.allocator)

	time_collector := get_total_time_from_json()

	que_icon_rect := rl.Rectangle{27.0, 27.0, 46.0, 46.0}
	que_count_rect := rl.Rectangle{75.0, 25.0, 50.0, 50.0}
	que_count := time_collector.hours
	que_icon_color := generate_random_colour()

	new_que_popup_rect := rl.Rectangle{Width - 350.0, Height - 150.0, 300.0, 50.0}
	draw_new_que_popup_rect := false
	new_que_count := 0

	que_tower_rect := rl.Rectangle{Width - 75.0, 100.0, 50.0, 50.0}
	que_tower_color := rl.GRAY

	first_que_cube_rect := rl.Rectangle{100.0, Height - 55.0, 55.0, 55.0}
	que_cube_colours: [dynamic]rl.Color
	for _ in 0 ..< que_count {
		append(&que_cube_colours, generate_random_colour())
	}

	que_cube_count_rect := rl.Rectangle{Width / 2 - 150.0, 25.0, 300.0, 75.0}

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

		if rl.IsKeyPressed(.Q) {
			if scene == .Main {
				scene = .QueTower
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

				save_time_to_json(&timer)

				add_time_to_time_collector(&time_collector, timer)
				save_total_time(time_collector)

				//we hit another hour
				if time_collector.hours > que_count {
					new_que_count = time_collector.hours - que_count
					for _ in 0 ..< new_que_count {
						append(&que_cube_colours, generate_random_colour())
					}

					que_count = time_collector.hours
					draw_new_que_popup_rect = true
					que_icon_color = generate_random_colour()
				}

				last_saved_time = timer

				timer.secs_full = 0.0
				timer.mins = 0
				timer.secs = 0
				timer.mili = 0
				timer.hours = 0

				started = false
			}

			if collission_mouse_rect(buttons[0]) {
				save_color = {211, 250, 127, 255}

				if rl.IsMouseButtonPressed(.LEFT) {
					update_timer = false
					play_popup_animation = true

					save_time_to_json(&timer)

					last_saved_time = timer

					timer.secs_full = 0.0
					timer.mins = 0
					timer.secs = 0
					timer.mili = 0
					timer.hours = 0

					started = false
				}
			} else {
				save_color = {162, 245, 73, 255}
			}

			if started {
				if rl.IsKeyPressed(.F) {
					timer.secs_full = 0.0
					timer.mins = 0
					timer.secs = 0
					timer.mili = 0
					timer.hours = 0
					update_timer = false
					started = false
				}

				if collission_mouse_rect(buttons[2]) {
					start_color = {245, 122, 122, 255}

					if rl.IsMouseButtonPressed(.LEFT) {
						timer.secs_full = 0.0
						timer.mins = 0
						timer.secs = 0
						timer.mili = 0
						timer.hours = 0
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
		case .QueTower:
			if rl.IsKeyPressed(.R) {
				for i in 0 ..< len(que_cube_colours) {
					que_cube_colours[i] = generate_random_colour()
				}
			}

			if rl.IsKeyPressed(.UP) {
				first_que_cube_rect.y += 55.0
			}
			if rl.IsKeyPressed(.DOWN) {
				first_que_cube_rect.y -= 55.0
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

		//que tower rect
		if collission_mouse_rect(que_tower_rect) {
			que_tower_color = rl.GRAY
			if rl.IsMouseButtonPressed(.LEFT) {
				if scene == .Main {
					scene = .QueTower
				} else {
					scene = .Main
				}
			}
		} else {
			que_tower_color = rl.GRAY
		}


		if started && update_timer {
			update_timer_(&timer)
		}

		//rendering
		rl.BeginDrawing()
		rl.ClearBackground({240, 240, 240, 255})

		switch scene {
		case .Main:
			if play_popup_animation {
				animaton_time += f64(rl.GetFrameTime())
				//end of animation
				if animaton_time >= animation_time_max {
					animaton_time = 0.0
					play_popup_animation = false
					saved_popup_color.a = 255

					new_que_count = 0
					draw_new_que_popup_rect = false
				}

				saved_popup_color.a -= 2

				rl.DrawRectangleRec(saved_popup, saved_popup_color)
				adjust_and_draw_text(
					strings.concatenate(
						{"time spent: ", get_timer_string(last_saved_time)},
						context.temp_allocator,
					),
					saved_popup,
				)

				if draw_new_que_popup_rect {
					rl.DrawRectangleRec(new_que_popup_rect, saved_popup_color)
					buf: [4]byte
					new_que_count_str := strconv.itoa(buf[:], new_que_count)
					adjust_and_draw_text(
						strings.concatenate(
							{new_que_count_str, " new ques!"},
							allocator = context.temp_allocator,
						),
						new_que_popup_rect,
					)
				}
			}

			rl.DrawTextEx(
				font,
				strings.clone_to_cstring(get_timer_string(timer), context.temp_allocator),
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

			rl.DrawRectangleRec(que_icon_rect, que_icon_color)
			buf: [4]byte
			adjust_and_draw_text(strconv.itoa(buf[:], que_count), que_count_rect, color = rl.BLACK)

		case .Log:
			for ser_time, i in serialized_times[time_log_cursor:] {
				cur_rect := time_rect
				cur_rect.y += f32(i) * time_rect_y_increment
				rl.DrawRectangleRec(cur_rect, rl.BLACK)

				thing := time.Time {
					_nsec = ser_time._nsec,
				}
				hour, min, _ := time.clock_from_time(thing)
				year, month_enum, day := time.date(thing)
				month := int(month_enum)

				//---------------------
				//I have to add 2 to hour...why? Idk
				hour += 2
				//---------------------

				date_formatted := fmt.aprint(
					day,
					".",
					month,
					".",
					year,
					" ",
					hour,
					":",
					min,
					sep = "",
					allocator = context.temp_allocator,
				)

				rects := slice_rect(cur_rect, 2, {0.0, 0.0}, 0.0, context.temp_allocator)
				adjust_and_draw_text(get_timer_string(ser_time), rects[0])
				adjust_and_draw_text(date_formatted, rects[1])
			}
		case .QueTower:
			for que_color, i in que_cube_colours {

				x := f32(i % 16)
				y := f32(i / 16)
				que_cube := first_que_cube_rect
				que_cube.x += x * first_que_cube_rect.width
				que_cube.y -= y * first_que_cube_rect.height
				rl.DrawRectangleRec(que_cube, que_color)
			}

			rl.DrawRectangleRec(que_cube_count_rect, rl.Color{200, 200, 200, 255})
			buf: [4]byte
			adjust_and_draw_text(
				strings.concatenate(
					{"You have ", strconv.itoa(buf[:], que_count), " ques!"},
					allocator = context.temp_allocator,
				),
				que_cube_count_rect,
			)
		}

		rl.DrawRectangleRec(log_rect, log_color)
		adjust_and_draw_text(" i", log_rect)

		rl.DrawRectangleRec(que_tower_rect, que_tower_color)
		adjust_and_draw_text("Q", que_tower_rect, padding = {10.0, 10.0}, wanted_scale = 40.0)


		rl.EndDrawing()

		//free_all(context.temp_allocator)
	}

	delete(buttons)
	delete(serialized_times)
	delete(que_cube_colours)

	rl.CloseWindow()

	for key, value in tracking_allocator.allocation_map {
		fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
	}
}
