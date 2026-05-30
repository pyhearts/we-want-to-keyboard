import os
import glob
import subprocess
import sys

# Ensure UTF-8 output on Windows console
if sys.platform.startswith('win'):
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

print("==================================================")
print("BGA (.mp4 -> .ogv) 최적화 변환 도구 (Godot 4 호환)")
print("==================================================")

# Search recursively for all .mp4 files
mp4_files = glob.glob('assets/musics/**/*.mp4', recursive=True) + glob.glob('scenes/**/*.mp4', recursive=True)

if not mp4_files:
    print("변환할 새로운 .mp4 파일이 없습니다.")
    print("원하시는 곡 폴더에 bga.mp4 파일을 드래그앤드롭한 뒤 이 도구를 실행해주세요.")
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
    
    ffmpeg_args = [
        "ffmpeg", "-y",
        "-i", mp4_path
    ]
    
    # Scale to 960x540 for large videos (> 5MB)
    if mp4_size > 5.0:
        ffmpeg_args.extend(["-vf", "scale=960:540"])
        print("  - [추천] 고해상도 영상을 최적 해상도(960x540)로 다운스케일링 적용...")
        
    ffmpeg_args.extend([
        "-c:v", "libtheora",
        "-q:v", "3",
        "-an",
        "-threads", "0",
        ogv_path
    ])
    
    try:
        # Run FFmpeg
        subprocess.run(ffmpeg_args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        ogv_size = os.path.getsize(ogv_path) / (1024 * 1024)
        print(f"  -> 변환 완료: {ogv_path} ({ogv_size:.2f} MB)")
        
        # Safely delete the original .mp4 to prevent engine warnings and save space
        os.remove(mp4_path)
        print("  -> 원본 .mp4 파일 정리 완료 (삭제)")
    except Exception as e:
        print(f"  -> 오류 발생: {e}")

print("\n모든 변환 작업이 완료되었습니다! 고도 에디터로 돌아가시면 즉시 인식됩니다.")
input("\n종료하려면 엔터 키를 누르세요...")
