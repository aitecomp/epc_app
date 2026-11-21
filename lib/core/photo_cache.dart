import 'dart:convert';
import 'dart:typed_data';

/// Keep decoded photo bytes stable between rebuilds so Flutter's image cache
/// can reuse the same MemoryImage instead of decoding and flashing it again.
class PhotoBytesCache {
  static const _maxEntries = 48;
  static const _maxBytes = 20 * 1024 * 1024;
  static final Map<String, Uint8List> _entries = {};
  static int _bytes = 0;

  static Uint8List decode(String encoded) {
    final existing = _entries.remove(encoded);
    if (existing != null) {
      _entries[encoded] = existing;
      return existing;
    }
    final decoded = base64Decode(encoded);
    // Avoid retaining unusually large photos indefinitely.
    if (decoded.lengthInBytes > _maxBytes) return decoded;
    while (_entries.isNotEmpty &&
        (_entries.length >= _maxEntries || _bytes + decoded.lengthInBytes > _maxBytes)) {
      final oldest = _entries.keys.first;
      _bytes -= _entries.remove(oldest)!.lengthInBytes;
    }
    _entries[encoded] = decoded;
    _bytes += decoded.lengthInBytes;
    return decoded;
  }
}
