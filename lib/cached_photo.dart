import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Фото товара с локальным кэшем в папке приложения.
class CachedPhoto extends StatefulWidget {
  const CachedPhoto({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<CachedPhoto> createState() => _CachedPhotoState();
}

class _CachedPhotoState extends State<CachedPhoto> {
  static Directory? _directory;
  static final Map<String, Future<File?>> _pending = {};

  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CachedPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _file = null;
      _load();
    }
  }

  Future<Directory> _cacheDirectory() async {
    final existing = _directory;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/photo_cache');
    await directory.create(recursive: true);
    _directory = directory;
    return directory;
  }

  Future<void> _load() async {
    final file = await _cachedFile();
    if (!mounted || file == null) return;
    setState(() => _file = file);
  }

  Future<File?> _cachedFile() async {
    if (widget.url.isEmpty) return null;
    try {
      final directory = await _cacheDirectory();
      final name = sha1.convert(utf8.encode(widget.url)).toString();
      final file = File('${directory.path}/$name.jpg');
      if (await file.exists() && await file.length() > 500) return file;
      final pending = _pending[widget.url];
      if (pending != null) return pending;
      final future = _download(file);
      _pending[widget.url] = future;
      try {
        return await future;
      } finally {
        _pending.remove(widget.url);
      }
    } catch (_) {
      return null;
    }
  }

  Future<File?> _download(File file) async {
    try {
      final response = await http
          .get(
            Uri.parse(widget.url),
            headers: const {'user-agent': 'Mozilla/5.0'},
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200 || response.bodyBytes.length < 500) {
        return null;
      }
      final temporary = File('${file.path}.part');
      await temporary.writeAsBytes(response.bodyBytes, flush: true);
      return await temporary.rename(file.path);
    } catch (_) {
      return null;
    }
  }

  Widget _placeholder(IconData icon) => SizedBox(
        width: widget.width,
        height: widget.height,
        child: Icon(icon),
      );

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file != null) {
      return Image.file(
        file,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, _, _) =>
            _placeholder(Icons.broken_image_outlined),
      );
    }
    return Image.network(
      widget.url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, _, _) => _placeholder(Icons.broken_image_outlined),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(Icons.image_outlined),
    );
  }
}
