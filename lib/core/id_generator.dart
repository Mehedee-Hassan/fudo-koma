import 'dart:math';

final _random = Random();

/// Short, sortable, collision-resistant enough for a single-device demo and
/// fine as a Firestore document id. Avoids pulling in `uuid` for one function.
String newId([String prefix = '']) {
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final noise = _random.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
  return prefix.isEmpty ? '$stamp$noise' : '$prefix-$stamp$noise';
}
