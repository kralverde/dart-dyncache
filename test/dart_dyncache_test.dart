import 'dart:async';
import 'dart:math';

import 'package:dart_dyncache/dart_dyncache.dart';
import 'package:test/test.dart';

void main() {
  group('Ordered Storage |', () {
    test('simple insertion', () {
      final storage = OrderedMap<String, int>(
          entryWeight: (key, value) => value.toDouble());
      storage['test'] = 0;
      expect(storage['test'], 0);
      expect(storage['doesnt exist'], null);
    });
    test('simple remove', () {
      final storage = OrderedMap<String, int>(
          entryWeight: (key, value) => value.toDouble());
      storage['test'] = 0;
      final oldValue = storage.remove('test');
      final nullValue = storage.remove('doesnt exist');
      expect(storage['test'], null);
      expect(oldValue, 0);
      expect(nullValue, null);
    });
    test('simple update', () {
      final storage = OrderedMap<String, int>(
          entryWeight: (key, value) => value.toDouble());
      storage['test'] = 0;
      storage['test'] = 1;
      expect(storage['test'], 1);
    });
    test('ordering', () {
      final storage = OrderedMap<String, int>(entryWeight: (key, value) {
        if (value % 2 == 0) {
          return value.toDouble();
        } else {
          return -value.toDouble();
        }
      });
      for (int i = 0; i < 10; i++) {
        storage['$i'] = i;
      }
      expect(storage.values, [8, 6, 4, 2, 0, 1, 3, 5, 7, 9]);
    });
    test('insert at highest weight', () {
      final storage = OrderedMap<String, int>(entryWeight: (key, value) => 0);
      for (int i = 0; i < 10; i++) {
        storage['$i'] = i;
      }
      expect(storage.values, [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]);
    });
    test('remove lightest', () {
      final storage = OrderedMap<String, int>(
          entryWeight: (key, value) => -value.toDouble());
      for (int i = 0; i < 10; i++) {
        storage['$i'] = i;
      }
      final lightest = storage.removeLightestEntry()?.value;
      expect(lightest, 9);
      expect(storage.values, [0, 1, 2, 3, 4, 5, 6, 7, 8]);
      expect(storage.length, 9); // Length is passed from _keyMap
    });
    test('remove heaviest', () {
      final storage = OrderedMap<String, int>(
          entryWeight: (key, value) => -value.toDouble());
      for (int i = 0; i < 10; i++) {
        storage['$i'] = i;
      }
      final heaviest = storage.removeHeaviestEntry()?.value;
      expect(heaviest, 0);
      expect(storage.values, [1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(storage.length, 9); // Length is passed from _keyMap
    });
    test('remove n lightest', () {
      final storage = OrderedMap<String, int>(
          entryWeight: (key, value) => -value.toDouble());
      for (int i = 0; i < 10; i++) {
        storage['$i'] = i;
      }
      final lightest = storage.removeNLightestEntries(2);
      expect(lightest.map((e) => e.value), [8, 9]);
      expect(storage.values, [0, 1, 2, 3, 4, 5, 6, 7]);
      expect(storage.length, 8);

      final lightestAll = storage.removeNLightestEntries(1000); //overload
      expect(lightestAll.map((e) => e.value), [0, 1, 2, 3, 4, 5, 6, 7]);
      expect(storage.values, []);
      expect(storage.length, 0);

      final nullVal = storage.removeLightestEntry();
      expect(nullVal, null);
    });
    test('remove n heaviest', () {
      final storage = OrderedMap<String, int>(
          entryWeight: (key, value) => -value.toDouble());
      for (int i = 0; i < 10; i++) {
        storage['$i'] = i;
      }
      final heaviest = storage.removeNHeaviestEntries(2);
      expect(heaviest.map((e) => e.value), [0, 1]);
      expect(storage.values, [2, 3, 4, 5, 6, 7, 8, 9]);
      expect(storage.length, 8);

      final heaviestAll = storage.removeNHeaviestEntries(1000); //overload
      expect(heaviestAll.map((e) => e.value), [2, 3, 4, 5, 6, 7, 8, 9]);
      expect(storage.values, []);
      expect(storage.length, 0);

      final nullVal = storage.removeHeaviestEntry();
      expect(nullVal, null);
    });
    test('update order', () {
      final storage = OrderedMap<String, int>(
          entryWeight: (key, value) => value.toDouble());
      for (int i = 0; i < 10; i++) {
        storage['$i'] = i;
      }
      for (int i = 109; i >= 100; i--) {
        storage['${i - 100}'] = i;
      }
      expect(
          storage.values, [109, 108, 107, 106, 105, 104, 103, 102, 101, 100]);
      expect(storage.length, 10);
    });
  });
  group('Simple Cache |', () {
    group('Known cache types |', () {
      test('Insert highest', () {
        final cache = FIFODynamicCache(10,
            storageGenerator: <K, V>(entryWeight) =>
                OrderedMap(entryWeight: entryWeight));
        for (int i = 0; i < 100; i++) {
          cache.set(i, i);
        }

        expect(cache.length, cache.cacheCapacity);
        expect(cache.values.length, cache.cacheCapacity);
        expect(cache.values, [99, 98, 97, 96, 95, 94, 93, 92, 91, 90]);
      });

      test('LRU', () {
        final cache = LRUDynamicCache(10,
            storageGenerator: <K, V>(entryWeight) =>
                OrderedMap(entryWeight: entryWeight));
        for (int i = 0; i < 100; i++) {
          cache.set(i, i);
        }

        cache.get(90);
        cache.get(91);
        cache.get(90);
        cache.get(1);

        expect(cache.length, cache.cacheCapacity);
        expect(cache.values.length, cache.cacheCapacity);
        expect(cache.values, [90, 91, 99, 98, 97, 96, 95, 94, 93, 92]);
      });

      test('LFU', () {
        final cache = LFUDynamicCache<int, int>(10,
            storageGenerator: <K, V>(entryWeight) =>
                OrderedMap(entryWeight: entryWeight));
        for (int i = 0; i < 100; i++) {
          cache.set(i, i);
        }

        cache.get(90);
        cache.get(91);
        cache.get(91);
        cache.get(91);
        cache.get(90);
        cache.get(1);

        expect(cache.length, cache.cacheCapacity);
        expect(cache.values.length, cache.cacheCapacity);
        expect(cache.values, [91, 90, 99, 98, 97, 96, 95, 94, 93, 92]);
      });
    });
    group('Auxiliary key managers |', () {
      test('basic mapping', () {
        final manager = AuxiliaryKeyManager<String, int, int>(
            generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) =>
                '$mainKey',
            generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
                int.parse(auxiliaryKey));

        final cache = SimpleDynamicCache<int, int>(10,
            entryWeight: (key, value, accessWeight, accessesSinceLastHit) => 0,
            storageGenerator: <K, V>(entryWeight) =>
                OrderedMap(entryWeight: entryWeight),
            auxiliaryKeyManagers: [manager]);

        for (int i = 20; i < 30; i++) {
          cache.set(i, i);
        }
        for (int i = 0; i < 10; i++) {
          cache.set(i, i);
        }

        expect(cache.length, cache.cacheCapacity);
        expect(cache.values.length, cache.cacheCapacity);
        expect(cache.auxKeysForHandlerAtIndex(0).length, cache.cacheCapacity);

        expect(cache.get('0'), 0);
        expect(cache.get(1), 1);
        expect(cache.get('2'), 2);
        expect(cache.get(3), 3);

        final val1 = cache.remove('0');
        final val2 = cache.remove('1');
        final val3 = cache.remove(2);

        expect(val1, 0);
        expect(val2, 1);
        expect(val3, 2);

        expect(cache.length, cache.cacheCapacity - 3);
        expect(
            cache.auxKeysForHandlerAtIndex(0).length, cache.cacheCapacity - 3);
        expect(cache.values, [9, 8, 7, 6, 5, 4, 3]);

        cache.set('100', 100);
        expect(cache.get(100), 100);
        expect(cache.length, cache.cacheCapacity - 2);
        expect(
            cache.auxKeysForHandlerAtIndex(0).length, cache.cacheCapacity - 2);
        expect(cache.values, [100, 9, 8, 7, 6, 5, 4, 3]);
      });

      test('same handler type', () {
        final manager1 = AuxiliaryKeyManager<String, int, int>(
            generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) =>
                '$mainKey',
            generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
                int.parse(auxiliaryKey));

        final manager2 = AuxiliaryKeyManager<String, int, int>(
            generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) =>
                'other_$mainKey',
            generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
                int.parse(auxiliaryKey.replaceFirst('other_', '')));

        final cache = SimpleDynamicCache<int, int>(10,
            entryWeight: (key, value, accessWeight, accessesSinceLastHit) => 0,
            storageGenerator: <K, V>(entryWeight) =>
                OrderedMap(entryWeight: entryWeight),
            auxiliaryKeyManagers: [manager1, manager2]);

        for (int i = 20; i < 30; i++) {
          cache.set(i, i);
        }
        for (int i = 0; i < 10; i++) {
          cache.set(i, i);
        }

        expect(cache.length, cache.cacheCapacity);
        expect(cache.values.length, cache.cacheCapacity);
        expect(cache.auxKeysForHandlerAtIndex(0).length, cache.cacheCapacity);
        expect(cache.auxKeysForHandlerAtIndex(1).length, cache.cacheCapacity);

        expect(cache.get(0), 0);
        expect(cache.get('0'), 0);
        expect(cache.get('other_0'), 0);

        final val1 = cache.remove('0');
        final val2 = cache.remove('other_1');
        final val3 = cache.remove(2);

        expect(val1, 0);
        expect(val2, 1);
        expect(val3, 2);

        expect(cache.length, cache.cacheCapacity - 3);
        expect(
            cache.auxKeysForHandlerAtIndex(0).length, cache.cacheCapacity - 3);
        expect(
            cache.auxKeysForHandlerAtIndex(1).length, cache.cacheCapacity - 3);
        expect(cache.values, [9, 8, 7, 6, 5, 4, 3]);

        cache.set('other_100', 100);
        expect(cache.get('100'), 100);
        expect(cache.get(100), 100);
        expect(cache.length, cache.cacheCapacity - 2);
        expect(
            cache.auxKeysForHandlerAtIndex(0).length, cache.cacheCapacity - 2);
        expect(cache.values, [100, 9, 8, 7, 6, 5, 4, 3]);
      });

      test('same as main type', () {
        final manager = AuxiliaryKeyManager<int, int, int>(
            generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) =>
                mainKey + 100,
            generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
                auxiliaryKey - 100);

        final cache = SimpleDynamicCache<int, int>(10,
            entryWeight: (key, value, accessWeight, accessesSinceLastHit) => 0,
            storageGenerator: <K, V>(entryWeight) =>
                OrderedMap(entryWeight: entryWeight),
            auxiliaryKeyManagers: [manager]);

        for (int i = 20; i < 30; i++) {
          cache.set(i, i);
        }
        for (int i = 0; i < 10; i++) {
          cache.set(i, i);
        }

        expect(cache.length, cache.cacheCapacity);
        expect(cache.values.length, cache.cacheCapacity);
        expect(cache.auxKeysForHandlerAtIndex(0).length, cache.cacheCapacity);

        expect(cache.get(0), 0);
        expect(cache.get(101), 1);
        expect(cache.get(2), 2);

        final val1 = cache.remove(100);
        final val2 = cache.remove(1);
        final val3 = cache.remove(102);

        expect(val1, 0);
        expect(val2, 1);
        expect(val3, 2);

        expect(cache.length, cache.cacheCapacity - 3);
        expect(
            cache.auxKeysForHandlerAtIndex(0).length, cache.cacheCapacity - 3);
        expect(cache.values, [9, 8, 7, 6, 5, 4, 3]);

        // Cannot set auxiliary key; defaults to main key.
      });

      test('type exceptions', () {
        final manager1 = AuxiliaryKeyManager<String, int, int>(
            generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) =>
                '$mainKey',
            generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
                int.parse(auxiliaryKey));

        final manager2 = AuxiliaryKeyManager<String, int, int>(
            generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) =>
                'other_$mainKey',
            generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
                int.parse(auxiliaryKey.replaceFirst('other_', '')));

        final cache = SimpleDynamicCache<int, int>(10,
            entryWeight: (key, value, accessWeight, accessesSinceLastHit) => 0,
            storageGenerator: <K, V>(entryWeight) =>
                OrderedMap(entryWeight: entryWeight),
            auxiliaryKeyManagers: [manager1, manager2]);

        for (int i = 20; i < 30; i++) {
          cache.set(i, i);
        }
        for (int i = 0; i < 10; i++) {
          cache.set(i, i);
        }

        expect(cache.get(Object()), null);
        expect(() => cache.set(Object(), 1),
            throwsA(isA<DynCacheTypeException>()));
      });
      test('collision exceptions', () {
        final managerA = AuxiliaryKeyManager<int, int, int>(
            generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) =>
                mainKey,
            generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
                auxiliaryKey);
        final cacheA = SimpleDynamicCache<int, int>(10,
            entryWeight: (key, value, accessWeight, accessesSinceLastHit) => 0,
            storageGenerator: <K, V>(entryWeight) =>
                OrderedMap(entryWeight: entryWeight),
            auxiliaryKeyManagers: [managerA]);

        expect(() => cacheA.set(1, 1),
            throwsA(isA<DynCacheAuxKeyCollisionException>()));
        expect(cacheA.length, 0);
        expect(cacheA.values.length, 0);
        expect(cacheA.auxKeysForHandlerAtIndex(0).length, 0);

        final managerB = AuxiliaryKeyManager<String, int, int>(
            generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) => 'same',
            generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
                0);
        final cacheB = SimpleDynamicCache<int, int>(10,
            entryWeight: (key, value, accessWeight, accessesSinceLastHit) => 0,
            storageGenerator: <K, V>(entryWeight) =>
                OrderedMap(entryWeight: entryWeight),
            auxiliaryKeyManagers: [managerB]);
        cacheB.set(1, 1);
        expect(() => cacheB.set(2, 2),
            throwsA(isA<DynCacheAuxKeyCollisionException>()));
        expect(cacheB.length, 1);
        expect(cacheB.values.length, 1);
        expect(cacheB.auxKeysForHandlerAtIndex(0).length, 1);
        expect(() => cacheB.set('bad key', 1),
            throwsA(isA<DynCacheAuxKeyCollisionException>()));
        expect(cacheB.length, 1);
        expect(cacheB.values.length, 1);
        expect(cacheB.auxKeysForHandlerAtIndex(0).length, 1);

        final managerC = AuxiliaryKeyManager<int, int, int>(
            generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) =>
                mainKey + 100,
            generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
                auxiliaryKey - 100);

        final cacheC = SimpleDynamicCache<int, int>(10,
            entryWeight: (key, value, accessWeight, accessesSinceLastHit) => 0,
            storageGenerator: <K, V>(entryWeight) =>
                OrderedMap(entryWeight: entryWeight),
            auxiliaryKeyManagers: [managerC]);

        cacheC.set(1, 1);
        expect(cacheC.get(101), 1);
        cacheC.set(101, 2);
        expect(cacheC.get(1), 2);
        expect(cacheC.get(101), 2);
      });
    });
  });
  group('Async Cache |', () {
    test('set futures', () async {
      final simpleCache = SimpleDynamicCache<int, int>(10,
          entryWeight: (key, value, accessWeight, accessesSinceLastHit) => 0,
          storageGenerator: <K, V>(entryWeight) =>
              OrderedMap(entryWeight: entryWeight));

      final cache = AsyncBasicDynamicCache(simpleCache);
      for (int i = 0; i < 100; i++) {
        cache.setAsync(i, () async {
          await Future.delayed(Duration(milliseconds: 1));
          return i;
        }());
      }

      await cache.awaitAllCurrentFutureValues();

      expect(cache.length, cache.cacheCapacity);
      expect(cache.values.length, cache.cacheCapacity);
      expect(cache.values, [99, 98, 97, 96, 95, 94, 93, 92, 91, 90]);
    });
    test('get futures', () async {
      final simpleCache = SimpleDynamicCache<int, int>(10,
          entryWeight: (key, value, accessWeight, accessesSinceLastHit) => 0,
          storageGenerator: <K, V>(entryWeight) =>
              OrderedMap(entryWeight: entryWeight));

      final cache = AsyncBasicDynamicCache(simpleCache);
      for (int i = 0; i < 100; i++) {
        cache.setAsync(i, () async {
          await Future.delayed(Duration(milliseconds: 10));
          return i;
        }());
      }

      expect(await cache.getAsync(99), 99);
      expect(await cache.getAsync(91), 91);
      expect(cache.doesKeyHaveAssociatedFuture(99), false);
      expect(cache.doesKeyHaveAssociatedFuture(91), false);

      cache.setAsync(100, () async {
        await Future.delayed(Duration(milliseconds: 1));
        return 100;
      }());
      cache.setAsync(100, () async {
        await Future.delayed(Duration(milliseconds: 10));
        return 101;
      }());
      cache.setAsync(100, () async {
        await Future.delayed(Duration(milliseconds: 3));
        return 102;
      }());

      expect(await cache.getAsync(100), 101);
    });
    test('get future with aux keys', () async {
      final manager = AuxiliaryKeyManager<String, int, int>(
          generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) =>
              '$mainKey',
          generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
              int.parse(auxiliaryKey),
          valueNeeded: false);
      final simpleCache = SimpleDynamicCache<int, int>(10,
          entryWeight: (key, value, accessWeight, accessesSinceLastHit) => 0,
          storageGenerator: <K, V>(entryWeight) =>
              OrderedMap(entryWeight: entryWeight),
          auxiliaryKeyManagers: [manager]);

      final cache = AsyncBasicDynamicCache(simpleCache);
      for (int i = 0; i < 100; i++) {
        cache.setAsync(i, () async {
          await Future.delayed(Duration(milliseconds: 10));
          return i;
        }());
      }

      final value = await cache.getAsync('99');
      expect(value, 99);
    });

    // This is less of a test and more of a demonstration how aux keys can cause
    // misses
    test('miss future with aux keys', () async {
      final manager = AuxiliaryKeyManager<String, int, int>(
        generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) => '$mainKey',
        generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
            int.parse(auxiliaryKey),
      );
      final simpleCache = SimpleDynamicCache<int, int>(10,
          entryWeight: (key, value, accessWeight, accessesSinceLastHit) => 0,
          storageGenerator: <K, V>(entryWeight) =>
              OrderedMap(entryWeight: entryWeight),
          auxiliaryKeyManagers: [manager]);

      final cache = AsyncBasicDynamicCache(simpleCache);
      for (int i = 0; i < 100; i++) {
        cache.setAsync(i, () async {
          await Future.delayed(Duration(milliseconds: 100));
          return i;
        }());
      }

      final value1 = await cache.getAsync('99');
      final value2 = await cache.getAsync(99);
      final value3 = await cache.getAsync('99');
      expect(value1,
          null); // Because valueNeeded is true, we cannot pre-generate the auxKeys
      expect(value2, 99);
      expect(value3, 99);
    });
    test('currentFutures', () async {
      final simpleCache = SimpleDynamicCache<String, int>(10,
          entryWeight: (key, value, accessWeight, accessesSinceLastHit) => 0,
          storageGenerator: <K, V>(entryWeight) =>
              OrderedMap(entryWeight: entryWeight));

      final cache = AsyncBasicDynamicCache(simpleCache);

      final completer = Completer<int>();
      cache.setAsync('my future', completer.future);

      expect(cache.waitingOnCount, 1);
      expect(cache.doesKeyHaveAssociatedFuture('my future'), true);

      completer.complete(1);

      final value = await cache.getAsync('my future');
      expect(value, 1);
      expect(cache.waitingOnCount, 0);
      expect(cache.doesKeyHaveAssociatedFuture('my future'), false);
    });
  });
}

//kralverde (c) 2023
