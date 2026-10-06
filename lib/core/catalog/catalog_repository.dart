import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../helpers/logging/log_helper.dart';
import 'models.dart';
import 'sources.dart' show builtCatalogPath;

enum CatalogUpdateResult { updated, upToDate, failed, notConfigured }

/// Loads the USSD catalog: the copy bundled with the app, replaced by a newer
/// one downloaded from [remoteUrl] and cached on disk, so corrections reach
/// users without a store release and the app keeps working offline.
class CatalogRepository {
  final String remoteUrl;
  final AssetBundle _bundle;
  final http.Client _client;
  final Future<Directory> Function() _cacheDir;

  CatalogRepository({
    required this.remoteUrl,
    AssetBundle? bundle,
    http.Client? client,
    Future<Directory> Function()? cacheDir,
  }) : _bundle = bundle ?? rootBundle,
       _client = client ?? http.Client(),
       _cacheDir = cacheDir ?? getApplicationSupportDirectory;

  static const _cacheFileName = 'catalog.json';
  static const _timeout = Duration(seconds: 15);

  bool get isRemoteConfigured => remoteUrl.isNotEmpty;

  /// The newest catalog available without network: the cached download when
  /// it's newer than the bundled copy (an app update may bundle a newer one).
  Future<Catalog> loadLocal() async {
    final bundled = Catalog.fromJson(jsonDecode(await _bundle.loadString(builtCatalogPath)) as Map<String, dynamic>);
    final cached = await _readCache();
    return cached != null && cached.version > bundled.version ? cached : bundled;
  }

  /// Downloads the remote catalog and caches it when it's newer than
  /// [current]. Returns the new catalog, or null when there is nothing to use.
  Future<(CatalogUpdateResult, Catalog?)> fetchRemote(Catalog current) async {
    if (!isRemoteConfigured) return (CatalogUpdateResult.notConfigured, null);

    try {
      final response = await _client.get(Uri.parse(remoteUrl)).timeout(_timeout);
      if (response.statusCode != 200) {
        LogHelper.w('Catalog download failed: HTTP ${response.statusCode}');
        return (CatalogUpdateResult.failed, null);
      }

      final content = utf8.decode(response.bodyBytes);
      final remote = _parse(content);
      if (remote == null) return (CatalogUpdateResult.failed, null);
      if (remote.version <= current.version) return (CatalogUpdateResult.upToDate, null);

      await (await _cacheFile()).writeAsString(content, flush: true);
      return (CatalogUpdateResult.updated, remote);
    } catch (e) {
      LogHelper.w('Catalog download failed', error: e);
      return (CatalogUpdateResult.failed, null);
    }
  }

  Future<Catalog?> _readCache() async {
    try {
      final file = await _cacheFile();
      if (!file.existsSync()) return null;
      return _parse(await file.readAsString());
    } catch (e) {
      LogHelper.w('Unreadable cached catalog', error: e);
      return null;
    }
  }

  /// A catalog the app can safely use, or null: a newer format (the app needs
  /// an update first) or invalid content is ignored, never shown.
  Catalog? _parse(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      if (json['schemaVersion'] != Catalog.supportedSchemaVersion) return null;
      final catalog = Catalog.fromJson(json);
      final errors = catalog.validate();
      if (errors.isNotEmpty) {
        LogHelper.w('Invalid catalog ignored: ${errors.take(5).join('; ')}');
        return null;
      }
      return catalog;
    } catch (e) {
      LogHelper.w('Malformed catalog ignored', error: e);
      return null;
    }
  }

  Future<File> _cacheFile() async => File('${(await _cacheDir()).path}/$_cacheFileName');
}
