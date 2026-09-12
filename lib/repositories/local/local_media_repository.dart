import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/app_exception.dart';
import '../../core/id_generator.dart';
import '../media_repository.dart';

class LocalMediaRepository implements MediaRepository {
  LocalMediaRepository();

  /// Web has no filesystem, so photos become inline data URIs. Deliberately
  /// capped - this is a demo affordance, not a storage strategy.
  static const int _maxWebBytes = 200 * 1024;

  Directory? _docsDir;

  Future<Directory> _documents() async =>
      _docsDir ??= await getApplicationDocumentsDirectory();

  @override
  Future<String> uploadCartPhoto({
    required String cartId,
    required XFile file,
  }) async {
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxWebBytes) {
        throw const RepositoryException(
          'That image is too large for the web demo. Try a smaller photo, or '
          'run the app on a device.',
        );
      }
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    final docs = await _documents();
    final relative = 'cart_photos/$cartId/${newId()}.jpg';
    final target = File('${docs.path}/$relative');
    await target.parent.create(recursive: true);
    await file.saveTo(target.path);

    // Store the RELATIVE path. On iOS the app container UUID changes across
    // reinstalls and some updates, so an absolute path silently rots and every
    // photo turns into a broken image. Resolved against the current docs dir
    // at read time instead.
    return relative;
  }

  @override
  Future<void> deleteCartPhoto(String reference) async {
    if (kIsWeb || reference.startsWith('data:')) return;
    final docs = await _documents();
    final file = File('${docs.path}/$reference');
    if (file.existsSync()) await file.delete();
  }

  @override
  ImageProvider imageFor(String reference) {
    if (reference.startsWith('data:')) {
      final payload = reference.substring(reference.indexOf(',') + 1);
      return MemoryImage(base64Decode(payload));
    }
    if (reference.startsWith('http://') || reference.startsWith('https://')) {
      return NetworkImage(reference);
    }
    final dir = _docsDir;
    if (dir == null) {
      // _documents() has not been awaited yet in this session; the widget
      // rebuilds once a photo is added, and prefetch() warms it at startup.
      return MemoryImage(_transparentPixel);
    }
    return FileImage(File('${dir.path}/$reference'));
  }

  /// Warms the documents directory so `imageFor` is synchronous from first paint.
  Future<void> prefetch() async {
    if (kIsWeb) return;
    await _documents();
  }

  static final Uint8List _transparentPixel = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);
}
