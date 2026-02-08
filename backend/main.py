"""
Bigkas Backend API
FastAPI application for public speaking assessment.

This API receives audio files, analyzes them using signal processing
and machine learning, and stores the results in Supabase.
"""

import asyncio
import io
import logging
import os
import tempfile
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path
from typing import Annotated
from uuid import UUID, uuid4
from pydub import AudioSegment

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
)
from app.database import (
    get_supabase,
    insert_analysis_result,
    insert_session_record,
    get_analysis_by_session,
    check_connection,
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
    Defer Whisper model loading to first request to prevent startup timeout on HF Spaces.
    """
    logger.info("Starting Bigkas Backend...")
    logger.info("Whisper model will be loaded on first request (deferred loading)")
    
    # Check Supabase connection
    try:
        connected = await check_connection()
        if connected:
            logger.info("Supabase connection verified")
        else:
            logger.warning("Supabase connection could not be verified")
    except Exception as e:
        logger.error(f"Supabase connection error: {e}")
    
    logger.info("✓ Backend started successfully")
    
    yield
    
    logger.info("Shutting down Bigkas Backend...")


# Global lock to prevent concurrent audio processing (prevents CPU overload)
# Only one user's audio will be analyzed at a time
processing_lock = asyncio.Lock()

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


@app.post("/warmup", tags=["Health"])
async def warmup_model():
    """
    Warmup endpoint to pre-load Whisper model.
    
    Call this endpoint after the backend starts to pre-load the model.
    Takes 1-3 minutes on first call but only needs to be done once.
    """
    if WhisperTranscriber.is_loaded():
        return {
            "status": "already_loaded",
            "message": "Whisper model is already loaded",
            "timestamp": datetime.utcnow()
        }
    
    try:
        logger.info("Starting warmup: Loading Whisper model...")
        WhisperTranscriber.get_model()
        logger.info("✓ Warmup complete: Whisper model loaded successfully")
        return {
            "status": "loaded",
            "message": "Whisper model loaded successfully",
            "timestamp": datetime.utcnow()
        }
    except Exception as e:
        logger.error(f"Warmup failed: {e}")
        return {
            "status": "failed",
            "message": str(e),
            "timestamp": datetime.utcnow()
        }


@app.get("/debug/info", tags=["Debug"])
async def debug_info():
    """
    Get debug information about the backend configuration.
    Lightweight endpoint that doesn't add significant CPU load.
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
        "whisper_backend": "faster-whisper (CTranslate2)",
    }


# ============================================================================
# CORE AI ENDPOINT: AUDIO ANALYSIS (Whisper + Analysis Pipeline)
# This is the only CPU-intensive endpoint - everything else is in Flutter/Supabase
# ============================================================================

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
    # Use lock to prevent concurrent processing (prevents CPU overload when multiple users submit audio simultaneously)
    async with processing_lock:
        logger.info("🔒 Audio processing lock acquired - starting analysis...")
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
            
            logger.info("🔓 Audio processing lock released")
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


# ============================================================================
# ANALYSIS RETRIEVAL ENDPOINT
# ============================================================================

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


# ============================================================================
# EXCEPTION HANDLER
# ============================================================================

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


# ============================================================================
# JWT VERIFICATION (for analyze-audio endpoint)
# ============================================================================

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


# ============================================================================
# RECORDING STREAMING ENDPOINT (needed for web audio playback)
# ============================================================================

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
        
        # Convert WAV to MP3 for better browser compatibility
        # Browsers have limited WAV support, but all support MP3
        try:
            logger.info(f"Converting WAV to MP3 for playback ({len(file_data)} bytes)")
            audio = AudioSegment.from_wav(io.BytesIO(file_data))
            
            # Export as MP3 with good quality
            mp3_buffer = io.BytesIO()
            audio.export(mp3_buffer, format="mp3", bitrate="192k")
            mp3_buffer.seek(0)
            mp3_data = mp3_buffer.getvalue()
            
            logger.info(f"Conversion complete: {len(file_data)} bytes WAV -> {len(mp3_data)} bytes MP3")
            
            # Return MP3 stream
            return StreamingResponse(
                io.BytesIO(mp3_data),
                media_type="audio/mpeg",
                headers={
                    "Content-Disposition": f"inline; filename=recording_{session_id}.mp3",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type, Range",
                    "Accept-Ranges": "bytes",
                    "Cache-Control": "public, max-age=3600",
                    "Content-Type": "audio/mpeg"
                }
            )
        except Exception as conversion_error:
            # If conversion fails, fall back to WAV
            logger.warning(f"MP3 conversion failed: {conversion_error}. Falling back to WAV.")
            return StreamingResponse(
                io.BytesIO(file_data),
                media_type="audio/wav",
                headers={
                    "Content-Disposition": f"inline; filename=recording_{session_id}.wav",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type, Range",
                    "Accept-Ranges": "bytes",
                    "Cache-Control": "public, max-age=3600",
                    "Content-Type": "audio/wav"
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


# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=7860,
        reload=False,
        log_level="info"
    )
