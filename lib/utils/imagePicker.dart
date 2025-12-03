import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

/// Helper class para seleccionar imágenes desde galería o portapapeles
/// con soporte multiplataforma (móvil y escritorio)
class ImagePickerHelper {
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);


  /// Abre el selector de galería en móvil o file picker en escritorio
  /// y retorna el archivo de imagen seleccionado
  static Future<File?> imageFromGallery() async {
    if (isMobile) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      return picked != null ? File(picked.path) : null;
    }

    if (isDesktop) {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
    }

    return null;
  }


  /// Abre la cámara en móvil o lee el portapapeles en escritorio
  /// y retorna la imagen capturada o pegada
  static Future<File?> imageFromClipboard() async {
    if (isMobile) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);
      return picked != null ? File(picked.path) : null;
    }

    if (isDesktop) {
      return await _pasteImageClipboard();
    }

    return null;
  }

  /// Lee el contenido del portapapeles del sistema y busca imágenes
  /// en formato PNG o JPEG
  static Future<File?> _pasteImageClipboard() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return null;

    final reader = await clipboard.read();
    if (reader == null) return null;

    if (reader.canProvide(Formats.png)) {
      return await _processClipboard(reader, Formats.png, "png");
    }

    if (reader.canProvide(Formats.jpeg)) {
      return await _processClipboard(reader, Formats.jpeg, "jpg");
    }

    return null;
  }

  /// Procesa la imagen del portapapeles, lee el stream de bytes
  /// y guarda la imagen en un archivo temporal
  static Future<File?> _processClipboard(
      ClipboardReader reader,
      SimpleFileFormat format,
      String extension,
      ) async {
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

    await Future.delayed(const Duration(milliseconds: 80));

    return resultFile;
  }
}