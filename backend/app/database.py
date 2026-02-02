"""
Supabase Database Client
Handles all database interactions with Supabase.
"""

import logging
from typing import Any, Optional
from uuid import UUID

from supabase import create_client, Client

from app.config import get_settings
from app.models import AnalysisResult, UserProfile, UpdateUserProfile

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


async def insert_analysis_result(result: AnalysisResult, user_id: str | None = None) -> dict[str, Any]:
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

    if user_id:
        record["user_id"] = user_id
    
    try:
        response = client.table("features").insert(record).execute()
        if getattr(response, "error", None):
            logger.error(f"Supabase insert error (features): {response.error}")
        logger.info(f"Successfully inserted analysis result for session {result.session_id}")
        return response.data[0] if response.data else record
    except Exception as e:
        error_message = str(e)
        logger.error(f"Failed to insert analysis result: {e}")

        # Retry without analyzed_at if column doesn't exist
        if "analyzed_at" in record and "analyzed_at" in error_message:
            fallback = dict(record)
            fallback.pop("analyzed_at", None)
            try:
                response = client.table("features").insert(fallback).execute()
                if getattr(response, "error", None):
                    logger.error(f"Supabase insert error (features fallback no analyzed_at): {response.error}")
                logger.info("Inserted analysis result without analyzed_at")
                return response.data[0] if response.data else fallback
            except Exception as retry_error:
                logger.error(f"Retry insert without analyzed_at failed: {retry_error}")

        # Retry without user_id if column doesn't exist
        if "user_id" in record and "user_id" in error_message:
            fallback = dict(record)
            fallback.pop("user_id", None)
            try:
                response = client.table("features").insert(fallback).execute()
                if getattr(response, "error", None):
                    logger.error(f"Supabase insert error (features fallback no user_id): {response.error}")
                logger.info("Inserted analysis result without user_id")
                return response.data[0] if response.data else fallback
            except Exception as retry_error:
                logger.error(f"Retry insert without user_id failed: {retry_error}")

        # Final fallback: insert minimal columns only
        minimal_record = {
            "session_id": str(result.session_id),
            "confidence_score": result.confidence_score.overall_score,
            "audio_duration": result.audio_duration,
        }
        if user_id:
            minimal_record["user_id"] = user_id

        try:
            response = client.table("features").insert(minimal_record).execute()
            if getattr(response, "error", None):
                logger.error(f"Supabase insert error (features minimal fallback): {response.error}")
            logger.info("Inserted analysis result with minimal columns")
            return response.data[0] if response.data else minimal_record
        except Exception as retry_error:
            logger.error(f"Minimal insert failed: {retry_error}")

        raise


async def insert_session_record(
    result: AnalysisResult,
    user_id: str | None = None,
    script_title: str | None = None,
) -> None:
    """
    Insert a session summary into the 'sessions' table if it exists.
    This is best-effort and will not raise if the table/columns are missing.
    """
    client = get_supabase()

    record = {
        "id": str(result.session_id),
        "session_id": str(result.session_id),
        "script_title": script_title or "Practice Session",
        "duration_seconds": int(result.audio_duration),
        "confidence_score": result.confidence_score.overall_score,
        "pitch_score": result.confidence_score.pitch_score,
        "voice_quality_score": result.confidence_score.voice_quality_score,
        "pace_score": result.confidence_score.pace_score,
        "fluency_score": result.confidence_score.fluency_score,
        "transcription": result.transcription,
        "created_at": result.analyzed_at.isoformat(),
    }

    if user_id:
        record["user_id"] = user_id

    try:
        response = client.table("sessions").insert(record).execute()
        if getattr(response, "error", None):
            logger.error(f"Supabase insert error (sessions): {response.error}")
        logger.info(f"Inserted session record {result.session_id}")
    except Exception as e:
        error_message = str(e)
        logger.error(f"Failed to insert session record: {e}")
        
        # Retry without new columns if they don't exist yet
        if any(col in error_message for col in ["pitch_score", "voice_quality_score", "pace_score", "fluency_score", "transcription"]):
            fallback_record = {
                "id": str(result.session_id),
                "session_id": str(result.session_id),
                "script_title": script_title or "Practice Session",
                "duration_seconds": int(result.audio_duration),
                "confidence_score": result.confidence_score.overall_score,
                "created_at": result.analyzed_at.isoformat(),
            }
            if user_id:
                fallback_record["user_id"] = user_id
            try:
                response = client.table("sessions").insert(fallback_record).execute()
                logger.info(f"Inserted session record (fallback without metrics) {result.session_id}")
            except Exception as retry_error:
                logger.error(f"Fallback session insert also failed: {retry_error}")


async def get_analysis_by_session(session_id: UUID) -> Optional[dict[str, Any]]:
    """
    Retrieve analysis result by session ID.
    
    Args:
        session_id: The UUID of the session to retrieve.
        
    Returns:
        The analysis record in API-compatible format if found, None otherwise.
    """
    client = get_supabase()
    
    try:
        response = client.table("features").select("*").eq(
            "session_id", str(session_id)
        ).execute()
        
        if response.data:
            row = response.data[0]
            # Convert flat DB row to nested API format for AnalysisModel
            return {
                "session_id": row.get("session_id"),
                "transcription": row.get("transcription", ""),
                "audio_duration": row.get("audio_duration", 0),
                "audio_metrics": {
                    "pitch_mean": row.get("pitch_mean", 0),
                    "pitch_std": row.get("pitch_std", 0),
                    "jitter_local": row.get("jitter_local", 0),
                    "shimmer_local": row.get("shimmer_local", 0),
                    "harmonics_to_noise_ratio": row.get("harmonics_to_noise_ratio", 0),
                },
                "fluency_metrics": {
                    "words_per_minute": row.get("wpm", 0),
                    "filler_count": row.get("filler_count", 0),
                    "filler_words_found": row.get("filler_words_found", []),
                    "total_words": row.get("total_words", 0),
                    "articulation_rate": row.get("articulation_rate", 0),
                },
                "pause_metrics": {
                    "total_pause_duration": row.get("total_pause_duration", 0),
                    "pause_count": row.get("pause_count", 0),
                    "pause_ratio": row.get("pause_ratio", 0),
                    "average_pause_duration": row.get("average_pause_duration", 0),
                    "longest_pause": row.get("longest_pause", 0),
                },
                "confidence_score": {
                    "overall_score": row.get("confidence_score", 0),
                    "pitch_score": row.get("pitch_score", 0),
                    "fluency_score": row.get("fluency_score", 0),
                    "voice_quality_score": row.get("voice_quality_score", 0),
                    "pace_score": row.get("pace_score", 0),
                },
                "analyzed_at": row.get("analyzed_at") or row.get("created_at"),
            }
        return None
    except Exception as e:
        logger.error(f"Failed to retrieve analysis result: {e}")
        raise


async def get_db_debug_info() -> dict[str, Any]:
    """
    Return basic counts and latest rows for debugging.
    """
    client = get_supabase()

    info: dict[str, Any] = {}

    try:
        features_resp = client.table("features").select(
            "session_id, user_id, analyzed_at, created_at, confidence_score",
            count="exact",
        ).order("created_at", desc=True).limit(1).execute()
        info["features_count"] = features_resp.count or 0
        info["features_latest"] = features_resp.data[0] if features_resp.data else None
    except Exception as e:
        info["features_error"] = str(e)

    try:
        sessions_resp = client.table("sessions").select(
            "session_id, user_id, created_at, confidence_score",
            count="exact",
        ).order("created_at", desc=True).limit(1).execute()
        info["sessions_count"] = sessions_resp.count or 0
        info["sessions_latest"] = sessions_resp.data[0] if sessions_resp.data else None
    except Exception as e:
        info["sessions_error"] = str(e)

    return info


async def get_sessions(user_id: str, limit: int = 20) -> list[dict[str, Any]]:
    """
    Retrieve session summaries for a user.
    Attempts to read from sessions table; falls back to features table if needed.
    """
    client = get_supabase()
    
    logger.info(f"Getting sessions for user_id: {user_id}")

    # First try sessions table with all metrics
    try:
        response = client.table("sessions").select(
            "id, session_id, script_title, created_at, duration_seconds, confidence_score, pitch_score, voice_quality_score, pace_score, fluency_score, transcription"
        ).eq("user_id", user_id).order("created_at", desc=True).limit(limit).execute()
        if response.data:
            logger.info(f"Found {len(response.data)} sessions in sessions table")
            return response.data
        logger.info("No sessions in sessions table, trying features table")
    except Exception as e:
        error_message = str(e)
        logger.error(f"Sessions table error: {e}")
        
        # Retry without new columns if they don't exist
        if any(col in error_message for col in ["pitch_score", "voice_quality_score", "pace_score", "fluency_score", "transcription"]):
            try:
                response = client.table("sessions").select(
                    "id, session_id, script_title, created_at, duration_seconds, confidence_score"
                ).eq("user_id", user_id).order("created_at", desc=True).limit(limit).execute()
                if response.data:
                    logger.info(f"Found {len(response.data)} sessions (without detailed metrics)")
                    return response.data
            except Exception as fallback_error:
                logger.error(f"Sessions fallback also failed: {fallback_error}")
        logger.error(f"Sessions table error (may not exist): {e}")

    # Fallback: try features table
    try:
        # First try with analyzed_at and all metrics
        logger.info(f"Querying features table with user_id={user_id}")
        response = client.table("features").select(
            "session_id, analyzed_at, audio_duration, confidence_score, pitch_score, voice_quality_score, pace_score, fluency_score, transcription, user_id"
        ).eq("user_id", user_id).order("analyzed_at", desc=True).limit(limit).execute()

        data = response.data or []
        logger.info(f"Features with user_id filter: {len(data)} results")

        return [
            {
                "id": row.get("session_id"),
                "session_id": row.get("session_id"),
                "script_title": "Practice Session",
                "created_at": row.get("analyzed_at"),
                "duration_seconds": int(row.get("audio_duration") or 0),
                "confidence_score": row.get("confidence_score") or 0,
                "pitch_score": row.get("pitch_score") or 0,
                "voice_quality_score": row.get("voice_quality_score") or 0,
                "pace_score": row.get("pace_score") or 0,
                "fluency_score": row.get("fluency_score") or 0,
                "transcription": row.get("transcription") or "",
            }
            for row in data
        ]
    except Exception as e:
        error_message = str(e)
        logger.error(f"Failed to retrieve sessions from features table: {e}")

        # Fallback: if analyzed_at doesn't exist, try created_at
        if "analyzed_at" in error_message:
            try:
                logger.info("Retrying features query using created_at")
                response = client.table("features").select(
                    "session_id, created_at, audio_duration, confidence_score, pitch_score, voice_quality_score, pace_score, fluency_score, transcription, user_id"
                ).eq("user_id", user_id).order("created_at", desc=True).limit(limit).execute()

                data = response.data or []

                return [
                    {
                        "id": row.get("session_id"),
                        "session_id": row.get("session_id"),
                        "script_title": "Practice Session",
                        "created_at": row.get("created_at"),
                        "duration_seconds": int(row.get("audio_duration") or 0),
                        "confidence_score": row.get("confidence_score") or 0,
                        "pitch_score": row.get("pitch_score") or 0,
                        "voice_quality_score": row.get("voice_quality_score") or 0,
                        "pace_score": row.get("pace_score") or 0,
                        "fluency_score": row.get("fluency_score") or 0,
                        "transcription": row.get("transcription") or "",
                    }
                    for row in data
                ]
            except Exception as retry_error:
                logger.error(f"Retry with created_at failed: {retry_error}")

        return []


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


async def get_user_profile(user_id: str) -> Optional[dict[str, Any]]:
    """
    Retrieve user profile by user ID.
    
    Args:
        user_id: The Supabase auth user ID.
        
    Returns:
        The user profile if found, None otherwise.
    """
    client = get_supabase()
    
    try:
        response = client.table("user_profiles").select("*").eq(
            "id", user_id
        ).execute()
        
        if response.data:
            return response.data[0]
        return None
    except Exception as e:
        logger.error(f"Failed to retrieve user profile: {e}")
        raise


async def create_user_profile(user_id: str, profile_data: UpdateUserProfile) -> dict[str, Any]:
    """
    Create a new user profile.
    
    Args:
        user_id: The Supabase auth user ID.
        profile_data: The profile data to create.
        
    Returns:
        The created profile record.
    """
    client = get_supabase()
    
    record = {
        "id": user_id,
        "nickname": profile_data.nickname,
        "full_name": profile_data.full_name,
        "is_active": profile_data.is_active if profile_data.is_active is not None else True,
    }
    
    try:
        response = client.table("user_profiles").insert(record).execute()
        logger.info(f"Successfully created user profile for user {user_id}")
        return response.data[0] if response.data else record
    except Exception as e:
        logger.error(f"Failed to create user profile: {e}")
        raise


async def update_user_profile(user_id: str, profile_data: UpdateUserProfile) -> dict[str, Any]:
    """
    Update an existing user profile.
    
    Args:
        user_id: The Supabase auth user ID.
        profile_data: The profile data to update.
        
    Returns:
        The updated profile record.
    """
    client = get_supabase()
    
    # Build update dict with only provided fields
    update_data = {}
    if profile_data.nickname is not None:
        update_data["nickname"] = profile_data.nickname
    if profile_data.full_name is not None:
        update_data["full_name"] = profile_data.full_name
    if profile_data.is_active is not None:
        update_data["is_active"] = profile_data.is_active
    if profile_data.account_status is not None:
        update_data["account_status"] = profile_data.account_status
    
    try:
        response = client.table("user_profiles").update(update_data).eq(
            "id", user_id
        ).execute()
        logger.info(f"Successfully updated user profile for user {user_id}")
        return response.data[0] if response.data else update_data
    except Exception as e:
        logger.error(f"Failed to update user profile: {e}")
        raise
