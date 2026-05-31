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
# Search recursively for all .mp4 files
mp4_files = glob.glob('assets/musics/**/*.mp4', recursive=True) + glob.glob('scenes/**/*.mp4', recursive=True)

if mp4_files:
    print(f"총 {len(mp4_files)}개의 새로운 비디오 파일(.mp4)을 발견했습니다.\n")
    for i, mp4_path in enumerate(mp4_files):
        dir_name = os.path.dirname(mp4_path)
        base_name = os.path.basename(mp4_path)
        ogv_name = os.path.splitext(base_name)[0] + ".ogv"
        ogv_path = os.path.join(dir_name, ogv_name)
        
        print(f"[{i+1}/{len(mp4_files)}] 비디오 변환 중: {mp4_path}")
        
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
            
            # Decide target width
            if mp4_size > 5.0:
                target_w = min(960, width)
            else:
                target_w = width
                
            target_w = int(round(target_w / 16.0) * 16)
            if target_w < 16:
                target_w = 16
                
            aspect_ratio = width / height
            target_h = int(round((target_w / aspect_ratio) / 16.0) * 16)
            if target_h < 16:
                target_h = 16
                
            print(f"  - 변환 해상도: {target_w}x{target_h} (16의 배수 맞춤)")
            ffmpeg_args.extend(["-vf", f"scale={target_w}:{target_h}"])
        else:
            if mp4_size > 5.0:
                print("  - [!] 해상도 감지 실패: 기본 해상도(960x544)로 인코딩합니다.")
                ffmpeg_args.extend(["-vf", "scale=960:544"])
            else:
                print("  - [!] 해상도 감지 실패: 원본 해상도 유지.")
                
        ffmpeg_args.extend([
            "-c:v", "libtheora",
            "-q:v", "6",
            "-an",
            "-threads", "0",
            ogv_path
        ])
        
        try:
            subprocess.run(ffmpeg_args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
            ogv_size = os.path.getsize(ogv_path) / (1024 * 1024)
            print(f"  -> 변환 완료: {ogv_path} ({ogv_size:.2f} MB)")
            os.remove(mp4_path)
            print("  -> 원본 비디오 파일 삭제 완료 (안전 캐싱)")
        except subprocess.CalledProcessError as e:
            print(f"  -> FFmpeg 에러 발생 (코드 {e.returncode})")
            err_msg = ""
            if e.stderr:
                try:
                    err_msg = e.stderr.decode('utf-8', errors='ignore')
                except:
                    err_msg = e.stderr.decode('cp949', errors='ignore')
            if err_msg:
                print("  [FFmpeg 에러 메시지]:")
                for line in err_msg.strip().split('\n')[-15:]:
                    print(f"    {line}")
        except Exception as e:
            print(f"  -> 변환 처리 중 오류 발생: {e}")
else:
    print("변환할 새로운 비디오 파일(.mp4)이 없습니다.\n")
# ==================================================
# 5. 오디오 볼륨 평준화 (MP3 Loudness Normalization - EBU R128)
# ==================================================
print("\n==================================================")
print("오디오 볼륨 평준화 작업 시작 (EBU R128 표준 -16 LUFS)")
print("==================================================")

normalized_cache_path = os.path.join(script_dir, "assets", "musics", "normalized_tracks.json")
normalized_cache = {}

if os.path.exists(normalized_cache_path):
    try:
        with open(normalized_cache_path, "r", encoding="utf-8") as f:
            normalized_cache = json.load(f)
    except Exception as e:
        print(f"  [!] 캐시 파일을 읽는 중 오류 발생 (초기화합니다): {e}")

all_mp3_files = glob.glob('assets/musics/**/*.mp3', recursive=True)
audio_normalized_count = 0

if all_mp3_files:
    print(f"총 {len(all_mp3_files)}개의 MP3 파일을 스캔 중...")
    for mp3_path in all_mp3_files:
        mp3_abs_path = os.path.abspath(mp3_path)
        file_size = os.path.getsize(mp3_abs_path)
        mp3_rel_path = os.path.relpath(mp3_abs_path, script_dir)
        
        # 캐시에 있고 크기가 동일하면 이미 평준화된 것으로 간주하고 스킵
        if mp3_rel_path in normalized_cache and normalized_cache[mp3_rel_path] == file_size:
            continue
            
        print(f"  -> 볼륨 평준화 처리 중: {mp3_rel_path}")
        
        # 임시 출력 파일 생성
        temp_out = mp3_abs_path + ".temp.mp3"
        
        # FFmpeg loudnorm 필터 실행
        loudnorm_args = [
            ffmpeg_path, "-y",
            "-i", mp3_abs_path,
            "-af", "loudnorm=I=-16:TP=-1.5:LRA=11",
            "-b:a", "192k",
            temp_out
        ]
        
        try:
            subprocess.run(loudnorm_args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
            if os.path.exists(temp_out) and os.path.getsize(temp_out) > 1000:
                os.replace(temp_out, mp3_abs_path)
                # 새로운 파일 크기를 캐시에 저장
                new_size = os.path.getsize(mp3_abs_path)
                normalized_cache[mp3_rel_path] = new_size
                print(f"     [+] 평준화 완료!")
                audio_normalized_count += 1
            else:
                print(f"     [!] 임시 파일 생성 실패")
                if os.path.exists(temp_out):
                    os.remove(temp_out)
        except Exception as e:
            print(f"     [!] FFmpeg 처리 중 오류 발생: {e}")
            if os.path.exists(temp_out):
                os.remove(temp_out)
                
    # 캐시 파일 저장
    try:
        os.makedirs(os.path.dirname(normalized_cache_path), exist_ok=True)
        with open(normalized_cache_path, "w", encoding="utf-8") as f:
            json.dump(normalized_cache, f, ensure_ascii=False, indent=4)
    except Exception as e:
        print(f"  [!] 캐시 파일 저장 실패: {e}")
        
    print(f"오디오 평준화 작업 완료! (새로 평준화된 곡: {audio_normalized_count}곡)\n")
else:
    print("스캔된 MP3 파일이 없습니다.\n")

print("\n변환 작업이 완료되었습니다! 고도로 돌아가시면 리로드됩니다.")
if sys.stdin.isatty():
    input("\n완료하려면 아무 키나 누르세요...")
