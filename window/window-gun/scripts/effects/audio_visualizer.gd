@tool
extends VBoxContainer
class_name AudioVisualizer

# --- Exported Properties (Inspector Sync) ---
@export var bar_count: int = 16:
	set(val):
		bar_count = max(1, val)
		_update_bars()

@export var max_bar_width: float = 135.0:
	set(val):
		max_bar_width = max(1.0, val)
		_update_bars()

@export var bar_color: Color = Color(1.0, 1.0, 1.0, 0.35):
	set(val):
		bar_color = val
		_update_bar_colors()

@export var separation: int = 6:
	set(val):
		separation = max(0, val)
		add_theme_constant_override("separation", separation)

@export var is_left_aligned: bool = true:
	set(val):
		is_left_aligned = val
		_update_bars()

# --- Internal Variables ---
var bar_widths: Array[float] = []
var bars: Array[ColorRect] = []
var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance = null
var dynamic_max_volume: float = 0.12
var editor_time: float = 0.0

func _ready() -> void:
	# Ignore mouse events on the container itself to prevent blocking gameplay input
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Initialise layout theme settings
	add_theme_constant_override("separation", separation)
	
	# Clear the material in case it was set to the shader previously
	material = null
	
	# Build visualizer bars
	_update_bars()
	
	# Only initialize the real audio spectrum analyzer during gameplay
	if not Engine.is_editor_hint():
		call_deferred("_setup_spectrum_analyzer")

func _setup_spectrum_analyzer() -> void:
	# Find or insert spectrum analyzer effect on the Master bus (bus 0)
	var effect_idx = -1
	for idx in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, idx) is AudioEffectSpectrumAnalyzer:
			effect_idx = idx
			break
			
	if effect_idx == -1:
		var analyzer_effect = AudioEffectSpectrumAnalyzer.new()
		analyzer_effect.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
		AudioServer.add_bus_effect(0, analyzer_effect)
		effect_idx = AudioServer.get_bus_effect_count(0) - 1
		
	spectrum_analyzer = AudioServer.get_bus_effect_instance(0, effect_idx)

func _update_bars() -> void:
	# Clean up any existing children to prevent duplicates
	for child in get_children():
		if child is ColorRect:
			child.queue_free()
			
	bars.clear()
	bar_widths.resize(bar_count)
	bar_widths.fill(3.0) # Start with minimum size
	
	for i in range(bar_count):
		var bar = ColorRect.new()
		bar.name = "Bar_%d" % i
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Set alignment: expand left-to-right (BEGIN) or right-to-left (END)
		if is_left_aligned:
			bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		else:
			bar.size_flags_horizontal = Control.SIZE_SHRINK_END
			
		bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bar.color = bar_color
		bar.custom_minimum_size = Vector2(3, 4) # Width 3px, minimum height 4px
		
		add_child(bar)
		bars.append(bar)
		
	queue_redraw()

func _update_bar_colors() -> void:
	for bar in bars:
		if is_instance_valid(bar):
			bar.color = bar_color

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# Live Preview: animate dummy pulsing wave in the editor
		editor_time += delta * 3.5
		if bars.size() > 0:
			for i in range(bars.size()):
				# Create a beautiful wave pattern using sine
				var dummy_energy = (sin(editor_time + i * 0.4) + 1.0) * 0.5 * (1.0 - float(i) / bar_count * 0.4)
				var target_width = dummy_energy * max_bar_width
				target_width = clamp(target_width, 3.0, max_bar_width * 0.92)
				target_width = max(3.0, target_width)
				bar_widths[i] = lerp(bar_widths[i], target_width, 8.0 * delta)
				bars[i].custom_minimum_size.x = bar_widths[i]
		return
		
	# Runtime gameplay: animate bars using real microphone/audio spectrum analysis
	if spectrum_analyzer and bars.size() > 0:
		var min_freq = 20.0
		var max_freq = 12500.0
		var log_min = log(min_freq)
		var log_max = log(max_freq)
		
		# --- Dynamic AGC (Auto Gain Control) ---
		var current_max_mag = 0.01
		var magnitudes: Array[float] = []
		magnitudes.resize(bar_count)
		
		for i in range(bar_count):
			var t_low = float(i) / bar_count
			var t_high = float(i + 1) / bar_count
			var freq_low = exp(log_min + (log_max - log_min) * t_low)
			var freq_high = exp(log_min + (log_max - log_min) * t_high)
			
			var mag = spectrum_analyzer.get_magnitude_for_frequency_range(freq_low, freq_high).length()
			magnitudes[i] = mag
			if mag > current_max_mag:
				current_max_mag = mag
				
		# Update dynamic volume peak smoothly
		dynamic_max_volume = lerp(dynamic_max_volume, max(0.018, current_max_mag), 0.35 * delta)
		var sensitivity = 0.36 / dynamic_max_volume
		
		# Apply spectrum data to custom bar widths
		for i in range(bars.size()):
			var freq_weight = 1.0 + (float(i) / bar_count) * 2.3
			if i < 4:
				freq_weight *= 0.55 # Block bass frequencies from overloading the bars
				
			var energy = magnitudes[i] * sensitivity * freq_weight
			var target_width = energy * max_bar_width
			
			# Cap at 92% to prevent visual clipping/saturation
			target_width = clamp(target_width, 3.0, max_bar_width * 0.92)
			target_width = max(3.0, target_width)
			
			if target_width > bar_widths[i]:
				bar_widths[i] = lerp(bar_widths[i], target_width, 24.0 * delta)
			else:
				bar_widths[i] = lerp(bar_widths[i], target_width, 10.0 * delta)
				
			bars[i].custom_minimum_size.x = bar_widths[i]

func _draw() -> void:
	if Engine.is_editor_hint():
		# Premium Gizmo Experience: draw a glowing boundary box in editor 
		# so the developer can see exactly where the drag bounds are!
		var rect = Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.2, 0.6, 1.0, 0.45), false, 1.0) # Bounding outline
