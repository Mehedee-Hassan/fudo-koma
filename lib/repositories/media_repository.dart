import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

/// One interface over three very different storage strategies.
///
/// Takes `XFile`, not `File`: `image_picker` on web has no filesystem path, so
/// a `File` signature would make web uploads impossible before a line is written.
abstract class MediaRepository {
  /// Returns an opaque reference to store on the cart.
  Future<String> uploadCartPhoto({
    required String cartId,
    required XFile file,
  });

  Future<void> deleteCartPhoto(String reference);

  /// Resolves a reference for rendering. This is the pivot that lets every
  /// widget just write `Image(image: media.imageFor(ref))` regardless of backend.
  ImageProvider imageFor(String reference);
}
