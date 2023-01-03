import 'dart:math';

import 'package:dart_dyncache/dart_dyncache.dart';

Future<int> expensiveOperation() async {
  await Future.delayed(Duration(milliseconds: 1));
  return 0;
}

void main() async {
  final keyCount = 5000;
  final keyRange = 1000;

  final rand = Random(DateTime.now().millisecondsSinceEpoch);
  final uniform = [for (int i = 0; i < keyCount; i++) rand.nextDouble()];

  final keysUniform = uniform.map((e) => (e * keyRange).floor());
  final keysSkew2 = uniform.map((e) => (e * e * keyRange).floor());
  final keysSkew4 = uniform.map((e) => (e * e * e * e * keyRange).floor());

  final dataSets = [
    ['Uniform Keys', keysUniform],
    ['x2 Skewed Keys', keysSkew2],
    ['x4 Skewed Keys', keysSkew4]
  ];

  for (final set in dataSets) {
    final name = set[0] as String;
    final keySet = set[1] as Iterable<int>;
    print('$name:');
    final sw = Stopwatch()..start();
    for (final _ in keySet) {
      await expensiveOperation();
    }
    final rawTime = sw.elapsed;
    print('No caching took ${rawTime.inMilliseconds} milliseconds');
    for (int cacheSize = keyRange ~/ 4;
        cacheSize <= keyRange;
        cacheSize += keyRange ~/ 4) {
      final lfuCache = LFUDynamicCache<int, int>(cacheSize,
          storageGenerator: <K, V>(entryWeight) =>
              OrderedMap(entryWeight: entryWeight));
      sw.reset();
      for (final key in keySet) {
        final value = lfuCache.get(key);
        if (value == null) {
          lfuCache.set(key, await expensiveOperation());
        }
      }
      final cacheTime = sw.elapsed;
      print(
          'LFU Cache with ${cacheSize * 100 ~/ keyRange}% of the key capacity took ${cacheTime.inMilliseconds} milliseconds (${rawTime.inMilliseconds / cacheTime.inMilliseconds} speedup)');
    }
    final map = <int, int>{};
    sw.reset();
    for (final key in keySet) {
      final value = map[key];
      if (value == null) {
        map[key] = await expensiveOperation();
      }
    }
    final mapTime = sw.elapsed;
    print(
        'mapping took ${mapTime.inMilliseconds} milliseconds (${rawTime.inMilliseconds / mapTime.inMilliseconds} speedup)');
  }
}

//kralverde (c) 2023
