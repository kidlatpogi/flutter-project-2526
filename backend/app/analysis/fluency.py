"""
Fluency Analysis
Calculates speaking rate, filler words, and articulation metrics.
"""

import logging
import re
from typing import NamedTuple

from app.config import get_settings
from app.models import FluencyMetrics

logger = logging.getLogger(__name__)


class FillerAnalysis(NamedTuple):
    """Results of filler word analysis."""
    count: int
    words_found: list[str]
    positions: list[int]


def count_words(text: str) -> int:
    """
    Count the number of words in text.
    
    Args:
        text: Input text string.
        
    Returns:
        Word count.
    """
    # Split on whitespace and filter empty strings
    words = [w for w in text.split() if w.strip()]
    return len(words)


def detect_fillers(text: str, filler_words: list[str] | None = None) -> FillerAnalysis:
    """
    Detect filler words in transcribed text.
    
    Args:
        text: Transcribed text to analyze.
        filler_words: Optional custom list of filler words.
        
    Returns:
        FillerAnalysis with count and positions of fillers.
    """
    if filler_words is None:
        settings = get_settings()
        filler_words = settings.filler_words
    
    text_lower = text.lower()
    words = text_lower.split()
    
    found_fillers = []
    positions = []
    
    for i, word in enumerate(words):
        # Clean punctuation from word for matching
        clean_word = re.sub(r'[^\w\s]', '', word)
        
        # Check single-word fillers
        if clean_word in filler_words:
            found_fillers.append(clean_word)
            positions.append(i)
    
    # Check multi-word fillers (like "you know")
    for filler in filler_words:
        if ' ' in filler:
            pattern = r'\b' + re.escape(filler) + r'\b'
            matches = re.finditer(pattern, text_lower)
            for match in matches:
                found_fillers.append(filler)
                # Approximate position
                positions.append(text_lower[:match.start()].count(' '))
    
    return FillerAnalysis(
        count=len(found_fillers),
        words_found=found_fillers,
        positions=sorted(positions)
    )


def calculate_wpm(
    word_count: int,
    duration_seconds: float,
    speech_duration_seconds: float | None = None
) -> tuple[float, float]:
    """
    Calculate Words Per Minute and Articulation Rate.
    
    Args:
        word_count: Total number of words.
        duration_seconds: Total audio duration.
        speech_duration_seconds: Duration of actual speech (excluding pauses).
        
    Returns:
        Tuple of (WPM, Articulation Rate).
    """
    if duration_seconds <= 0:
        return 0.0, 0.0
    
    # Words Per Minute (including pauses)
    wpm = (word_count / duration_seconds) * 60
    
    # Articulation Rate (speech time only)
    if speech_duration_seconds and speech_duration_seconds > 0:
        articulation_rate = (word_count / speech_duration_seconds) * 60
    else:
        articulation_rate = wpm
    
    return wpm, articulation_rate


def analyze_fluency(
    text: str,
    total_duration: float,
    speech_duration: float | None = None
) -> FluencyMetrics:
    """
    Perform complete fluency analysis.
    
    Args:
        text: Transcribed text.
        total_duration: Total audio duration in seconds.
        speech_duration: Duration of actual speech in seconds.
        
    Returns:
        FluencyMetrics with all fluency measurements.
    """
    logger.info("Analyzing fluency metrics")
    
    # Count words
    total_words = count_words(text)
    
    # Detect fillers
    filler_analysis = detect_fillers(text)
    
    # Calculate speaking rates
    wpm, articulation_rate = calculate_wpm(total_words, total_duration, speech_duration)
    
    logger.info(f"Fluency analysis complete - WPM: {wpm:.1f}, Fillers: {filler_analysis.count}")
    
    return FluencyMetrics(
        words_per_minute=round(wpm, 2),
        filler_count=filler_analysis.count,
        filler_words_found=filler_analysis.words_found,
        total_words=total_words,
        articulation_rate=round(articulation_rate, 2)
    )
