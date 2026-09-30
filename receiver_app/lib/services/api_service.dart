import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/location_data.dart';

class ApiException implements Exception {
  final String message;
  final bool isNetworkError;
  final bool isNotFound;

  ApiException(this.message, {this.isNetworkError = false, this.isNotFound = false});

  @override
  String toString() => message;
}

class ApiService {
  /// Fetch latest location
  /// GET /api/location
  static Future<LocationDataModel> fetchLatestLocation({String? username, String? id}) async {
    var uri = Uri.parse(AppConfig.locationApiUrl);
    if (username != null && username.isNotEmpty) {
      uri = uri.replace(queryParameters: {'username': username});
    } else if (id != null && id.isNotEmpty) {
      uri = uri.replace(queryParameters: {'id': id});
    }

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return LocationDataModel.fromJson(data);
      } else if (response.statusCode == 404) {
        throw ApiException(
          'No location available yet. Waiting for sender to share location.',
          isNotFound: true,
        );
      } else {
        throw ApiException('Server error: HTTP ${response.statusCode}');
      }
    } on SocketException catch (_) {
      throw ApiException('Unable to connect to server.', isNetworkError: true);
    } on TimeoutException catch (_) {
      throw ApiException('Connection timed out.', isNetworkError: true);
    } on http.ClientException catch (_) {
      throw ApiException('Unable to connect to server.', isNetworkError: true);
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('[ApiService] Unexpected error: $e');
      throw ApiException('Failed to fetch location: $e');
    }
  }

  /// Fetch all active shared locations in DB
  /// GET /api/locations
  static Future<List<LocationDataModel>> fetchAllLocations() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/locations');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((e) => LocationDataModel.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] fetchAllLocations error: $e');
      return [];
    }
  }

  /// Fetch all user activity history logs stored in MongoDB
  /// GET /api/user-activity
  static Future<List<UserActivityModel>> fetchUserActivities({String? username, int limit = 50}) async {
    var uri = Uri.parse('${AppConfig.baseUrl}/api/user-activity');
    final query = <String, String>{'limit': limit.toString()};
    if (username != null && username.isNotEmpty) {
      query['username'] = username;
    }
    uri = uri.replace(queryParameters: query);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final list = data['activities'] as List?;
        if (list != null) {
          return list.map((item) => UserActivityModel.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[ApiService] fetchUserActivities error: $e');
      return [];
    }
  }

  /// Ping the backend to check connectivity
  /// GET /api/health
  static Future<bool> checkHealth() async {
    try {
      final url = Uri.parse(AppConfig.healthApiUrl);
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Username-only login/registration
  /// POST /api/auth/username-login
  static Future<Map<String, dynamic>> loginWithUsername(String username) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/username-login');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username.trim()}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        try {
          final err = jsonDecode(response.body);
          throw ApiException(err['error']?.toString() ?? 'Login failed');
        } catch (e) {
          if (e is ApiException) rethrow;
          throw ApiException('Login failed with status ${response.statusCode}');
        }
      }
    } on SocketException catch (_) {
      throw ApiException('Unable to connect to server.', isNetworkError: true);
    } on TimeoutException catch (_) {
      throw ApiException('Connection timed out.', isNetworkError: true);
    } on http.ClientException catch (_) {
      throw ApiException('Network error connecting to server.', isNetworkError: true);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Authentication error: $e');
    }
  }
}
