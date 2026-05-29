"""Generate correct.wav and error.wav game sound effects."""
import wave
import struct
import math
import os

def write_wav(path, samples, sample_rate=44100):
    with wave.open(path, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        f.writeframes(struct.pack(f'<{len(samples)}h', *samples))

def clamp(v):
    return max(-32767, min(32767, int(v)))

def correct_sound():
    """Pleasant two-tone ding: 880 Hz + 1320 Hz, 0.8 s with soft decay."""
    sr = 44100
    n = int(sr * 0.8)
    out = []
    for i in range(n):
        t = i / sr
        p = t / 0.8
        env = math.exp(-p * 3.5) * (1.0 - math.exp(-p * 50))
        s = env * (0.55 * math.sin(2 * math.pi * 880  * t) +
                   0.45 * math.sin(2 * math.pi * 1320 * t))
        out.append(clamp(s * 32767))
    return out, sr

def error_sound():
    """Two short buzzer pulses at 220 Hz, 0.65 s total."""
    sr = 44100
    n = int(sr * 0.65)
    out = []
    for i in range(n):
        t = i / sr
        # Burst 1: 0 – 0.20 s  |  gap: 0.20 – 0.32 s  |  Burst 2: 0.32 – 0.52 s
        if t < 0.20:
            env = 0.85 * math.exp(-t * 6)
        elif t < 0.32:
            env = 0.0
        elif t < 0.52:
            t2 = t - 0.32
            env = 0.85 * math.exp(-t2 * 6)
        else:
            env = 0.0
        freq = 220
        s = env * (math.sin(2 * math.pi * freq * t) +
                   0.4 * math.sin(2 * math.pi * freq * 2 * t) +
                   0.15 * math.sin(2 * math.pi * freq * 3 * t))
        out.append(clamp(s * 28000))
    return out, sr

if __name__ == '__main__':
    out_dir = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
    os.makedirs(out_dir, exist_ok=True)

    samples, sr = correct_sound()
    write_wav(os.path.join(out_dir, 'correct.wav'), samples, sr)
    print(f'correct.wav: {len(samples)} samples ({len(samples)/sr:.2f}s)')

    samples, sr = error_sound()
    write_wav(os.path.join(out_dir, 'error.wav'), samples, sr)
    print(f'error.wav:   {len(samples)} samples ({len(samples)/sr:.2f}s)')
