import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/analysis_model.dart';
import 'supabase_service.dart';

/// Exception thrown when API calls fail
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() =>
      'ApiException: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// Service for communicating with the Python FastAPI backend
/// OPTIMIZED: Now focuses only on AI operations (audio analysis with Whisper)
/// For profile, sessions, and data management, use SupabaseService directly
class ApiService {
  // Base URL for the FastAPI backend
  // Production: Hugging Face Spaces deployment
  static const String baseUrl = 'https://kidlatpogi17-bigkas-backend.hf.space';

  // For local development, uncomment this instead:
  // static const String baseUrl = 'http://localhost:8000';

  // For Android emulator, uncomment this instead:
  // static const String baseUrl = 'http://10.0.2.2:8000';

  // HTTP client with timeout configuration
  final http.Client _client;
  final SupabaseService _supabaseService = SupabaseService();

  // Request timeout duration (increased for Hugging Face Spaces cold starts + Whisper loading)
  static const Duration _timeout = Duration(seconds: 300); // 5 minutes for cold starts

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<void> _ensureFreshSession({bool forceRefresh = false}) async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) return;

    // On web implicit flow, refresh token may be missing
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return;

    if (forceRefresh) {
      try {
        await supabase.auth.refreshSession();
      } catch (e) {
      }
      return;
    }

    final expiresAt = session.expiresAt;
    if (expiresAt == null) return;

    final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    final now = DateTime.now().toUtc();
    if (now.isAfter(expiry.subtract(const Duration(minutes: 1)))) {
      try {
        await supabase.auth.refreshSession();
      } catch (e) {
      }
    }
  }

  /// Get the current JWT access token from Supabase session
  String? get _accessToken =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  /// Build headers for API requests
  Map<String, String> _buildHeaders({bool includeAuth = true}) {
    final headers = <String, String>{'Accept': 'application/json'};

    // Add auth token if available and requested
    if (includeAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    return headers;
  }

  /// Upload audio file to the backend for analysis
  ///
  /// Sends the audio file to POST /analyze-audio endpoint
  /// Returns [AnalysisModel] with the analysis results
  ///
  /// Throws [ApiException] on failure
  Future<AnalysisModel> uploadAudio(
    File audioFile, {
    String? scriptTitle,
    String? scriptContent,
    int? recordedDurationSeconds,
  }) async {
    await _ensureFreshSession();
    final uri = Uri.parse('$baseUrl/analyze-audio');

    try {
      // Create multipart request
      final request = http.MultipartRequest('POST', uri);

      // Add authentication header if logged in
      request.headers.addAll(_buildHeaders());

      // Determine content type based on file extension
      final extension = audioFile.path.split('.').last.toLowerCase();
      String contentType;
      switch (extension) {
        case 'mp3':
          contentType = 'audio/mpeg';
          break;
        case 'wav':
          contentType = 'audio/wav';
          break;
        case 'm4a':
          contentType = 'audio/m4a';
          break;
        default:
          contentType = 'audio/wav'; // Default to wav
      }

      // Add the audio file to the request
      final multipartFile = await http.MultipartFile.fromPath(
        'audio', // Field name expected by FastAPI
        audioFile.path,
        contentType: http.MediaType.parse(contentType),
      );
      request.files.add(multipartFile);

      if (scriptTitle != null && scriptTitle.trim().isNotEmpty) {
        request.fields['script_title'] = scriptTitle.trim();
      }

      if (scriptContent != null && scriptContent.trim().isNotEmpty) {
        request.fields['script_content'] = scriptContent.trim();
      }

      if (recordedDurationSeconds != null && recordedDurationSeconds > 0) {
        request.fields['recorded_duration'] = recordedDurationSeconds
            .toString();
      }

      // Send request with timeout
      final streamedResponse = await request.send().timeout(_timeout);

      // Get response body
      final response = await http.Response.fromStream(streamedResponse);

      // Handle response
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return AnalysisModel.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw ApiException(
          'Unauthorized. Please sign in again.',
          statusCode: response.statusCode,
          body: response.body,
        );
      } else if (response.statusCode == 413) {
        throw ApiException(
          'Audio file is too large. Please use a shorter recording.',
          statusCode: response.statusCode,
          body: response.body,
        );
      } else if (response.statusCode == 422) {
        throw ApiException(
          'Unsupported audio format. Please use WAV or MP3.',
          statusCode: response.statusCode,
          body: response.body,
        );
      } else {
        // Parse error message from backend if available
        String errorMessage = 'Analysis failed';
        try {
          final errorJson = json.decode(response.body);
          errorMessage =
              errorJson['detail'] ?? errorJson['error'] ?? errorMessage;
        } catch (_) {}

        throw ApiException(
          errorMessage,
          statusCode: response.statusCode,
          body: response.body,
        );
      }
    } on SocketException {
      throw ApiException(
        'Cannot connect to server. Please check your internet connection and ensure the backend is running.',
        statusCode: 0,
      );
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', statusCode: 0);
    } on FormatException {
      throw ApiException('Invalid response from server', statusCode: 0);
    } on ApiException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw ApiException(
          'Request timed out. The audio file might be too long to process.',
          statusCode: 0,
        );
      }
      throw ApiException('Unexpected error: ${e.toString()}');
    }
  }

  /// Upload audio bytes to the backend (web)
  Future<AnalysisModel> uploadAudioBytes(
    Uint8List bytes, {
    String fileName = 'recording.wav',
    String contentType = 'audio/wav',
    String? scriptTitle,
    String? scriptContent,
    int? recordedDurationSeconds,
  }) async {
    await _ensureFreshSession();
    final uri = Uri.parse('$baseUrl/analyze-audio');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(_buildHeaders());

      final multipartFile = http.MultipartFile.fromBytes(
        'audio',
        bytes,
        filename: fileName,
        contentType: http.MediaType.parse(contentType),
      );
      request.files.add(multipartFile);

      if (scriptTitle != null && scriptTitle.trim().isNotEmpty) {
        request.fields['script_title'] = scriptTitle.trim();
      }

      if (scriptContent != null && scriptContent.trim().isNotEmpty) {
        request.fields['script_content'] = scriptContent.trim();
      }

      if (recordedDurationSeconds != null && recordedDurationSeconds > 0) {
        request.fields['recorded_duration'] = recordedDurationSeconds
            .toString();
      }

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return AnalysisModel.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw ApiException(
          'Unauthorized. Please sign in again.',
          statusCode: response.statusCode,
          body: response.body,
        );
      } else if (response.statusCode == 413) {
        throw ApiException(
          'Audio file is too large. Please use a shorter recording.',
          statusCode: response.statusCode,
          body: response.body,
        );
      } else if (response.statusCode == 422) {
        throw ApiException(
          'Unsupported audio format. Please use WAV or MP3.',
          statusCode: response.statusCode,
          body: response.body,
        );
      } else {
        String errorMessage = 'Analysis failed';
        try {
          final errorJson = json.decode(response.body);
          errorMessage =
              errorJson['detail'] ?? errorJson['error'] ?? errorMessage;
        } catch (_) {}

        throw ApiException(
          errorMessage,
          statusCode: response.statusCode,
          body: response.body,
        );
      }
    } on SocketException {
      throw ApiException(
        'Cannot connect to server. Please check your internet connection and ensure the backend is running.',
        statusCode: 0,
      );
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', statusCode: 0);
    } on FormatException {
      throw ApiException('Invalid response from server', statusCode: 0);
    } on ApiException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw ApiException(
          'Request timed out. The audio file might be too long to process.',
          statusCode: 0,
        );
      }
      throw ApiException('Unexpected error: ${e.toString()}');
    }
  }

  /// Fetch a previous analysis result by session ID
  Future<AnalysisModel> getAnalysis(String sessionId) async {
    await _ensureFreshSession();
    final uri = Uri.parse('$baseUrl/analysis/$sessionId');

    try {
      final response = await _client
          .get(uri, headers: _buildHeaders())
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return AnalysisModel.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw ApiException(
          'Analysis not found',
          statusCode: response.statusCode,
        );
      } else {
        throw ApiException(
          'Failed to fetch analysis',
          statusCode: response.statusCode,
          body: response.body,
        );
      }
    } on SocketException {
      throw ApiException('Cannot connect to server', statusCode: 0);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Unexpected error: ${e.toString()}');
    }
  }

  /// Check if the backend server is reachable
  Future<bool> healthCheck() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Fetch recent sessions for the current user
  /// OPTIMIZED: Now uses direct Supabase queries to reduce backend load
  Future<List<Map<String, dynamic>>> getSessions({int limit = 20}) async {
    return await _supabaseService.getSessions(limit: limit);
  }

  /// Get total sessions count for the current user
  /// OPTIMIZED: Now uses direct Supabase queries to reduce backend load
  Future<int> getTotalSessionsCount() async {
    return await _supabaseService.getTotalSessionsCount();
  }

  /// Clear all recordings and session data for the current user
  /// OPTIMIZED: Now uses direct Supabase queries to reduce backend load
  Future<Map<String, dynamic>> clearUserData() async {
    return await _supabaseService.clearUserData();
  }

  /// Dispose the HTTP client when no longer needed
  void dispose() {
    _client.close();
  }
}
