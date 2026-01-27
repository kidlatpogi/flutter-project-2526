"""
Acoustic Analysis using Praat-Parselmouth
Extracts pitch, jitter, shimmer, and other voice quality metrics.
"""

import logging
from pathlib import Path
from typing import NamedTuple

import numpy as np
import parselmouth
from parselmouth.praat import call

from app.models import AudioMetrics

logger = logging.getLogger(__name__)


class VoiceQualityMetrics(NamedTuple):
    """Raw voice quality measurements."""
    jitter_local: float
    jitter_local_absolute: float
    jitter_rap: float
    jitter_ppq5: float
    shimmer_local: float
    shimmer_local_db: float
    shimmer_apq3: float
    shimmer_apq5: float
    harmonics_to_noise_ratio: float


def extract_pitch_features(sound: parselmouth.Sound) -> tuple[float, float, float, float]:
    """
    Extract pitch (F0) features from audio.
    
    Args:
        sound: Parselmouth Sound object.
        
    Returns:
        Tuple of (mean, std, min, max) pitch values in Hz.
    """
    # Create pitch object with appropriate settings for speech
    pitch = call(sound, "To Pitch", 0.0, 75, 500)  # time_step=0, min=75Hz, max=500Hz
    
    # Get pitch values
    pitch_values = pitch.selected_array["frequency"]
    
    # Filter out unvoiced frames (0 values)
    voiced_pitch = pitch_values[pitch_values > 0]
    
    if len(voiced_pitch) == 0:
        logger.warning("No voiced frames detected in audio")
        return 0.0, 0.0, 0.0, 0.0
    
    return (
        float(np.mean(voiced_pitch)),
        float(np.std(voiced_pitch)),
        float(np.min(voiced_pitch)),
        float(np.max(voiced_pitch))
    )


def extract_voice_quality(sound: parselmouth.Sound) -> VoiceQualityMetrics:
    """
    Extract jitter, shimmer, and HNR using Praat's PointProcess.
    
    Args:
        sound: Parselmouth Sound object.
        
    Returns:
        VoiceQualityMetrics with all voice quality measurements.
    """
    # Create pitch object
    pitch = call(sound, "To Pitch", 0.0, 75, 500)
    
    # Create PointProcess (pulses) from pitch
    point_process = call(sound, "To PointProcess (periodic, cc)", 75, 500)
    
    # Get time range
    start_time = sound.xmin
    end_time = sound.xmax
    
    # Extract Jitter measurements
    try:
        jitter_local = call(point_process, "Get jitter (local)", start_time, end_time, 0.0001, 0.02, 1.3)
        jitter_local_absolute = call(point_process, "Get jitter (local, absolute)", start_time, end_time, 0.0001, 0.02, 1.3)
        jitter_rap = call(point_process, "Get jitter (rap)", start_time, end_time, 0.0001, 0.02, 1.3)
        jitter_ppq5 = call(point_process, "Get jitter (ppq5)", start_time, end_time, 0.0001, 0.02, 1.3)
    except Exception as e:
        logger.warning(f"Jitter extraction failed: {e}")
        jitter_local = jitter_local_absolute = jitter_rap = jitter_ppq5 = 0.0
    
    # Extract Shimmer measurements
    try:
        shimmer_local = call([sound, point_process], "Get shimmer (local)", start_time, end_time, 0.0001, 0.02, 1.3, 1.6)
        shimmer_local_db = call([sound, point_process], "Get shimmer (local_dB)", start_time, end_time, 0.0001, 0.02, 1.3, 1.6)
        shimmer_apq3 = call([sound, point_process], "Get shimmer (apq3)", start_time, end_time, 0.0001, 0.02, 1.3, 1.6)
        shimmer_apq5 = call([sound, point_process], "Get shimmer (apq5)", start_time, end_time, 0.0001, 0.02, 1.3, 1.6)
    except Exception as e:
        logger.warning(f"Shimmer extraction failed: {e}")
        shimmer_local = shimmer_local_db = shimmer_apq3 = shimmer_apq5 = 0.0
    
    # Extract Harmonics-to-Noise Ratio
    try:
        harmonicity = call(sound, "To Harmonicity (cc)", 0.01, 75, 0.1, 1.0)
        hnr = call(harmonicity, "Get mean", 0, 0)
    except Exception as e:
        logger.warning(f"HNR extraction failed: {e}")
        hnr = 0.0
    
    # Handle NaN values
    def safe_float(val: float) -> float:
        return 0.0 if np.isnan(val) else float(val)
    
    return VoiceQualityMetrics(
        jitter_local=safe_float(jitter_local) * 100,  # Convert to percentage
        jitter_local_absolute=safe_float(jitter_local_absolute) * 1000,  # Convert to ms
        jitter_rap=safe_float(jitter_rap) * 100,
        jitter_ppq5=safe_float(jitter_ppq5) * 100,
        shimmer_local=safe_float(shimmer_local) * 100,  # Convert to percentage
        shimmer_local_db=safe_float(shimmer_local_db),
        shimmer_apq3=safe_float(shimmer_apq3) * 100,
        shimmer_apq5=safe_float(shimmer_apq5) * 100,
        harmonics_to_noise_ratio=safe_float(hnr)
    )


def analyze_acoustics(audio_path: Path) -> AudioMetrics:
    """
    Perform complete acoustic analysis on audio file.
    
    Args:
        audio_path: Path to the audio file.
        
    Returns:
        AudioMetrics with all acoustic measurements.
    """
    logger.info(f"Analyzing acoustics: {audio_path}")
    
    # Load audio with Parselmouth
    sound = parselmouth.Sound(str(audio_path))
    
    # Extract pitch features
    pitch_mean, pitch_std, pitch_min, pitch_max = extract_pitch_features(sound)
    
    # Extract voice quality metrics
    voice_quality = extract_voice_quality(sound)
    
    logger.info(f"Acoustic analysis complete - Pitch: {pitch_mean:.1f}Hz, Jitter: {voice_quality.jitter_local:.2f}%")
    
    return AudioMetrics(
        pitch_mean=pitch_mean,
        pitch_std=pitch_std,
        jitter_local=voice_quality.jitter_local,
        shimmer_local=voice_quality.shimmer_local,
        harmonics_to_noise_ratio=voice_quality.harmonics_to_noise_ratio
    )
