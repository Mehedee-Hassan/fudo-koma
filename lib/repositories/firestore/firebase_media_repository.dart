import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/id_generator.dart';
import '../media_repository.dart';

class FirebaseMediaRepository implements MediaRepository {
  FirebaseMediaRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadCartPhoto({
    required String cartId,
    required XFile file,
  }) async {
    final ref = _storage.ref('carts/$cartId/${newId()}.jpg');
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    if (kIsWeb) {
      // Web XFiles have no filesystem path; bytes are the only route.
      await ref.putData(await file.readAsBytes(), metadata);
    } else {
      await ref.putFile(File(file.path), metadata);
    }
    return ref.getDownloadURL();
  }

  @override
  Future<void> deleteCartPhoto(String reference) async {
    if (!reference.startsWith('http')) return;
    await _storage.refFromURL(reference).delete();
  }

  @override
  ImageProvider imageFor(String reference) => NetworkImage(reference);
}
