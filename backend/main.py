"""
Bigkas Backend API
FastAPI application for public speaking assessment.

This API receives audio files, analyzes them using signal processing
and machine learning, and stores the results in Supabase.
"""

import logging
import os
import tempfile
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path
from typing import Annotated
from uuid import UUID, uuid4

from fastapi import FastAPI, File, UploadFile, HTTPException, status, Query, Header, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import jwt
from jwt.exceptions import InvalidTokenError

from app.config import get_settings
from app.models import (
    AnalysisResult,
    HealthResponse,
    ErrorResponse,
    UserProfile,
    UpdateUserProfile,
)
from app.database import (
    get_supabase,
    insert_analysis_result,
    insert_session_record,
    get_sessions,
    get_total_sessions_count,
    get_analysis_by_session,
    check_connection,
    get_user_profile,
    create_user_profile,
    update_user_profile,
    get_db_debug_info,
)
from app.analysis.pipeline import run_analysis_pipeline
from app.analysis.transcription import WhisperTranscriber

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan handler.
    Pre-loads Whisper model on startup.
    """
    logger.info("Starting Bigkas Backend...")
    
    # Pre-load Whisper model
    try:
        logger.info("Pre-loading Whisper model...")
        WhisperTranscriber.get_model()
        logger.info("Whisper model loaded successfully")
    except Exception as e:
        logger.error(f"Failed to load Whisper model: {e}")
    
    # Check Supabase connection
    try:
        connected = await check_connection()
        if connected:
            logger.info("Supabase connection verified")
        else:
            logger.warning("Supabase connection could not be verified")
    except Exception as e:
        logger.error(f"Supabase connection error: {e}")
    
    yield
    
    logger.info("Shutting down Bigkas Backend...")


# Initialize FastAPI app
app = FastAPI(
    title="Bigkas API",
    description="Public Speaking Assessment API - Analyzes voice recordings for speaking confidence metrics",
    version="1.0.0",
    lifespan=lifespan,
    responses={
        500: {"model": ErrorResponse, "description": "Internal Server Error"}
    }
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/", tags=["Root"])
async def root():
    """Root endpoint with API information."""
    return {
        "name": "Bigkas API",
        "version": "1.0.0",
        "description": "Public Speaking Assessment Tool",
        "docs_url": "/docs",
        "health_check": "/health"
    }


@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """
    Health check endpoint.
    
    Returns the status of the API and its dependencies.
    """
    supabase_connected = await check_connection()
    
    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow(),
        whisper_model_loaded=WhisperTranscriber.is_loaded(),
        supabase_connected=supabase_connected
    )


@app.get("/debug/info", tags=["Debug"])
async def debug_info():
    """
    Get debug information about the backend configuration.
    """
    import os
    
    return {
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat(),
        "environment": {
            "SUPABASE_URL": "configured" if os.getenv("SUPABASE_URL") else "missing",
            "SUPABASE_KEY": "configured" if os.getenv("SUPABASE_KEY") else "missing",
        },
        "whisper_loaded": WhisperTranscriber.is_loaded(),
        "supabase_connected": await check_connection()
    }


@app.get("/debug/session/{session_id}", tags=["Debug"])
async def debug_session(session_id: str):
    """
    Get debug info about a specific session.
    """
    try:
        db = get_supabase()
        
        # Try to fetch the session (NO AWAIT - db is sync)
        try:
            result = db.table("features").select("*").eq("session_id", session_id).single()
            session_data = result.data if result else None
        except Exception as e:
            session_data = None
            fetch_error = str(e)
        
        # Try to list storage buckets
        try:
            buckets = db.storage.list_buckets()
            bucket_list = [b.name if hasattr(b, 'name') else b.get('name', 'unknown') for b in buckets]
        except Exception as e:
            bucket_list = []
            bucket_error = str(e)
        
        # Try to find the recording file
        file_exists = False
        file_error = None
        if session_data and session_data.get("user_id"):
            try:
                file_path = f"{session_data['user_id']}/{session_id}.wav"
                # Try to get file metadata (lightweight check)
                db.storage.from_("recordings").download(file_path)
                file_exists = True
            except Exception as e:
                file_error = str(e)
        
        return {
            "status": "ok",
            "session_id": session_id,
            "session_found": session_data is not None,
            "session_user_id": session_data.get("user_id") if session_data else None,
            "storage_buckets": bucket_list,
            "recordings_bucket_exists": "recordings" in bucket_list,
            "file_exists": file_exists,
            "file_error": file_error,
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Debug session failed: {e}", exc_info=True)
        return {
            "status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }


@app.get("/debug/storage", tags=["Debug"])
async def debug_storage():
    """
    Debug endpoint to verify storage bucket exists and is accessible.
    """
    try:
        # Get the Supabase client (NOT async)
        db = get_supabase()
        
        # Try to access the storage object
        bucket_names = []
        recordings_exists = False
        files_in_bucket = []
        
        # Try to detect if recordings bucket exists by trying to list files
        try:
            files = db.storage.from_("recordings").list()
            if files is not None:  # If this succeeds, the bucket exists
                recordings_exists = True
                files_in_bucket = [f.get('name', 'unknown') for f in files] if isinstance(files, list) else []
                bucket_names = ["recordings"]
        except Exception as e:
            error_msg = str(e).lower()
            
            # If we get "not found" error, bucket doesn't exist
            if "not found" in error_msg or "404" in error_msg:
                recordings_exists = False
            else:
                # Other error, might be permission or actual error
                logger.warning(f"Could not check recordings bucket: {e}")
        
        return {
            "status": "connected",
            "buckets": bucket_names,
            "recordings_bucket_exists": recordings_exists,
            "files_in_recordings_bucket": files_in_bucket,
            "file_count": len(files_in_bucket),
            "timestamp": datetime.utcnow().isoformat(),
            "note": "bucket detection via file listing"
        }
    except Exception as e:
        logger.error(f"Storage debug failed: {e}", exc_info=True)
        return {
            "status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }


@app.get("/debug/test-recording/{session_id}", tags=["Debug"])
async def debug_test_recording(session_id: str):
    """
    Test endpoint to verify a specific recording file exists and is readable.
    """
    try:
        db = get_supabase()
        
        # Get session info first (NO AWAIT - db is sync)
        try:
            result = db.table("features").select("*").eq("session_id", session_id).single()
            session_data = result.data if result else None
        except:
            session_data = None
        
        if not session_data:
            return {
                "status": "error",
                "error": f"Session {session_id} not found in database",
                "session_found": False
            }
        
        user_id = session_data.get("user_id")
        
        # Try to access the file with different paths
        attempts = []
        
        # Attempt 1: {user_id}/{session_id}.wav
        if user_id:
            file_path = f"{user_id}/{session_id}.wav"
            try:
                data = db.storage.from_("recordings").download(file_path)
                attempts.append({
                    "path": file_path,
                    "status": "success",
                    "size_bytes": len(data)
                })
            except Exception as e:
                attempts.append({
                    "path": file_path,
                    "status": "failed",
                    "error": str(e)
                })
        
        # Attempt 2: {session_id}.wav
        file_path = f"{session_id}.wav"
        try:
            data = db.storage.from_("recordings").download(file_path)
            attempts.append({
                "path": file_path,
                "status": "success",
                "size_bytes": len(data)
            })
        except Exception as e:
            attempts.append({
                "path": file_path,
                "status": "failed",
                "error": str(e)
            })
        
        # List all files in recordings bucket
        files_in_bucket = []
        try:
            files = db.storage.from_("recordings").list()
            files_in_bucket = [f.get('name', 'unknown') for f in files] if files else []
        except Exception as e:
            logger.warning(f"Could not list files: {e}")
        
        return {
            "status": "ok",
            "session_id": session_id,
            "session_found": True,
            "user_id": user_id,
            "file_access_attempts": attempts,
            "files_in_bucket": files_in_bucket,
            "total_files": len(files_in_bucket),
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Test recording failed: {e}", exc_info=True)
        return {
            "status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }


@app.post(
    "/analyze-audio",
    response_model=AnalysisResult,
    status_code=status.HTTP_200_OK,
    tags=["Analysis"],
    responses={
        400: {"model": ErrorResponse, "description": "Invalid audio file"},
        413: {"model": ErrorResponse, "description": "File too large"},
        422: {"model": ErrorResponse, "description": "Unsupported audio format"},
        500: {"model": ErrorResponse, "description": "Analysis failed"}
    }
)
async def analyze_audio(
    audio: Annotated[UploadFile, File(description="Audio file (WAV or MP3)")],
    save_to_db: Annotated[bool, Query(description="Save results to database")] = True,
    authorization: Annotated[str, Header()] = "",
    script_title: Annotated[str | None, Form()] = None,
    script_content: Annotated[str | None, Form(description="Expected script content for accuracy comparison")] = None,
    recorded_duration: Annotated[int | None, Form(description="Recorded duration in seconds from the frontend")] = None
):
    """
    Analyze an audio recording for public speaking confidence metrics.
    
    This endpoint accepts an audio file and performs comprehensive analysis including:
    
    - **Transcription**: Converts speech to text using Whisper
    - **Acoustic Analysis**: Extracts pitch, jitter, shimmer, and HNR
    - **Fluency Analysis**: Calculates WPM and detects filler words
    - **Pause Detection**: Identifies and measures pauses in speech
    - **Confidence Scoring**: Generates an overall speaking confidence score
    
    **Supported Formats**: WAV, MP3
    
    **Maximum Duration**: 10 minutes
    
    Returns a complete analysis with all metrics and a confidence score (0-100).
    """
    settings = get_settings()
    
    # Validate content type (strip codecs like "audio/webm;codecs=opus")
    content_type = (audio.content_type or "").split(";")[0].strip()
    if content_type not in settings.allowed_audio_types:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unsupported audio format: {audio.content_type}. Allowed: {settings.allowed_audio_types}"
        )
    
    # Determine file extension
    if content_type in ["audio/mpeg", "audio/mp3"]:
        suffix = ".mp3"
    elif content_type in ["audio/webm", "audio/ogg"]:
        suffix = ".webm"
    else:
        suffix = ".wav"
    
    temp_path: Path | None = None
    wav_path: Path | None = None
    
    try:
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
            content = await audio.read()
            temp_file.write(content)
            temp_path = Path(temp_file.name)
        
        logger.info(f"Received audio file: {audio.filename}, size: {len(content)} bytes, content_type: {content_type}")
        
        if len(content) < 1024:
            logger.warning(f"Audio file is suspiciously small: {len(content)} bytes")
        
        # Run analysis pipeline - returns result and path to converted WAV
        result, wav_path = await run_analysis_pipeline(temp_path, script_content=script_content)
        
        # Override audio_duration with frontend recorded_duration if provided
        if recorded_duration is not None and recorded_duration > 0:
            logger.info(f"Using frontend recorded_duration ({recorded_duration}s) instead of librosa duration ({result.audio_duration:.1f}s)")
            result = AnalysisResult(
                session_id=result.session_id,
                transcription=result.transcription,
                audio_duration=float(recorded_duration),
                audio_metrics=result.audio_metrics,
                fluency_metrics=result.fluency_metrics,
                pause_metrics=result.pause_metrics,
                confidence_score=result.confidence_score,
                analyzed_at=result.analyzed_at
            )
        
        # Validate duration
        if result.audio_duration > settings.max_audio_duration_seconds:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Audio duration ({result.audio_duration:.1f}s) exceeds maximum allowed ({settings.max_audio_duration_seconds}s)"
            )
        
        # Save to database if requested
        if save_to_db:
            try:
                user_id = None
                if authorization:
                    try:
                        user_id = verify_jwt_token(authorization)
                        logger.info(f"Successfully verified JWT token, user_id: {user_id}")
                    except Exception as e:
                        logger.warning(f"JWT token verification failed: {e}")
                        user_id = None
                else:
                    logger.warning("No authorization header provided")

                await insert_analysis_result(result, user_id=user_id)
                await insert_session_record(result, user_id=user_id, script_title=script_title)
                logger.info(f"Analysis result saved to database: {result.session_id}")
                
                # Save recording to Supabase Storage for web playback
                # This allows web clients to listen to their recordings
                # Use the converted WAV file (not the original webm) for proper playback
                upload_path = wav_path if wav_path and wav_path.exists() else temp_path
                logger.info(f"Attempting to upload recording: user_id={user_id}, upload_path={upload_path}, exists={upload_path and upload_path.exists()}")
                if upload_path and upload_path.exists():
                    try:
                        db = get_supabase()
                        storage = db.storage
                        
                        # Use user_id if available, otherwise use session_id
                        if user_id:
                            file_path = f"{user_id}/{result.session_id}.wav"
                        else:
                            file_path = f"{result.session_id}.wav"
                        
                        with open(upload_path, 'rb') as f:
                            file_data = f.read()
                        
                        logger.info(f"Uploading recording to storage: {file_path} (size: {len(file_data)} bytes, from: {upload_path.name})")
                        
                        # Upload to storage
                        response = storage.from_("recordings").upload(
                            file_path,
                            file_data,
                            {"cacheControl": "3600", "upsert": "true"}
                        )
                        logger.info(f"Recording uploaded successfully: {file_path}")
                    except Exception as e:
                        # Don't fail the request if storage upload fails
                        logger.error(f"Failed to save recording to storage: {e}", exc_info=True)
                else:
                    logger.warning(f"Cannot upload recording: upload_path={upload_path}, exists={upload_path and upload_path.exists() if upload_path else False}")
            except Exception as e:
                logger.error(f"Failed to save to database: {e}")
                # Don't fail the request, just log the error
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Analysis failed: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Analysis failed: {str(e)}"
        )
    finally:
        # Clean up temporary files
        if temp_path and temp_path.exists():
            try:
                os.remove(temp_path)
            except Exception as e:
                logger.warning(f"Failed to clean up temp file: {e}")
        
        # Clean up WAV file if it was created (different from original)
        if wav_path and wav_path != temp_path and wav_path.exists():
            try:
                os.remove(wav_path)
            except Exception as e:
                logger.warning(f"Failed to clean up WAV file: {e}")


@app.get(
    "/sessions",
    response_model=list,
    tags=["Sessions"],
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"}
    }
)
async def list_sessions(
    authorization: Annotated[str, Header()] = "",
    limit: Annotated[int, Query(description="Max number of sessions")] = 20
):
    """
    Return recent session summaries for the authenticated user.
    """
    user_id = verify_jwt_token(authorization)

    try:
        sessions = await get_sessions(user_id=user_id, limit=limit)
        return sessions
    except Exception as e:
        logger.error(f"Failed to retrieve sessions: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve sessions: {str(e)}"
        )


@app.get(
    "/sessions/count",
    response_model=dict,
    tags=["Sessions"],
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"}
    }
)
async def get_sessions_count(
    authorization: Annotated[str, Header()] = "",
):
    """
    Return total session count for the authenticated user.
    """
    user_id = verify_jwt_token(authorization)

    try:
        count = await get_total_sessions_count(user_id=user_id)
        return {"total": count}
    except Exception as e:
        logger.error(f"Failed to retrieve sessions count: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve sessions count: {str(e)}"
        )


@app.get(
    "/analysis/{session_id}",
    response_model=dict,
    tags=["Analysis"],
    responses={
        404: {"model": ErrorResponse, "description": "Session not found"}
    }
)
async def get_analysis(session_id: UUID):
    """
    Retrieve a previous analysis result by session ID.
    
    Args:
        session_id: The UUID of the analysis session to retrieve.
        
    Returns:
        The stored analysis record.
    """
    try:
        result = await get_analysis_by_session(session_id)
        
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Analysis session {session_id} not found"
            )
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to retrieve analysis: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve analysis: {str(e)}"
        )


@app.get(
    "/debug/db-stats",
    response_model=dict,
    tags=["Debug"],
)
async def debug_db_stats():
    """
    Return basic DB stats for features and sessions.
    """
    try:
        return await get_db_debug_info()
    except Exception as e:
        logger.error(f"Failed to retrieve debug stats: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve debug stats: {str(e)}",
        )


@app.post(
    "/debug/insert-test",
    response_model=dict,
    tags=["Debug"],
)
async def debug_insert_test():
    """
    Try inserting a minimal feature row to validate DB writes.
    """
    client = get_supabase()
    test_id = str(uuid4())
    record = {
        "session_id": test_id,
        "confidence_score": 50,
        "audio_duration": 10,
    }
    try:
        response = client.table("features").insert(record).execute()
        return {
            "ok": True,
            "record": record,
            "data": response.data,
            "error": str(getattr(response, "error", None)),
        }
    except Exception as e:
        return {"ok": False, "error": str(e), "record": record}

@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler for unhandled errors."""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "Internal Server Error",
            "detail": str(exc),
            "timestamp": datetime.utcnow().isoformat()
        }
    )


def verify_jwt_token(authorization: str) -> str:
    """
    Verify JWT token from Authorization header and extract user ID.
    
    Args:
        authorization: The Authorization header value (Bearer <token>)
        
    Returns:
        The user ID from the token.
        
    Raises:
        HTTPException: If token is invalid or missing.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authorization header"
        )
    
    token = authorization.replace("Bearer ", "")
    settings = get_settings()
    
    try:
        # Decode JWT token (Supabase uses HS256 by default)
        # Note: In production, you should verify the signature with Supabase JWT secret
        payload = jwt.decode(
            token,
            options={"verify_signature": False}  # For development; verify in production
        )
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: missing user ID"
            )
        return user_id
    except InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}"
        )


@app.get(
    "/profile",
    response_model=dict,
    tags=["User Profile"],
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        404: {"model": ErrorResponse, "description": "Profile not found"}
    }
)
async def get_profile(
    authorization: Annotated[str, Header()] = ""
):
    """
    Get the current user's profile.
    
    Requires authentication via Bearer token in Authorization header.
    """
    user_id = verify_jwt_token(authorization)
    
    try:
        profile = await get_user_profile(user_id)
        
        if profile is None:
            # Profile doesn't exist yet, return empty profile
            return {
                "id": user_id,
                "nickname": None,
                "full_name": None,
                "is_active": True,
                "has_profile": False
            }
        
        return {
            **profile,
            "has_profile": True
        }
    except Exception as e:
        logger.error(f"Failed to retrieve profile: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve profile: {str(e)}"
        )


@app.put(
    "/profile",
    response_model=dict,
    tags=["User Profile"],
    responses={
        401: {"model": ErrorResponse, "description": "Unauthorized"},
        400: {"model": ErrorResponse, "description": "Invalid profile data"}
    }
)
async def update_profile(
    profile_data: UpdateUserProfile,
    authorization: Annotated[str, Header()] = ""
):
    """
    Create or update the current user's profile.
    
    Requires authentication via Bearer token in Authorization header.
    """
    user_id = verify_jwt_token(authorization)
    
    try:
        # Check if profile exists
        existing_profile = await get_user_profile(user_id)
        
        if existing_profile is None:
            # Create new profile
            profile = await create_user_profile(user_id, profile_data)
        else:
            # Update existing profile
            profile = await update_user_profile(user_id, profile_data)
        
        return {
            **profile,
            "has_profile": True
        }
    except Exception as e:
        logger.error(f"Failed to update profile: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update profile: {str(e)}"
        )


@app.get(
    "/sessions/{session_id}/recording",
    tags=["Recordings"],
    responses={
        404: {"model": ErrorResponse, "description": "Recording not found"},
        401: {"model": ErrorResponse, "description": "Unauthorized"}
    }
)
async def get_session_recording(
    session_id: str,
    authorization: Annotated[str, Header()] = ""
):
    """
    Retrieve the audio recording for a completed analysis session.
    
    This endpoint allows users to listen to their recorded speech.
    Recordings are available for 14 days after analysis.
    
    **Note:** For web clients, this endpoint streams the audio file directly.
    For native clients, audio is stored locally in cache.
    
    Returns the audio file with appropriate Content-Type header.
    """
    from fastapi.responses import StreamingResponse
    import io
    
    try:
        # Verify authentication
        user_id = None
        if authorization:
            try:
                user_id = verify_jwt_token(authorization)
            except Exception as e:
                logger.warning(f"Token verification failed: {e}")
                # Don't fail on token error for recordings - allow anon access
                pass
        
        # Get analysis result to verify session exists
        db = get_supabase()
        session_data = None
        session_user_id = None
        
        try:
            result = db.table("features").select("*").eq("session_id", session_id).single()
            session_data = result.data if result else None
            session_user_id = session_data.get("user_id") if session_data else None
            logger.info(f"Found session in database: {session_id}, user_id: {session_user_id}")
        except Exception as e:
            logger.warning(f"Could not fetch session from database: {e}")
            session_data = None
            session_user_id = None
        
        # Note: We don't require session to be in database
        # The file might exist even if session wasn't saved (e.g., from old API version)
        logger.info(f"Retrieving recording for session: {session_id}, user: {user_id}, session_user: {session_user_id}")
        
        # Verify user has access to this recording (if user_id is provided)
        if user_id and session_user_id and str(session_user_id) != str(user_id):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="You do not have access to this recording"
            )
        if user_id and session_user_id and str(session_user_id) != str(user_id):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="You do not have access to this recording"
            )
        
        logger.info(f"Retrieving recording for session: {session_id}, user: {user_id}, session_user: {session_user_id}")
        
        # Try to get recording from Supabase Storage
        file_data = None
        storage = db.storage
        
        # Try with user_id prefix first
        if session_user_id:
            try:
                file_path = f"{session_user_id}/{session_id}.wav"
                logger.info(f"Attempting to download: {file_path}")
                file_data = storage.from_("recordings").download(file_path)
                logger.info(f"Successfully downloaded recording ({len(file_data)} bytes)")
            except Exception as e:
                logger.warning(f"Failed to download with user_id: {e}")
        
        # Try without user_id prefix (fallback)
        if file_data is None:
            try:
                file_path = f"{session_id}.wav"
                logger.info(f"Trying fallback: {file_path}")
                file_data = storage.from_("recordings").download(file_path)
                logger.info(f"Successfully downloaded recording via fallback ({len(file_data)} bytes)")
            except Exception as e:
                logger.warning(f"Fallback also failed: {e}")
        
        # Try looking in subdirectories (legacy format: parent_dir/session_id.wav)
        # This handles cases where files are stored in user_id or other parent folders
        if file_data is None:
            try:
                # First, try to list all items in recordings bucket
                all_items = storage.from_("recordings").list()
                logger.info(f"Searching for {session_id}.wav in subdirectories. Found {len(all_items)} items at root")
                
                for item in all_items:
                    if item.get("metadata") is None:  # It's a folder
                        folder_name = item["name"]
                        try:
                            file_path = f"{folder_name}/{session_id}.wav"
                            logger.info(f"Trying subfolder path: {file_path}")
                            file_data = storage.from_("recordings").download(file_path)
                            logger.info(f"Successfully found recording in subfolder ({len(file_data)} bytes)")
                            break
                        except Exception as e:
                            logger.debug(f"Not in {folder_name}: {str(e)[:50]}")
                            continue
            except Exception as e:
                logger.warning(f"Subfolder search failed: {e}")
        
        # If still no data, check if this is a test/development scenario
        if file_data is None:
            logger.error(f"Recording not found in storage for session: {session_id}")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Recording file not found. Make sure the 'recordings' bucket exists in Supabase Storage."
            )
        
        # Return audio stream
        return StreamingResponse(
            io.BytesIO(file_data),
            media_type="audio/wav",
            headers={
                "Content-Disposition": f"inline; filename=recording_{session_id}.wav",
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": "public, max-age=3600"
            }
        )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to retrieve recording: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve recording: {str(e)}"
        )


@app.delete(
    "/user/clear-data",
    tags=["User"],
    responses={
        200: {"description": "User data cleared successfully"},
        401: {"model": ErrorResponse, "description": "Unauthorized"}
    }
)
async def clear_user_data(
    authorization: Annotated[str, Header()] = ""
):
    """
    Clear all recordings for the authenticated user.
    
    This will:
    - Delete all recordings from storage
    
    NOTE: Session records in the database are preserved to maintain
    the user's streak and progress history. Only the audio files
    are removed to free up storage space.
    """
    user_id = verify_jwt_token(authorization)
    
    db = get_supabase()
    storage = db.storage
    
    deleted_files = 0
    errors = []
    
    try:
        # Delete recordings from storage only
        # Session records are preserved for streak calculation
        try:
            # List files in user's folder
            files = storage.from_("recordings").list(user_id)
            logger.info(f"Found {len(files)} files in user folder: {user_id}")
            
            for file_info in files:
                file_name = file_info.get("name")
                if file_name:
                    try:
                        file_path = f"{user_id}/{file_name}"
                        storage.from_("recordings").remove([file_path])
                        deleted_files += 1
                        logger.info(f"Deleted recording: {file_path}")
                    except Exception as e:
                        errors.append(f"Failed to delete {file_name}: {str(e)}")
                        logger.warning(f"Failed to delete recording {file_name}: {e}")
        except Exception as e:
            errors.append(f"Failed to list recordings: {str(e)}")
            logger.warning(f"Failed to list recordings for user {user_id}: {e}")
        
        # Session records are NOT deleted - they are needed for:
        # - Streak calculation (based on session dates)
        # - Progress tracking and analytics
        # - Historical performance data
        
        return {
            "success": True,
            "deleted_files": deleted_files,
            "message": "Recordings cleared. Your streak and session history are preserved.",
            "errors": errors if errors else None
        }
        
    except Exception as e:
        logger.error(f"Failed to clear user data: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to clear user data: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info"
    )
