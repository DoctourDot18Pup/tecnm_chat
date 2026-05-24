import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:tecnm_chat/core/constants/app_constants.dart';

class CloudinaryService {
  static const _uploadUrl = AppConstants.cloudinaryBaseUrl;
  static const _uploadPreset = AppConstants.cloudinaryUploadPreset;

  Future<String> uploadFile(File file, String folder) async {
    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
    request.fields['upload_preset'] = _uploadPreset;
    request.fields['folder'] = folder;
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw Exception(
        'El tiempo de subida ha expirado. Verifica tu conexión a internet.',
      ),
    );

    final responseBody = await streamedResponse.stream.bytesToString();
    final jsonData = json.decode(responseBody) as Map<String, dynamic>;

    if (streamedResponse.statusCode == 200) {
      final secureUrl = jsonData['secure_url'] as String?;
      if (secureUrl == null || secureUrl.isEmpty) {
        throw Exception('Cloudinary no devolvió una URL válida.');
      }
      return secureUrl;
    } else {
      final errorMsg = (jsonData['error'] as Map?)?['message'] as String? ??
          'Error desconocido al subir el archivo.';
      throw Exception('Error al subir el archivo: $errorMsg');
    }
  }
}
