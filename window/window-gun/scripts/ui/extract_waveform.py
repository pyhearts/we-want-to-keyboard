import os
import sys
import json
import subprocess
import struct

def extract_waveform(mp3_path, output_json_path, ffmpeg_path="ffmpeg"):
    if not os.path.exists(mp3_path):
        print(f"Error: MP3 file not found: {mp3_path}")
        return False

    print(f"Extracting waveform from: {mp3_path}")
    
    # 44100Hz 16-bit Mono Raw PCM
    sample_rate = 16000 # 16kHz is enough for high-res visualization and faster processing
    cmd = [
        ffmpeg_path, "-y", "-i", mp3_path,
        "-f", "s16le", "-ac", "1", "-ar", str(sample_rate), "-"
    ]
    
    try:
        process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except Exception as e:
        print(f"Failed to start ffmpeg: {e}")
        return False
        
    samples_per_second = 60 # 60Hz update rate for smooth visuals
    chunk_size = sample_rate // samples_per_second
    
    lows = []
    mids = []
    highs = []
    
    # DSP Filters (Simple IIR single-pole filters)
    # Low-pass filter (cut ~150Hz): alpha_l
    # High-pass filter (cut ~2000Hz): alpha_h
    dt = 1.0 / sample_rate
    
    # RC filter coefficients
    # fc_low = 150 Hz
    rc_low = 1.0 / (2.0 * 3.14159 * 150.0)
    alpha_low = dt / (rc_low + dt)
    
    # fc_high = 2000 Hz
    rc_high = 1.0 / (2.0 * 3.14159 * 2000.0)
    alpha_high = rc_high / (rc_high + dt)
    
    low_prev = 0.0
    high_prev = 0.0
    sample_prev = 0.0
    
    # Read block by block
    bytes_per_chunk = chunk_size * 2 # 2 bytes per s16 sample
    
    while True:
        data = process.stdout.read(bytes_per_chunk)
        if not data:
            break
            
        num_samples = len(data) // 2
        if num_samples == 0:
            break
            
        # Parse s16 samples
        fmt = f"<{num_samples}h"
        samples = struct.unpack(fmt, data[:num_samples*2])
        
        sum_low = 0.0
        sum_mid = 0.0
        sum_high = 0.0
        
        for s in samples:
            val = float(s) / 32768.0 # Normalize to -1.0 ~ 1.0
            
            # Low pass filter (Bass/Kick)
            low_val = low_prev + alpha_low * (val - low_prev)
            low_prev = low_val
            
            # High pass filter (Treble/Vocals)
            high_val = alpha_high * (high_prev + val - sample_prev)
            high_prev = high_val
            sample_prev = val
            
            # Mid band (Snare/Melody)
            mid_val = val - low_val - high_val
            
            sum_low += abs(low_val)
            sum_mid += abs(mid_val)
            sum_high += abs(high_val)
            
        # Store average amplitudes for this chunk
        lows.append(round((sum_low / num_samples) * 3.5, 4) if num_samples > 0 else 0.0)
        mids.append(round((sum_mid / num_samples) * 3.5, 4) if num_samples > 0 else 0.0)
        highs.append(round((sum_high / num_samples) * 4.5, 4) if num_samples > 0 else 0.0)
        
    process.stdout.close()
    process.wait()
    
    # Clamp results to a reasonable scale
    lows = [min(1.0, l) for l in lows]
    mids = [min(1.0, m) for m in mids]
    highs = [min(1.0, h) for h in highs]
    
    duration = len(lows) / float(samples_per_second)
    
    result = {
        "duration": duration,
        "samples_per_second": samples_per_second,
        "low": lows,
        "mid": mids,
        "high": highs
    }
    
    with open(output_json_path, "w", encoding="utf-8") as f:
        json.dump(result, f)
        
    print(f"Successfully generated waveform data: {output_json_path}")
    return True

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python extract_waveform.py <mp3_path> <output_json_path> [ffmpeg_path]")
        sys.exit(1)
        
    mp3 = sys.argv[1]
    out = sys.argv[2]
    ff = sys.argv[3] if len(sys.argv) > 3 else "ffmpeg"
    
    extract_waveform(mp3, out, ff)
