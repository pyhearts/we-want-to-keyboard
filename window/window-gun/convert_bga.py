import os
import glob
import subprocess
import sys
import json

# Ensure UTF-8 output on Windows console
if sys.platform.startswith('win'):
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

print("==================================================")
print("BGA (.mp4 -> .ogv) 최적화 변환 도구 (Godot 4 호환)")
print("==================================================")

# Detect local ffmpeg/ffprobe first
script_dir = os.path.dirname(os.path.abspath(__file__))
local_ffmpeg = os.path.join(script_dir, "ffmpeg.exe")
local_ffprobe = os.path.join(script_dir, "ffprobe.exe")

ffmpeg_path = local_ffmpeg if os.path.exists(local_ffmpeg) else "ffmpeg"
ffprobe_path = local_ffprobe if os.path.exists(local_ffprobe) else "ffprobe"

print(f"사용할 FFmpeg: {ffmpeg_path}")
print(f"사용할 FFprobe: {ffprobe_path}\n")

def get_video_size(mp4_path):
    cmd = [
        ffprobe_path, "-v", "error",
        "-select_streams", "v:0",
        "-show_entries", "stream=width,height",
        "-of", "json",
        mp4_path
    ]
    try:
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        info = json.loads(res.stdout)
        s = info['streams'][0]
        return int(s['width']), int(s['height'])
    except Exception as e:
        print(f"  [경고] 비디오 해상도를 가져오지 못했습니다 (ffprobe 실패): {e}")
        return None

# Search recursively for all .mp4 files
mp4_files = glob.glob('assets/musics/**/*.mp4', recursive=True) + glob.glob('scenes/**/*.mp4', recursive=True)

if not mp4_files:
    print("변환할 새로운 .mp4 파일이 없습니다.")
    print("원하는 곡 폴더에 bga.mp4 파일을 드래그앤드롭한 후 도구를 실행해주세요.")
    if sys.stdin.isatty():
        input("\n종료하려면 엔터 키를 누르세요...")
    exit()

print(f"총 {len(mp4_files)}개의 새로운 비디오 파일을 발견했습니다.\n")

for i, mp4_path in enumerate(mp4_files):
    dir_name = os.path.dirname(mp4_path)
    base_name = os.path.basename(mp4_path)
    ogv_name = os.path.splitext(base_name)[0] + ".ogv"
    ogv_path = os.path.join(dir_name, ogv_name)
    
    print(f"[{i+1}/{len(mp4_files)}] 변환 중: {mp4_path}")
    
    mp4_size = os.path.getsize(mp4_path) / (1024 * 1024)
    print(f"  - 원본 용량: {mp4_size:.2f} MB")
    
    # Run ffprobe to check dimensions
    dimensions = get_video_size(mp4_path)
    
    ffmpeg_args = [
        ffmpeg_path, "-y",
        "-i", mp4_path
    ]
    
    # Calculate divisible-by-16 resolution
    if dimensions:
        width, height = dimensions
        print(f"  - 원본 해상도: {width}x{height}")
        
        # Decide target width: scale down if size is large
        if mp4_size > 5.0:
            target_w = min(960, width)
        else:
            target_w = width
            
        # Round target_w to nearest multiple of 16
        target_w = int(round(target_w / 16.0) * 16)
        if target_w < 16:
            target_w = 16
            
        # Maintain aspect ratio and round target_h to nearest multiple of 16
        aspect_ratio = width / height
        target_h = int(round((target_w / aspect_ratio) / 16.0) * 16)
        if target_h < 16:
            target_h = 16
            
        print(f"  - 변환 해상도: {target_w}x{target_h} (16의 배수 정렬 완료)")
        ffmpeg_args.extend(["-vf", f"scale={target_w}:{target_h}"])
    else:
        # Fallback if ffprobe failed
        if mp4_size > 5.0:
            print("  - [경고] ffprobe 실패로 인해 기본 최적 해상도(960x544)로 인코딩합니다.")
            ffmpeg_args.extend(["-vf", "scale=960:544"])
        else:
            print("  - [경고] ffprobe 실패로 인해 원본 해상도로 인코딩합니다. (가장자리에 노이즈가 생길 수 있습니다)")
            
    ffmpeg_args.extend([
        "-c:v", "libtheora",
        "-q:v", "6",  # Increased quality to 6 (very clean and compact)
        "-an",
        "-threads", "0",
        ogv_path
    ])
    
    try:
        # Run FFmpeg
        res = subprocess.run(ffmpeg_args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        ogv_size = os.path.getsize(ogv_path) / (1024 * 1024)
        print(f"  -> 변환 완료: {ogv_path} ({ogv_size:.2f} MB)")
        
        # Safely delete the original .mp4 to prevent engine warnings and save space
        os.remove(mp4_path)
        print("  -> 원본 .mp4 파일 정리 완료 (삭제)")
    except subprocess.CalledProcessError as e:
        print(f"  -> 오류 발생: FFmpeg 실행 실패 (반환 코드 {e.returncode})")
        err_msg = ""
        if e.stderr:
            try:
                err_msg = e.stderr.decode('utf-8', errors='ignore')
            except:
                err_msg = e.stderr.decode('cp949', errors='ignore')
        elif e.stdout:
            try:
                err_msg = e.stdout.decode('utf-8', errors='ignore')
            except:
                err_msg = e.stdout.decode('cp949', errors='ignore')
        
        if err_msg:
            print("  [FFmpeg 에러 메시지]:")
            for line in err_msg.strip().split('\n')[-15:]:  # Show last 15 lines of error
                print(f"    {line}")
    except Exception as e:
        print(f"  -> 일반 오류 발생: {e}")

print("\n모든 변환 작업이 완료되었습니다! 고도 에디터로 돌아가시면 즉시 인식됩니다.")
if sys.stdin.isatty():
    input("\n종료하려면 엔터 키를 누르세요...")
