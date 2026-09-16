class CachedAudioFile {
  const CachedAudioFile({
    required this.path,
    required this.byteLength,
    required this.modified,
  });

  final String path;
  final int byteLength;
  final DateTime modified;
}

class AvitoCachePlan {
  const AvitoCachePlan({
    required this.evictions,
    required this.retainedCount,
    required this.retainedBytes,
  });

  final List<CachedAudioFile> evictions;
  final int retainedCount;
  final int retainedBytes;
}

/// Удаляет самые старые записи, пока кэш не укладывается в оба лимита.
AvitoCachePlan planAvitoCache(
  Iterable<CachedAudioFile> values, {
  required int maxFiles,
  required int maxBytes,
}) {
  if (maxFiles <= 0 || maxBytes <= 0) {
    throw ArgumentError('Лимиты кэша должны быть положительными');
  }
  final files = values.toList()
    ..sort((a, b) => a.modified.compareTo(b.modified));
  var bytes = files.fold<int>(0, (total, file) => total + file.byteLength);
  final evictions = <CachedAudioFile>[];
  while (files.length > maxFiles || bytes > maxBytes) {
    final oldest = files.removeAt(0);
    evictions.add(oldest);
    bytes -= oldest.byteLength;
  }
  return AvitoCachePlan(
    evictions: evictions,
    retainedCount: files.length,
    retainedBytes: bytes,
  );
}

String formatAvitoCacheSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} КБ';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
}
