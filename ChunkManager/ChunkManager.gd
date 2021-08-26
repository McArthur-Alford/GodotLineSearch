extends Node2D

export var debug_lines:bool = true
export var debug_print:bool = true


# The size of the grid in units
var grid_scale:int = 64;

# Chuck used chunks in here as a Vector2() key with Array of line objects.
# Importantly, these reference lines (not points).
# Chunk Coords are the top left corner.
var chunks:Dictionary = {}

var drawing_start:Vector2 = Vector2.ZERO
var drawing_end:Vector2 = Vector2.ZERO

onready var road:Object = preload("res://Road/Road.tscn")

func calculate_intersects(start:Vector2, end:Vector2) -> Array:
	# returns an array of all chunks intersected by the line
	
	if(start == end):
		# This should never happen but why not!
		return []
	
	var intersects:Array = []
	intersects.append((start))
	
	var direction:Vector2 = (end-start).normalized()
	
	# (x,y) = (x0, y0) + t(x1 - x0, y1 - y0)
	# For y-axis intercepts, y=y0+t(y1-y0) must result in y being on the grid, so y=Gi => i.e t=(Gi-y0)/(y1-y0) where G is grid size, i is the ith intersect
	# Same for x
	
	# There is a really weird bug where one extra intersect is being checked backwards. Ic cannot figure it out.
	
	var flip_x_range = range(global_to_chunk_coords(end).x,global_to_chunk_coords(start).x+1)
	for i in range(global_to_chunk_coords(start).x+1,global_to_chunk_coords(end).x+1) if flip_x_range.size() == 0 else flip_x_range:
		if(direction.x==0):
			break
		var t:float = (grid_scale*i - start.x) / (direction.x)
		if abs(t) > (start-end).length():
			continue
		if(!intersects.has(t*direction + start)):
			intersects.append(t*direction + start + direction/100)
			# (add a tiny bit of direction extra so it is not on a cell boundary exactly, 
			# causes less double ups and more neighbouring chunks to be hit)
	
	# literally the same code for x, should probably factor this out:
	var flip_y_range = range(global_to_chunk_coords(end).y,global_to_chunk_coords(start).y+1)
	for i in range(global_to_chunk_coords(start).y+1,global_to_chunk_coords(end).y+1) if flip_y_range.size() == 0 else flip_y_range:
		if(direction.y==0):
			break
		var t:float = (grid_scale*i - start.y) / (direction.y)
		if abs(t) > (start-end).length():
			continue
		if(!intersects.has(t*direction + start)):
			intersects.append(t*direction + start + direction/100) 
	
	intersects.append((end))
	
	return intersects

func round_array_to_chunk_coords(points:Array) -> Array:
	for i in points.size():
		points[i] = global_to_chunk_coords(points[i])
	return points

func round_array_to_chunk_corner(points:Array) -> Array:
	for i in points.size():
		points[i] = round_to_chunk_corner(points[i])
	return points

func round_to_chunk_corner(pos:Vector2) -> Vector2:
	var cpos:Vector2 = (pos/grid_scale).floor() * grid_scale
	return cpos

func global_to_chunk_coords(pos:Vector2) -> Vector2:
	var cpos:Vector2 = (pos/grid_scale).floor()
	return cpos


func get_chunk(pos:Vector2) -> Dictionary:
	return chunks.get(pos)

func get_chunk_global(pos:Vector2) -> Dictionary:
	# Useful if using global coordinates
	return chunks.get(global_to_chunk_coords(pos))


func add_to_chunk(pos:Vector2, line:Object):
	if(chunks.get(pos) == null):
		chunks[pos] = [line]
	else:
		if(!chunks.get(pos).has(line)):
			chunks[pos].append(line)

# Everything below this point is just debug drawing:

func _draw():
	if(debug_lines):
		# Draws a grid that should line up with the chunks with length and height of 10,000.
		for x in range(0, round(get_viewport_rect().size.x / grid_scale)):
			var start:Vector2 = Vector2(x*grid_scale,-10000)
			var end:Vector2 = Vector2(x*grid_scale,10000)
			draw_line(start,end,Color("#ff79c6"))
			draw_line(Vector2(start.y,start.x), Vector2(end.y, end.x), Color("#ff79c6"))
		
		# Highlights chunk containing cursor.
		draw_rect(Rect2(global_to_chunk_coords(get_global_mouse_position())*grid_scale, Vector2.ONE*grid_scale),Color("50fa7b"))

	var intercepts:Array = calculate_intersects(drawing_start, drawing_end)
	for point in intercepts:
		draw_circle(point, 3, Color.white)
	var cells:Array = round_array_to_chunk_corner(intercepts)
	for cell in cells:
		draw_rect(Rect2(cell,Vector2.ONE*grid_scale),Color("#50fa7b05"))
	
	draw_string(Label.new().get_font(""), get_global_mouse_position(), JSON.print(get_chunk_global(get_global_mouse_position())), Color.white)

func _process(delta):
	update()

func _input(event):
	if(Input.is_action_just_pressed("draw_line")):
		drawing_start = get_global_mouse_position()
	if(Input.is_action_pressed("draw_line")):
		drawing_end = get_global_mouse_position()
	if(Input.is_action_just_released("draw_line")):
		var instance = road.instance()
		instance.init(drawing_start, drawing_end)
		get_tree().current_scene.add_child(instance)
		var chunks_hit:Array = round_array_to_chunk_coords(calculate_intersects(drawing_start, drawing_end))
		for hit in chunks_hit:
			add_to_chunk(hit, instance)
		
