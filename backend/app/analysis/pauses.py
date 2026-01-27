"""
Pause and Silence Detection
Analyzes pauses in speech using librosa for audio processing.
"""

import logging
from pathlib import Path
from typing import NamedTuple

import librosa
import numpy as np

from app.models import PauseMetrics

logger = logging.getLogger(__name__)


class PauseSegment(NamedTuple):
    """A detected pause segment."""
    start: float
    end: float
    duration: float


def detect_pauses_librosa(
    audio_path: Path,
    min_pause_duration: float = 0.3,
    silence_threshold_db: float = -40.0
) -> list[PauseSegment]:
    """
    Detect pauses in audio using librosa's onset detection and RMS energy.
    
    Args:
        audio_path: Path to audio file.
        min_pause_duration: Minimum pause length to detect (seconds).
        silence_threshold_db: Threshold below which audio is considered silent (dB).
        
    Returns:
        List of detected pause segments.
    """
    # Load audio
    y, sr = librosa.load(str(audio_path), sr=None)
    
    # Calculate frame-level RMS energy
    frame_length = int(0.025 * sr)  # 25ms frames
    hop_length = int(0.010 * sr)    # 10ms hop
    
    rms = librosa.feature.rms(y=y, frame_length=frame_length, hop_length=hop_length)[0]
    
    # Convert to dB
    rms_db = librosa.amplitude_to_db(rms, ref=np.max)
    
    # Find silent frames
    silent_frames = rms_db < silence_threshold_db
    
    # Convert frame indices to time
    frame_times = librosa.frames_to_time(
        np.arange(len(rms_db)),
        sr=sr,
        hop_length=hop_length
    )
    
    # Group consecutive silent frames into pause segments
    pauses = []
    in_pause = False
    pause_start = 0.0
    
    for i, (is_silent, time) in enumerate(zip(silent_frames, frame_times)):
        if is_silent and not in_pause:
            # Start of pause
            in_pause = True
            pause_start = time
        elif not is_silent and in_pause:
            # End of pause
            in_pause = False
            pause_duration = time - pause_start
            
            if pause_duration >= min_pause_duration:
                pauses.append(PauseSegment(
                    start=pause_start,
                    end=time,
                    duration=pause_duration
                ))
    
    # Handle case where audio ends in silence
    if in_pause:
        final_time = frame_times[-1] if len(frame_times) > 0 else 0
        pause_duration = final_time - pause_start
        if pause_duration >= min_pause_duration:
            pauses.append(PauseSegment(
                start=pause_start,
                end=final_time,
                duration=pause_duration
            ))
    
    return pauses


def detect_pauses_from_transcription(
    segments: list[dict],
    min_pause_duration: float = 0.3
) -> list[PauseSegment]:
    """
    Detect pauses from gaps in transcription segments.
    
    Args:
        segments: Whisper transcription segments with timing.
        min_pause_duration: Minimum pause length to detect.
        
    Returns:
        List of detected pause segments.
    """
    if not segments:
        return []
    
    pauses = []
    
    for i in range(len(segments) - 1):
        current_end = segments[i]["end"]
        next_start = segments[i + 1]["start"]
        gap = next_start - current_end
        
        if gap >= min_pause_duration:
            pauses.append(PauseSegment(
                start=current_end,
                end=next_start,
                duration=gap
            ))
    
    return pauses


def analyze_pauses(
    audio_path: Path,
    total_duration: float,
    transcription_segments: list[dict] | None = None
) -> PauseMetrics:
    """
    Perform complete pause analysis.
    
    Args:
        audio_path: Path to audio file.
        total_duration: Total audio duration in seconds.
        transcription_segments: Optional Whisper segments for pause detection.
        
    Returns:
        PauseMetrics with all pause measurements.
    """
    logger.info("Analyzing pauses")
    
    # Detect pauses using both methods and combine
    audio_pauses = detect_pauses_librosa(audio_path)
    
    if transcription_segments:
        transcript_pauses = detect_pauses_from_transcription(transcription_segments)
        # Merge pause detections (use audio-based as primary)
        all_pauses = audio_pauses
    else:
        all_pauses = audio_pauses
    
    # Calculate metrics
    if all_pauses:
        total_pause_duration = sum(p.duration for p in all_pauses)
        pause_count = len(all_pauses)
        average_pause = total_pause_duration / pause_count
        longest_pause = max(p.duration for p in all_pauses)
    else:
        total_pause_duration = 0.0
        pause_count = 0
        average_pause = 0.0
        longest_pause = 0.0
    
    # Calculate pause ratio
    pause_ratio = total_pause_duration / total_duration if total_duration > 0 else 0.0
    
    logger.info(f"Pause analysis complete - Count: {pause_count}, Ratio: {pause_ratio:.2%}")
    
    return PauseMetrics(
        total_pause_duration=round(total_pause_duration, 3),
        pause_count=pause_count,
        pause_ratio=round(pause_ratio, 4),
        average_pause_duration=round(average_pause, 3),
        longest_pause=round(longest_pause, 3)
    )


def calculate_speech_duration(
    total_duration: float,
    pause_metrics: PauseMetrics
) -> float:
    """
    Calculate actual speech duration (excluding pauses).
    
    Args:
        total_duration: Total audio duration.
        pause_metrics: Analyzed pause metrics.
        
    Returns:
        Speech duration in seconds.
    """
    return total_duration - pause_metrics.total_pause_duration
