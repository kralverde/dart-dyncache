import 'dart:math';

import 'package:dart_dyncache/dart_dyncache.dart';

void main() async {
  // A standard LFU cache
  final lfuCache = LFUDynamicCache<int, int>(10,
      storageGenerator: <K, V>(p0) => OrderedMap(entryWeight: p0),
      onEvict: (p0, p1) {
        if (p0 == 7 || p0 == -1) print('removed $p0');
      });

  // Fill with junk
  for (int i = 0; i < 10; i++) {
    lfuCache.set(-i, 0);
  }

  print('0: ${lfuCache.values}');

  // And it gets replaced, items that get evicted call the `onEvict` method,
  // if provided.
  for (int i = 0; i < 10; i++) {
    lfuCache.set(i, i);
  }

  // Perform some accesses
  lfuCache.get(5);
  lfuCache.get(5);
  lfuCache.get(4);
  lfuCache.get(4);
  lfuCache.get(4);
  lfuCache.get(5);

  // Remove a value, which calls the `onEvict` callback, if provided
  lfuCache.remove(7);

  print('1: ${lfuCache.values}');

  // The key-values that have been accessed continue to be cached since
  // they are now weighted higher
  for (int i = 0; i < 10; i++) {
    lfuCache.set(i + 10, 0);
  }
  print('2: ${lfuCache.values}');

  // If we want, we can also put weight on how long it has been since
  // an element was last accessed
  final lfruCache = SimpleDynamicCache<int, int>(10,
      entryWeight: (key, value, accessWeight, accessesSinceLastHit) =>
          accessWeight - (accessesSinceLastHit / 10),
      storageGenerator: <K, V>(p0) => OrderedMap(entryWeight: p0));
  for (int i = 0; i < 10; i++) {
    lfruCache.set(i, i);
  }
  lfruCache.get(5);
  lfruCache.get(5);
  lfruCache.get(4);
  lfruCache.get(4);
  lfruCache.get(4);
  lfruCache.get(5);

  // If insert more keys...
  for (int i = 0; i < 10; i++) {
    lfruCache.set(-i, 0);
  }

  // the accessed key-values remain.
  print('3: ${lfruCache.values}');

  // But if we do more...
  for (int i = 0; i < 20; i++) {
    lfruCache.set(-i, 0);
  }

  // you can see them become de-valued.
  print('4: ${lfruCache.values}');

  for (int i = 0; i < 10; i++) {
    lfruCache.set(-i, 0);
  }
  // And after just a bit more... all gone.
  print('5: ${lfruCache.values}');

  // you can also wrap a `BasicDynamicCache` with `AsyncBasicDynamicCache`
  // for built-in future support.

  // you should solely use `getAsync` with a `AsyncBasicDynamicCache`.
  // `get` will miss on all keys that have an associated future.
  // `getAsync` will await for the completion of that future.
  final fifoCache = FIFODynamicCache<int, int>(10,
      storageGenerator: <K, V>(e) => OrderedMap(entryWeight: e));
  final asyncFifoCache = AsyncBasicDynamicCache(fifoCache);

  asyncFifoCache.setAsync(1, () async {
    await Future.delayed(Duration(milliseconds: 2));
    return 1;
  }());

  // A get misses
  print('6: ${asyncFifoCache.get(1, throwOnUnsafe: false)}');
  // But an asyncGet awaits the result
  print('7: ${await asyncFifoCache.getAsync(1)}');

  // you can also add an `AuxiliaryKeyManager` to a `BasicDynamicCache`.
  // An `AuxiliaryKeyManager` creates an auxiliary key for every main key
  // added an vice-versa. There should be a 1-1 correspondence between main keys
  // and auxiliary keys. Auxiliary key sets should not intersect.

  // this manager will map a main key of type `int` to a String by converting it
  // to its string representation.
  // it converts an auxiliary key to a main key by parsing the string.
  final manager = AuxiliaryKeyManager<String, int, String>(
      generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) => '$mainKey',
      generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
          int.parse(auxiliaryKey));
  final lruCache = LRUDynamicCache(10,
      storageGenerator: <K, V>(e) => OrderedMap(entryWeight: e),
      auxiliaryKeyManagers: [manager]);

  // setting a main key...
  lruCache.set(1, 'val1');
  // can be queried by an auxiliary key
  print('8: ${lruCache.get('1')}');
  // and setting an auxiliary key
  lruCache.set('2', 'val2');
  // can be queried by the associated main key.
  print('9: ${lruCache.get(2)}');

  // A bad auxiliary key is still a miss. So is a non-handled key type.
  print('10: ${lruCache.get('3')}, ${lruCache.get(Object())}');

  // And an invalid key type will throw if it cannot be handled.
  // This includes non-handled types.
  try {
    lruCache.set(Object(), 'objectVal');
  } catch (e) {
    print(e);
  }
  // And unparsable keys.
  try {
    lruCache.set('not a int', 'bad parse');
  } catch (e) {
    print(e);
  }

  // By default, auxiliary key conflicts will throw errors, but if your methods
  // are sound, you may want to set `checkAuxiliaryKeys` to `false` to avoid
  // extraneous computations

  final badManager1 = AuxiliaryKeyManager<int, int, String>(
      generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) => mainKey,
      generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
          auxiliaryKey,
      id: 'aux keys and main keys are the same set');
  final badManager2 = AuxiliaryKeyManager<String, int, String>(
      generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) => '$mainKey',
      generateMainKeyFromAuxiliaryKeyAndValue: (k, v) => int.parse(k),
      id: 'int to string 1');
  final badManager3 = AuxiliaryKeyManager<String, int, String>(
      generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) => '$mainKey',
      generateMainKeyFromAuxiliaryKeyAndValue: (k, v) => int.parse(k),
      id: 'int to string 2');
  final badCache1 = LRUDynamicCache(10,
      storageGenerator: <K, V>(e) => OrderedMap(entryWeight: e),
      auxiliaryKeyManagers: [badManager1]);
  final badCache2 = LRUDynamicCache(10,
      storageGenerator: <K, V>(e) => OrderedMap(entryWeight: e),
      auxiliaryKeyManagers: [badManager2, badManager3]);

  try {
    badCache1.set(1, 'aux conflicts with main');
  } catch (e) {
    print(e);
  }
  try {
    badCache2.set('1', 'aux conflicts with aux');
  } catch (e) {
    print(e);
  }

  // !!! Important note about using auxilairy keys with async caches !!!
  // Auxiliary keys normally work as follows:
  //
  //         |----------> +-------+ >--------V |----------> +-------+ >--------V
  //  [AUXILIARY KEY]     | VALUE |     [MAIN KEY]          | VALUE |     [AUXILIARY KEY]
  //         ^----------< +-------+ <--------| ^----------< +-------+ <--------|
  //
  // For an auxiliary key to be associate with other auxiliary keys, it must
  // first convert to the main key.
  //
  // The issue arises because with a future, the value is not known until the
  // future completes; when calling `asyncGet`, it will only await if the key
  // passed in is the same key passed into `asyncSet`, other keys will miss,
  // even if they are associated main or auxiliary keys.
  //
  // This issue can be side stepped with the `valueNeeded` argument of the
  // AuxiliaryKeyManager constructor. If the manager conversion functions
  // do not rely on the value, this can be set to `false`.

  final manager1 = AuxiliaryKeyManager<String, int, int>(
      generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) => '$mainKey',
      generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
          int.parse(auxiliaryKey),
      valueNeeded: false);

  final manager2 = AuxiliaryKeyManager<double, int, int>(
      generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) =>
          mainKey + value! / (pow(10, '$value'.length)),
      generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
          auxiliaryKey ~/ 1);

  final cache = LRUDynamicCache<int, int>(10,
      storageGenerator: <K, V>(e) => OrderedMap(entryWeight: e),
      auxiliaryKeyManagers: [manager1, manager2]);
  final asyncCache = AsyncBasicDynamicCache(cache);

  // This sets the value of 1 to main key 100.
  // manager1 will create an auxiliary key of '100' and does not require the value.
  // manager2 will create an auxiliary key of 101 and does require the value.
  asyncCache.setAsync(100, () async {
    await Future.delayed(Duration(milliseconds: 5));
    return 1;
  }());

  final futures1 = [
    asyncCache.getAsync(100),
    asyncCache.getAsync('100'),
    asyncCache.getAsync(100.1)
  ];
  final results1 = await Future.wait(futures1);
  // The main key hits, '100' keys because it does not require the key.
  // Because manager2 requires the value, 101 misses as we cannot calculate
  // it before knowing the value.
  print('11: $results1');

  asyncCache.setAsync(200.1, () async {
    await Future.delayed(Duration(milliseconds: 5));
    return 1;
  }());

  final futures2 = [
    asyncCache.getAsync(200),
    asyncCache.getAsync('200'),
    asyncCache.getAsync(200.1)
  ];
  // Because manager2 requires the value, we cannot derive the main key.
  // because we cannot derive the main key, we cannot derive manager1's aux
  // key; only manager2's key awaits the value because that is the only known
  // key before we see the value.
  final results2 = await Future.wait(futures2);
  print('12: $results2');

  // Of course, after the future complete, all the keys are now associated.
  final futures3 = [
    asyncCache.getAsync(200),
    asyncCache.getAsync('200'),
    asyncCache.getAsync(200.1)
  ];
  final results3 = await Future.wait(futures3);
  print('13: $results3');
}

//kralverde (c) 2023
