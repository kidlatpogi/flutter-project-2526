"""
Confidence Scoring Algorithm
Generates speaking confidence scores based on analyzed metrics.
"""

import logging
from typing import NamedTuple

from app.models import AudioMetrics, FluencyMetrics, PauseMetrics, ConfidenceScore

logger = logging.getLogger(__name__)


class ScoringWeights(NamedTuple):
    """Weights for different score components."""
    pitch_stability: float = 0.20
    voice_quality: float = 0.25
    fluency: float = 0.30
    pace: float = 0.25


# Optimal ranges for speech metrics (based on research)
OPTIMAL_RANGES = {
    # Pitch variation (standard deviation as % of mean)
    "pitch_cv_min": 10.0,   # Too monotone below this
    "pitch_cv_max": 30.0,   # Too variable above this
    "pitch_cv_optimal": 20.0,
    
    # Jitter (percentage) - normal speech: 0.5-1.0%
    "jitter_excellent": 0.5,
    "jitter_good": 1.0,
    "jitter_acceptable": 1.5,
    "jitter_poor": 2.5,
    
    # Shimmer (percentage) - normal speech: 3-5%
    "shimmer_excellent": 3.0,
    "shimmer_good": 5.0,
    "shimmer_acceptable": 7.0,
    "shimmer_poor": 10.0,
    
    # HNR (dB) - normal speech: > 20 dB
    "hnr_excellent": 25.0,
    "hnr_good": 20.0,
    "hnr_acceptable": 15.0,
    "hnr_poor": 10.0,
    
    # WPM - conversational: 120-150, presentations: 100-130
    "wpm_min": 100.0,
    "wpm_optimal": 130.0,
    "wpm_max": 160.0,
    
    # Filler ratio (fillers per 100 words)
    "filler_ratio_excellent": 1.0,
    "filler_ratio_good": 2.0,
    "filler_ratio_acceptable": 4.0,
    "filler_ratio_poor": 6.0,
    
    # Pause ratio (as percentage of total time)
    "pause_ratio_min": 0.10,
    "pause_ratio_optimal": 0.20,
    "pause_ratio_max": 0.35,
}


def _normalize_score(value: float, min_val: float, max_val: float, invert: bool = False) -> float:
    """
    Normalize a value to 0-100 scale.
    
    Args:
        value: The value to normalize.
        min_val: Minimum expected value.
        max_val: Maximum expected value.
        invert: If True, lower values get higher scores.
        
    Returns:
        Normalized score (0-100).
    """
    if max_val == min_val:
        return 50.0
    
    # Clamp value to range
    clamped = max(min_val, min(max_val, value))
    
    # Normalize to 0-1
    normalized = (clamped - min_val) / (max_val - min_val)
    
    if invert:
        normalized = 1.0 - normalized
    
    return normalized * 100.0


def _gaussian_score(value: float, optimal: float, sigma: float) -> float:
    """
    Score based on Gaussian distribution around optimal value.
    
    Args:
        value: The measured value.
        optimal: The optimal/target value.
        sigma: Standard deviation (controls how quickly score drops).
        
    Returns:
        Score (0-100) based on distance from optimal.
    """
    import math
    deviation = abs(value - optimal)
    score = math.exp(-(deviation ** 2) / (2 * sigma ** 2))
    return score * 100.0


def calculate_pitch_score(audio_metrics: AudioMetrics) -> float:
    """
    Calculate pitch stability score.
    
    Higher scores for:
    - Appropriate pitch variation (not too monotone, not too erratic)
    - Consistent pitch within normal ranges
    
    Args:
        audio_metrics: Analyzed audio metrics.
        
    Returns:
        Pitch stability score (0-100).
    """
    if audio_metrics.pitch_mean <= 0:
        return 50.0  # Neutral score if no pitch detected
    
    # Calculate coefficient of variation
    pitch_cv = (audio_metrics.pitch_std / audio_metrics.pitch_mean) * 100
    
    # Score based on optimal variation range
    score = _gaussian_score(
        pitch_cv,
        OPTIMAL_RANGES["pitch_cv_optimal"],
        sigma=10.0
    )
    
    return max(0.0, min(100.0, score))


def calculate_voice_quality_score(audio_metrics: AudioMetrics) -> float:
    """
    Calculate voice quality score based on jitter, shimmer, and HNR.
    
    Lower jitter/shimmer = more stable voice = higher score
    Higher HNR = clearer voice = higher score
    
    Args:
        audio_metrics: Analyzed audio metrics.
        
    Returns:
        Voice quality score (0-100).
    """
    # Jitter score (lower is better)
    if audio_metrics.jitter_local <= OPTIMAL_RANGES["jitter_excellent"]:
        jitter_score = 100.0
    elif audio_metrics.jitter_local <= OPTIMAL_RANGES["jitter_good"]:
        jitter_score = 85.0
    elif audio_metrics.jitter_local <= OPTIMAL_RANGES["jitter_acceptable"]:
        jitter_score = 70.0
    elif audio_metrics.jitter_local <= OPTIMAL_RANGES["jitter_poor"]:
        jitter_score = 50.0
    else:
        jitter_score = max(20.0, 50.0 - (audio_metrics.jitter_local - OPTIMAL_RANGES["jitter_poor"]) * 10)
    
    # Shimmer score (lower is better)
    if audio_metrics.shimmer_local <= OPTIMAL_RANGES["shimmer_excellent"]:
        shimmer_score = 100.0
    elif audio_metrics.shimmer_local <= OPTIMAL_RANGES["shimmer_good"]:
        shimmer_score = 85.0
    elif audio_metrics.shimmer_local <= OPTIMAL_RANGES["shimmer_acceptable"]:
        shimmer_score = 70.0
    elif audio_metrics.shimmer_local <= OPTIMAL_RANGES["shimmer_poor"]:
        shimmer_score = 50.0
    else:
        shimmer_score = max(20.0, 50.0 - (audio_metrics.shimmer_local - OPTIMAL_RANGES["shimmer_poor"]) * 5)
    
    # HNR score (higher is better)
    if audio_metrics.harmonics_to_noise_ratio >= OPTIMAL_RANGES["hnr_excellent"]:
        hnr_score = 100.0
    elif audio_metrics.harmonics_to_noise_ratio >= OPTIMAL_RANGES["hnr_good"]:
        hnr_score = 85.0
    elif audio_metrics.harmonics_to_noise_ratio >= OPTIMAL_RANGES["hnr_acceptable"]:
        hnr_score = 70.0
    elif audio_metrics.harmonics_to_noise_ratio >= OPTIMAL_RANGES["hnr_poor"]:
        hnr_score = 50.0
    else:
        hnr_score = max(20.0, audio_metrics.harmonics_to_noise_ratio * 3)
    
    # Weighted average (jitter and shimmer more important than HNR)
    return (jitter_score * 0.4) + (shimmer_score * 0.4) + (hnr_score * 0.2)


def calculate_fluency_score(fluency_metrics: FluencyMetrics) -> float:
    """
    Calculate fluency score based on filler words and word count.
    
    Args:
        fluency_metrics: Analyzed fluency metrics.
        
    Returns:
        Fluency score (0-100).
    """
    if fluency_metrics.total_words == 0:
        return 50.0
    
    # Filler ratio (fillers per 100 words)
    filler_ratio = (fluency_metrics.filler_count / fluency_metrics.total_words) * 100
    
    # Score based on filler frequency
    if filler_ratio <= OPTIMAL_RANGES["filler_ratio_excellent"]:
        filler_score = 100.0
    elif filler_ratio <= OPTIMAL_RANGES["filler_ratio_good"]:
        filler_score = 85.0
    elif filler_ratio <= OPTIMAL_RANGES["filler_ratio_acceptable"]:
        filler_score = 70.0
    elif filler_ratio <= OPTIMAL_RANGES["filler_ratio_poor"]:
        filler_score = 50.0
    else:
        filler_score = max(20.0, 50.0 - (filler_ratio - OPTIMAL_RANGES["filler_ratio_poor"]) * 5)
    
    return filler_score


def calculate_pace_score(
    fluency_metrics: FluencyMetrics,
    pause_metrics: PauseMetrics
) -> float:
    """
    Calculate speaking pace score based on WPM and pause patterns.
    
    Args:
        fluency_metrics: Analyzed fluency metrics.
        pause_metrics: Analyzed pause metrics.
        
    Returns:
        Pace score (0-100).
    """
    # WPM score (optimal around 130 WPM)
    wpm_score = _gaussian_score(
        fluency_metrics.words_per_minute,
        OPTIMAL_RANGES["wpm_optimal"],
        sigma=30.0
    )
    
    # Pause ratio score (optimal around 20%)
    pause_score = _gaussian_score(
        pause_metrics.pause_ratio,
        OPTIMAL_RANGES["pause_ratio_optimal"],
        sigma=0.10
    )
    
    # Combine scores (WPM weighted more heavily)
    return (wpm_score * 0.6) + (pause_score * 0.4)


def calculate_confidence_score(
    audio_metrics: AudioMetrics,
    fluency_metrics: FluencyMetrics,
    pause_metrics: PauseMetrics,
    weights: ScoringWeights | None = None
) -> ConfidenceScore:
    """
    Calculate overall speaking confidence score.
    
    Args:
        audio_metrics: Analyzed audio metrics.
        fluency_metrics: Analyzed fluency metrics.
        pause_metrics: Analyzed pause metrics.
        weights: Optional custom weights for score components.
        
    Returns:
        ConfidenceScore with overall and component scores.
    """
    if weights is None:
        weights = ScoringWeights()
    
    logger.info("Calculating confidence score")
    
    # Calculate component scores
    pitch_score = calculate_pitch_score(audio_metrics)
    voice_quality_score = calculate_voice_quality_score(audio_metrics)
    fluency_score = calculate_fluency_score(fluency_metrics)
    pace_score = calculate_pace_score(fluency_metrics, pause_metrics)
    
    # Calculate weighted overall score
    overall_score = (
        pitch_score * weights.pitch_stability +
        voice_quality_score * weights.voice_quality +
        fluency_score * weights.fluency +
        pace_score * weights.pace
    )
    
    # Round all scores
    confidence = ConfidenceScore(
        overall_score=round(overall_score, 2),
        pitch_score=round(pitch_score, 2),
        fluency_score=round(fluency_score, 2),
        voice_quality_score=round(voice_quality_score, 2),
        pace_score=round(pace_score, 2)
    )
    
    logger.info(f"Confidence score calculated: {confidence.overall_score}")
    
    return confidence
