import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

class ImagePickerHelper {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Selecciona una imagen desde la cámara (móvil) o portapapeles (escritorio)
  static Future<File?> seleccionarImagen() async {
    if (isMobile) {
      return await _seleccionarImagenMovil();
    } else if (isDesktop) {
      return await _pegarImagenPortapapeles();
    }
    return null;
  }

  static Future<File?> _seleccionarImagenMovil() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint('Error al seleccionar imagen móvil: $e');
    }
    return null;
  }

  static Future<File?> _pegarImagenPortapapeles() async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) return null;

      final reader = await clipboard.read();
      if (reader == null) return null;

      // Intenta PNG primero, luego JPEG
      if (reader.canProvide(Formats.png)) {
        return await _procesarImagenPortapapeles(reader, Formats.png, 'png');
      } else if (reader.canProvide(Formats.jpeg)) {
        return await _procesarImagenPortapapeles(reader, Formats.jpeg, 'jpg');
      }
    } catch (e) {
      debugPrint('Error al pegar imagen del portapapeles: $e');
    }
    return null;
  }

  static Future<File?> _procesarImagenPortapapeles(
      ClipboardReader reader,
      SimpleFileFormat format,
      String extension,
      ) async {
    try {
      File? resultFile;

      reader.getFile(format, (file) async {
        final stream = file.getStream();
        final chunks = <int>[];

        await for (final chunk in stream) {
          chunks.addAll(chunk);
        }

        final imageBytes = Uint8List.fromList(chunks);
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/clipboard_image_${DateTime.now().millisecondsSinceEpoch}.$extension',
        );

        await tempFile.writeAsBytes(imageBytes);
        resultFile = tempFile;
      });

      // Espera un momento para que el callback termine
      await Future.delayed(Duration(milliseconds: 100));
      return resultFile;
    } catch (e) {
      debugPrint('Error al procesar imagen del portapapeles: $e');
      return null;
    }
  }
}