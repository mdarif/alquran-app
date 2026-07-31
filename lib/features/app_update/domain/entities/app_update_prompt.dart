import 'package:equatable/equatable.dart';

class AppUpdatePrompt extends Equatable {
  const AppUpdatePrompt({
    required this.currentVersion,
    required this.latestVersion,
    required this.storeUrl,
    required this.message,
    this.required = false,
  });

  final String currentVersion;
  final String latestVersion;
  final Uri storeUrl;
  final String message;
  final bool required;

  @override
  List<Object?> get props => [
        currentVersion,
        latestVersion,
        storeUrl,
        message,
        required,
      ];
}
