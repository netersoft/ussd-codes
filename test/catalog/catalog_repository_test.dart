import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ussd_codes/core/catalog/catalog_repository.dart';
import 'package:ussd_codes/core/catalog/models.dart';

Map<String, dynamic> _catalogJson({int version = 1, int schemaVersion = 1, String code = '*100#'}) => {
  'schemaVersion': schemaVersion,
  'version': version,
  'updatedAt': '2026-10-06',
  'countries': [
    {
      'id': 'bj',
      'name': {'fr': 'Bénin'},
      'operators': [
        {
          'id': 'bj-moov',
          'name': 'Moov Africa',
          'mccMnc': ['61602'],
          'codes': [
            {'id': 'bj-moov.balance', 'label': 'Solde', 'code': code, 'category': 'account'},
          ],
        },
      ],
    },
  ],
  'deviceCodes': <dynamic>[],
};

class _FakeBundle extends CachingAssetBundle {
  final String content;

  _FakeBundle(this.content);

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(utf8.encode(content));

  @override
  Future<String> loadString(String key, {bool cache = true}) async => content;
}

void main() {
  late Directory cacheDir;

  setUp(() => cacheDir = Directory.systemTemp.createTempSync('catalog_test'));
  tearDown(() => cacheDir.deleteSync(recursive: true));

  CatalogRepository repository({String remoteUrl = 'https://example.test/catalog.json', http.Client? client, int bundledVersion = 1}) => CatalogRepository(
    remoteUrl: remoteUrl,
    bundle: _FakeBundle(jsonEncode(_catalogJson(version: bundledVersion))),
    client: client ?? MockClient((_) async => http.Response('', 404)),
    cacheDir: () async => cacheDir,
  );

  MockClient serving(Map<String, dynamic> json) => MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode(json)), 200));

  test('loadLocal returns the bundled catalog when nothing is cached', () async {
    expect((await repository().loadLocal()).version, 1);
  });

  test('a newer remote catalog is used and cached for offline launches', () async {
    final repo = repository(client: serving(_catalogJson(version: 2, code: '*101#')));
    final (result, remote) = await repo.fetchRemote(await repo.loadLocal());

    expect(result, CatalogUpdateResult.updated);
    expect(remote?.version, 2);

    final offline = await repository().loadLocal();
    expect(offline.version, 2);
    expect(offline.entryById('bj-moov.balance')?.code.code, '*101#');
  });

  test('an app update bundling a newer catalog wins over an older cache', () async {
    final repo = repository(client: serving(_catalogJson(version: 2)));
    await repo.fetchRemote(await repo.loadLocal());

    expect((await repository(bundledVersion: 3).loadLocal()).version, 3);
  });

  test('a remote catalog that is not newer is ignored', () async {
    final repo = repository(client: serving(_catalogJson()));
    expect((await repo.fetchRemote(await repo.loadLocal())).$1, CatalogUpdateResult.upToDate);
  });

  test('a remote catalog in a newer format is ignored until the app is updated', () async {
    final repo = repository(client: serving(_catalogJson(version: 5, schemaVersion: Catalog.supportedSchemaVersion + 1)));
    final (result, remote) = await repo.fetchRemote(await repo.loadLocal());

    expect(result, CatalogUpdateResult.failed);
    expect(remote, isNull);
    expect((await repository().loadLocal()).version, 1);
  });

  test('an invalid remote catalog is never used', () async {
    final repo = repository(client: serving(_catalogJson(version: 2, code: '*100#{oops}')));
    expect((await repo.fetchRemote(await repo.loadLocal())).$1, CatalogUpdateResult.failed);

    final malformed = repository(client: MockClient((_) async => http.Response('<html>', 200)));
    expect((await malformed.fetchRemote(await malformed.loadLocal())).$1, CatalogUpdateResult.failed);
  });

  test('network errors fail without throwing', () async {
    final repo = repository(client: MockClient((_) async => throw const SocketException('offline')));
    expect((await repo.fetchRemote(await repo.loadLocal())).$1, CatalogUpdateResult.failed);
  });

  test('nothing is downloaded when no remote URL is configured', () async {
    final repo = repository(remoteUrl: '', client: MockClient((_) async => fail('no request expected')));
    expect((await repo.fetchRemote(await repo.loadLocal())).$1, CatalogUpdateResult.notConfigured);
  });
}
