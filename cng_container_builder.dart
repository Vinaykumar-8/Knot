import 'dart:convert';
import 'cng_models.dart';

class CngContainerBuilder {
  static String buildContainer({
    required String originalFileName,
    required List<int> fileBytes,
    required ClassificationResult classification,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final extension = originalFileName.split('.').last;

    String payload;

    if (classification.category == FileCategory.programming) {
      final originalContent = utf8.decode(fileBytes, allowMalformed: true);

      payload = '''
      $originalContent
      ''';
    } else if (classification.category == FileCategory.executable ||
        classification.category == FileCategory.archive) {
      payload = base64Encode(fileByte);
    } else {
      payload = base64Encode(fileBytes);
    }

    return '''
    [CNG-CONTAINER v1]
    Original-Name: $originalFileName
    Original-Extension: $extension
    Category: ${classification.category.name}
    Risk-Level: ${classification.risklevel.name}
    Reason: ${classification.reason}
    Timestamp: $timestamp

    -----CNG-PAYLOAD-START-----
    $payload
    -----CNG-PAYLOAD-END-----
    ''';
  }
}
