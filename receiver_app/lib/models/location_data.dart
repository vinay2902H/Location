class LocationDataModel {
  final String id;
  final String? userId;
  final String username;
  final String email;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  LocationDataModel({
    required this.id,
    this.userId,
    this.username = 'Player_777',
    this.email = '',
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  factory LocationDataModel.fromJson(Map<String, dynamic> json) {
    return LocationDataModel(
      id: json['_id']?.toString() ?? 'X',
      userId: json['userId']?.toString(),
      username: json['username']?.toString() ?? 'Player_777',
      email: json['email']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      if (userId != null) 'userId': userId,
      'username': username,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class UserActivityModel {
  final String username;
  final String email;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  UserActivityModel({
    required this.username,
    required this.email,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  factory UserActivityModel.fromJson(Map<String, dynamic> json) {
    return UserActivityModel(
      username: json['username']?.toString() ?? 'Player_777',
      email: json['email']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
