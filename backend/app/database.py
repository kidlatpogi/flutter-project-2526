"""
Supabase Database Client
Handles all database interactions with Supabase.
"""

import logging
from typing import Any, Optional
from uuid import UUID

from supabase import create_client, Client

from app.config import get_settings
from app.models import AnalysisResult

logger = logging.getLogger(__name__)


class SupabaseClient:
    """Singleton Supabase client wrapper."""
    
    _instance: Optional[Client] = None
    
    @classmethod
    def get_client(cls) -> Client:
        """Get or create Supabase client instance."""
        if cls._instance is None:
            settings = get_settings()
            cls._instance = create_client(
                settings.supabase_url,
                settings.supabase_key
            )
            logger.info("Supabase client initialized successfully")
        return cls._instance
    
    @classmethod
    def reset_client(cls) -> None:
        """Reset client instance (useful for testing)."""
        cls._instance = None


def get_supabase() -> Client:
    """Dependency injection for Supabase client."""
    return SupabaseClient.get_client()


async def insert_analysis_result(result: AnalysisResult) -> dict[str, Any]:
    """
    Insert analysis result into the 'features' table.
    
    Args:
        result: The complete analysis result to store.
        
    Returns:
        The inserted record from Supabase.
        
    Raises:
        Exception: If database insertion fails.
    """
    client = get_supabase()
    
    # Prepare the record for insertion
    record = {
        "session_id": str(result.session_id),
        "transcription": result.transcription,
        "audio_duration": result.audio_duration,
        
        # Audio metrics
        "pitch_mean": result.audio_metrics.pitch_mean,
        "pitch_std": result.audio_metrics.pitch_std,
        "jitter_local": result.audio_metrics.jitter_local,
        "shimmer_local": result.audio_metrics.shimmer_local,
        "harmonics_to_noise_ratio": result.audio_metrics.harmonics_to_noise_ratio,
        
        # Fluency metrics
        "wpm": result.fluency_metrics.words_per_minute,
        "filler_count": result.fluency_metrics.filler_count,
        "filler_words_found": result.fluency_metrics.filler_words_found,
        "total_words": result.fluency_metrics.total_words,
        "articulation_rate": result.fluency_metrics.articulation_rate,
        
        # Pause metrics
        "total_pause_duration": result.pause_metrics.total_pause_duration,
        "pause_count": result.pause_metrics.pause_count,
        "pause_ratio": result.pause_metrics.pause_ratio,
        "average_pause_duration": result.pause_metrics.average_pause_duration,
        "longest_pause": result.pause_metrics.longest_pause,
        
        # Confidence scores
        "confidence_score": result.confidence_score.overall_score,
        "pitch_score": result.confidence_score.pitch_score,
        "fluency_score": result.confidence_score.fluency_score,
        "voice_quality_score": result.confidence_score.voice_quality_score,
        "pace_score": result.confidence_score.pace_score,
        
        # Timestamp
        "analyzed_at": result.analyzed_at.isoformat()
    }
    
    try:
        response = client.table("features").insert(record).execute()
        logger.info(f"Successfully inserted analysis result for session {result.session_id}")
        return response.data[0] if response.data else record
    except Exception as e:
        logger.error(f"Failed to insert analysis result: {e}")
        raise


async def get_analysis_by_session(session_id: UUID) -> Optional[dict[str, Any]]:
    """
    Retrieve analysis result by session ID.
    
    Args:
        session_id: The UUID of the session to retrieve.
        
    Returns:
        The analysis record if found, None otherwise.
    """
    client = get_supabase()
    
    try:
        response = client.table("features").select("*").eq(
            "session_id", str(session_id)
        ).execute()
        
        if response.data:
            return response.data[0]
        return None
    except Exception as e:
        logger.error(f"Failed to retrieve analysis result: {e}")
        raise


async def check_connection() -> bool:
    """
    Check if Supabase connection is working.
    
    Returns:
        True if connection is successful, False otherwise.
    """
    try:
        client = get_supabase()
        # Simple query to check connection
        client.table("features").select("session_id").limit(1).execute()
        return True
    except Exception as e:
        logger.warning(f"Supabase connection check failed: {e}")
        return False
