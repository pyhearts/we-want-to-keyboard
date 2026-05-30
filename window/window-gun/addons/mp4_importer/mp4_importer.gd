@tool
extends EditorImportPlugin

func _get_importer_name():
	return "antigravity.mp4.importer"

func _get_visible_name():
	return "MP4 Video to OGV Importer"

func _get_recognized_extensions():
	return ["mp4"]

func _get_save_extension():
	# 고도 표준 직렬화 리소스 포맷 (.res)으로 저장하여 임포터 검증 통과
	return "res"

func _get_resource_type():
	# VideoStream의 실 작동 클래스인 VideoStreamTheora 반환
	return "VideoStreamTheora"

func _get_preset_count():
	return 1

func _get_preset_name(preset_index):
	return "Default"

func _get_import_options(path, preset_index):
	return [
		{"name": "quality", "default_value": 6, "property_hint": PROPERTY_HINT_RANGE, "hint_string": "1,10"},
		{"name": "mute", "default_value": true}
	]

func _get_option_visibility(path, option_name, options):
	return true

func _import(source_file, save_path, options, platform_variants, gen_files):
	# 1. 실제 비디오 바이너리 데이터(.ogv)가 들어갈 고도 내부 임포트 경로
	var ogv_path = save_path + ".ogv"
	var global_source = ProjectSettings.globalize_path(source_file)
	var global_ogv = ProjectSettings.globalize_path(ogv_path)
	
	# 2. FFmpeg 동적 백그라운드 변환
	var ffmpeg_args = ["-y", "-i", global_source, "-c:v", "libtheora", "-q:v", str(options.quality)]
	if options.mute:
		ffmpeg_args.append("-an")
	ffmpeg_args.append(global_ogv)
	
	var output = []
	var exit_code = OS.execute("ffmpeg", ffmpeg_args, output, true)
	
	if exit_code != 0:
		push_error("MP4 Importer: FFmpeg transcoding failed for " + source_file + ". Log: " + str(output))
		return ERR_CANT_CREATE
		
	# 고도 엔진에게 변환된 미디어 파일(.ogv)의 의존성 라이프사이클을 추적하라고 알려줌
	gen_files.append(ogv_path)
	
	# 3. VideoStreamTheora 리소스 오브젝트 생성 및 가상 파일 매핑
	var video_stream = VideoStreamTheora.new()
	video_stream.file = ogv_path
	
	# 4. 고도 표준 이진 리소스 파일(.res) 형식으로 메타데이터 직렬화 디스크 저장
	var filename = save_path + "." + _get_save_extension()
	var save_err = ResourceSaver.save(video_stream, filename)
	
	if save_err != OK:
		push_error("MP4 Importer: Failed to save VideoStream resource to " + filename)
		return save_err
		
	return OK
