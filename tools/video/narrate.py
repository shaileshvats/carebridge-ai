#!/usr/bin/env python3
"""Synthetic-voice narration for the recorded demo (macOS: `say` + `afconvert`).

usage: narrate.py <manifest.json> <workdir>
Writes <workdir>/manifest-narrated.json (segments stretched so speech never overruns its shot)
and <workdir>/narration.wav (speech placed at each caption's start).
Narration text is the caption, adjusted only so the voice pronounces HL7 and product terms clearly.
"""
import json, os, subprocess, sys, wave, array

manifest, work = sys.argv[1], sys.argv[2]
os.makedirs(work, exist_ok=True)
frames = json.load(open(manifest))

SPEAK = [
    ("ORU^R01", "O R U, R zero one"), ("ADT^A04", "A D T, A zero four"), ("HL7", "H L 7"), ("MLLP", "M L L P"),
    ("LIS", "L I S"), ("HIS", "H I S"), ("EMR", "E M R"), ("IRIS", "Iris"), ("Qwen3-4B", "Quen 3, 4 B"),
    ("IPM", "I P M"), ("patient_update", "patient update"), ("·", ","), ("…", ","), ("docker compose up", "docker compose up"),
]

def speakable(text):
    for a, b in SPEAK:
        text = text.replace(a, b)
    return text

# Group consecutive frames into caption segments.
segments = []
for i, f in enumerate(frames):
    if not segments or f["caption"] != segments[-1]["caption"]:
        segments.append({"caption": f["caption"], "first": i, "last": i})
    else:
        segments[-1]["last"] = i

RATE = 22050
for n, seg in enumerate(segments):
    aiff, wav = os.path.join(work, f"l{n:02d}.aiff"), os.path.join(work, f"l{n:02d}.wav")
    subprocess.run(["say", "-r", "185", "-o", aiff, speakable(seg["caption"])], check=True)
    subprocess.run(["afconvert", "-f", "WAVE", "-d", f"LEI16@{RATE}", "-c", "1", aiff, wav], check=True)
    with wave.open(wav) as w:
        seg["speech"] = w.getnframes() / w.getframerate()
        seg["wav"] = wav
    shot = sum(frames[j]["dur"] for j in range(seg["first"], seg["last"] + 1))
    need = seg["speech"] + 0.6 - shot
    if need > 0:  # hold the segment's last frame a little longer
        frames[seg["last"]]["dur"] += need

json.dump(frames, open(os.path.join(work, "manifest-narrated.json"), "w"), indent=1)

total = sum(f["dur"] for f in frames)
mix = array.array("h", [0]) * int(total * RATE + RATE)
t = 0.0
idx = 0
starts = []
for seg in segments:
    starts.append(sum(frames[j]["dur"] for j in range(0, seg["first"])))
for seg, start in zip(segments, starts):
    with wave.open(seg["wav"]) as w:
        data = array.array("h", w.readframes(w.getnframes()))
    off = int((start + 0.25) * RATE)
    for k, v in enumerate(data):
        if off + k < len(mix):
            mix[off + k] = max(-32768, min(32767, mix[off + k] + v))
with wave.open(os.path.join(work, "narration.wav"), "w") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(mix.tobytes())
print(f"{len(segments)} segments, video {total:.1f}s")
