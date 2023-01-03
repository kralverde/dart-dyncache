part of dart_dyncache;

const _minIntJSSafe = -(1 << 52);
const _maxIntJSSafe = (1 << 52) - 1;

class DynCacheException implements Exception {}

/// Thrown when a [BaseDynamicCache] cannot handle a key type.
class DynCacheTypeException extends DynCacheException {
  final String message;
  DynCacheTypeException(this.message);

  @override
  String toString() {
    return "DynCacheTypeException: $message";
  }
}

/// Thrown on unsafe [BaseDynamicCache.get] behavior.
class DynCacheUnsafeException extends DynCacheException {
  final String message;
  DynCacheUnsafeException(this.message);

  @override
  String toString() {
    return "DynCacheUnsafeException: $message";
  }
}

/// Thrown if there is a key collision with auxiliary keys and [BaseDynamicCache.checkAuxiliaryKeys] is `true`.
class DynCacheAuxKeyCollisionException extends DynCacheException {
  final String message;
  DynCacheAuxKeyCollisionException(this.message);

  @override
  String toString() {
    return "DynCacheUnsafeException: $message";
  }
}

class _AuxiliaryKeyMap<KA, KO, V> {
  final AuxiliaryKeyManager<KA, KO, V> _keyManager;
  final _auxKeyToMainKeyMap = <KA, KO>{};

  _AuxiliaryKeyMap(this._keyManager);

  Iterable<MapEntry<KA, KO>> get entries => _auxKeyToMainKeyMap.entries;
  Iterable<KA> get keys => _auxKeyToMainKeyMap.keys;
  bool get needsValue => _keyManager.valueNeeded;
  String get id => _keyManager.identifier;
  KO? getExistingMainKeyFromAuxiliaryKey(dynamic key) =>
      _auxKeyToMainKeyMap[key];
  KO generateMainKeyFromAuxiliaryKeyAndValue(dynamic key, V? value) =>
      _keyManager.generateMainKeyFromAuxiliaryKeyAndValue(key as KA, value);
  KA generateAuxiliaryKeyFromMainKeyAndValue(KO key, V? value) =>
      _keyManager.generateAuxiliaryKeyFromMainKeyAndValue(key, value);
  void associateAuxiliaryKeyWithMainKey(dynamic auxiliaryKey, KO mainKey) =>
      _auxKeyToMainKeyMap[auxiliaryKey as KA] = mainKey;
  void removeAuxiliaryKey(dynamic auxiliaryKey) =>
      _auxKeyToMainKeyMap.remove(auxiliaryKey);
  bool containsKey(dynamic auxiliaryKey) =>
      _auxKeyToMainKeyMap.containsKey(auxiliaryKey);
  bool canHandleAuxiliaryKey(dynamic auxiliaryKey) =>
      _keyManager.canHandleAuxiliaryKey(auxiliaryKey);
}

class _DynamicCacheEntry<V> {
  V _value;
  double _accessWeight;
  int _lastAccessCount;
  _DynamicCacheEntry(this._value, this._accessWeight, this._lastAccessCount);
}

typedef CacheWeightFunction<K, V> = double Function(
    K key, V value, double accessWeight, int accessesSinceLastHit);
typedef OnEvictFunction<K, V> = void Function(K key, V value);

/// Abstract class for the basic functionality of a cache.
abstract class DynamicCache<K, V> {
  abstract final int cacheCapacity;
  abstract final OnEvictFunction<K, V>? onEvict;

  int get length;
  Iterable<K> get keys;
  Iterable<V> get values;
  Iterable<MapEntry<K, V>> get entries;

  V? get(dynamic key);
  void set(dynamic key, V value);
  V? remove(dynamic key);

  abstract int hits;
  abstract int misses;
}

/// An abstract cache class with a weight function that supports eviction and
/// auxiliary keys.
abstract class BaseDynamicCache<K, V> implements DynamicCache<K, V> {
  /// The maximum number of entries in the cache.
  @override
  final int cacheCapacity;

  /// The `accessWeight` of a entry is set to this value when first inserted
  /// with [set].
  double insertWeight;

  /// The `accessWeight` of an entry is increased by this amount when its value
  /// is updated with [set].
  double updateWeight;

  /// The `accessWeight` of an entry is increased by this amount when it is
  /// hit by a [get].
  double lookupWeight;

  /// Calculates the total weight of an entry.
  ///
  /// Values with the lowest weight are evicted first.
  ///
  /// `accessWeight` is the total accrued weight of an entry as per [insertWeight],
  /// [updateWeight], and [lookupWeight].
  ///
  /// `accessesSinceLastHit` is the number of calls to [set] or [get] since
  /// this entry was last accessed by [set] or [get].
  final CacheWeightFunction<K, V> entryWeight;

  /// Called when an entry is removed from eviction or [remove].
  @override
  final OnEvictFunction<K, V>? onEvict;

  /// If `true`, throws [DynCacheAuxKeyCollisionException] if a key generated
  /// by a [AuxiliaryKeyManager] is already in the main key set or another
  /// [AuxiliaryKeyManager].
  ///
  /// Note that this may decrease performance as this is O(n) over the number
  /// of [AuxiliaryKeyManager] when an element is inserted with a main key, and
  /// O(n^2) when an element is inserted with an auxiliary key.
  final bool checkAuxiliaryKeys;

  /// Incremented when [get] successfully returns a value.
  @override
  int hits = 0;

  /// Incremented when [get] returns null.
  @override
  int misses = 0;

  int _accessIdCounter = _minIntJSSafe;
  late OrderedStorage<K, _DynamicCacheEntry<V>> _internalStorage;
  final _auxiliaryKeyMaps = <_AuxiliaryKeyMap<dynamic, K, V>>[];

  /// The constructor for [BaseDynamicCache]
  ///
  /// [storageGenerator] is a function that generates the [OrderedStorage]
  /// used as the internal storage of the cache.
  ///
  /// [auxiliaryKeyManagers] are checked in-order when checking for auxiliary
  /// keys.
  BaseDynamicCache(this.cacheCapacity,
      {required this.entryWeight,
      required this.insertWeight,
      required this.updateWeight,
      required this.lookupWeight,
      required OrderedStorage<K1, V1> Function<K1, V1>(
              StorageWeightFunction<K1, V1>)
          storageGenerator,
      this.onEvict,
      this.checkAuxiliaryKeys = true,
      Iterable<AuxiliaryKeyManager<dynamic, K, V>>? auxiliaryKeyManagers}) {
    _internalStorage = storageGenerator<K, _DynamicCacheEntry<V>>(
        (key, value) => entryWeight(key, value._value, value._accessWeight,
            _accessIdCounter - value._lastAccessCount));
    auxiliaryKeyManagers
        ?.forEach((e) => _auxiliaryKeyMaps.add(_AuxiliaryKeyMap(e)));
  }

  void _counterRolloverProtection() {
    if (_accessIdCounter == _maxIntJSSafe) {
      // Loop 1: find largest offset
      final offset = _internalStorage.values
          .map((e) => _accessIdCounter - e._lastAccessCount)
          .reduce((value, element) => value > element ? value : element);
      // Loop 2: set new accesses
      for (final entry in _internalStorage.values) {
        entry._lastAccessCount = (_minIntJSSafe + offset) -
            (_accessIdCounter - entry._lastAccessCount);
      }
      // Set new counter
      _accessIdCounter = _minIntJSSafe + offset;
    }
  }

  /// This function should be called on all [get] and [set], just before the
  /// value is returned.
  void _incrementAccessIdCounter() {
    _accessIdCounter++;
    _counterRolloverProtection();
  }

  /// Given some auxiliary key, return the main key of the first mapping if
  /// it exists.
  ///
  /// The aux-main key mapping must already exist; this function does not
  /// generate a new key.
  K? getMainKeyFromAuxiliaryKey(dynamic key, bool throwOnBadType) {
    bool validKey = false;
    K? mainKey;
    for (final auxiliaryKeyMap in _auxiliaryKeyMaps) {
      if (auxiliaryKeyMap.canHandleAuxiliaryKey(key)) {
        validKey = true;
        mainKey = auxiliaryKeyMap.getExistingMainKeyFromAuxiliaryKey(key);
        if (mainKey != null) break;
      }
    }
    if (throwOnBadType && !validKey && key is! K) {
      throw DynCacheTypeException(
          'key $key (${key.runtimeType}) cannot be handled.');
    }
    return mainKey;
  }

  V? getValueForMainKey(K key) {
    final entry = _internalStorage[key];
    entry?._lastAccessCount = _accessIdCounter;
    entry?._accessWeight += lookupWeight;
    _internalStorage[key]; // Call again to re-sort after updating entry values
    _incrementAccessIdCounter();
    return entry?._value;
  }

  /// throws [DynCacheAuxKeyCollisionException] if [checkAuxiliaryKeys] is `true`
  /// and [key] already exists in an [AuxiliaryKeyManager].
  void setValueForMainKey(K key, V value) {
    if (checkAuxiliaryKeys) {
      for (final auxiliaryKeyMap in _auxiliaryKeyMaps) {
        if (auxiliaryKeyMap.containsKey(key)) {
          throw DynCacheAuxKeyCollisionException(
              'Main key $key conflicts with auxiliary key generator ${auxiliaryKeyMap.id}');
        }
      }
    }
    final entry = _DynamicCacheEntry<V>(value, insertWeight, _accessIdCounter);
    _internalStorage[key] = entry;
    _incrementAccessIdCounter();
  }

  void updateValueForMainKey(K key, V value) {
    final entry = _internalStorage[key];
    entry?._lastAccessCount = _accessIdCounter;
    entry?._accessWeight += updateWeight;
    entry?._value = value;
    _internalStorage[key]; // Call again to re-sort after updating entry values
    _incrementAccessIdCounter();
  }

  void removeNLightestEntries(final int n) {
    for (final entry in _internalStorage.removeNLightestEntries(n)) {
      final key = entry.key;
      final value = entry.value._value;
      if (onEvict != null) onEvict!(key, value);
      removeAuxiliaryKeysForMainKeyAndValue(key, value);
    }
  }

  /// Given a main key, remove and return the value if exists.
  V? removeValueForMainKey(K key) {
    final entry = _internalStorage.remove(key);
    if (entry != null && onEvict != null) {
      onEvict!(key, entry._value);
    }
    return entry?._value;
  }

  /// Given a main key-value pair, generate keys for all [AuxiliaryKeyManager]
  ///
  /// throws [DynCacheAuxKeyCollisionException] if [checkAuxiliaryKeys] is
  /// `true` and a generated auxiliary key exists in the main key set or
  /// in another auxiliary key set.
  void setAuxiliaryKeysForMainKeyAndValue(K key, V value) {
    for (final auxiliaryKeyMap in _auxiliaryKeyMaps) {
      final auxiliaryKey =
          auxiliaryKeyMap.generateAuxiliaryKeyFromMainKeyAndValue(key, value);
      if (checkAuxiliaryKeys) {
        if (keys.contains(auxiliaryKey) || key == auxiliaryKey) {
          throw DynCacheAuxKeyCollisionException(
              'Auxiliary key $auxiliaryKey from ${auxiliaryKeyMap.id} using main key $key and value $value conflicts with the main keys');
        }
        for (final internalAuxiliaryKeyMap in _auxiliaryKeyMaps) {
          if (internalAuxiliaryKeyMap.containsKey(auxiliaryKey)) {
            throw DynCacheAuxKeyCollisionException(
                'Auxiliary key $auxiliaryKey from ${auxiliaryKeyMap.id} using main key $key and value $value conflicts with auxiliary key manager ${internalAuxiliaryKeyMap.id}');
          }
        }
      }
      auxiliaryKeyMap.associateAuxiliaryKeyWithMainKey(auxiliaryKey, key);
    }
  }

  /// Given a main key-value pair, get associated auxiliary keys from valid
  /// [AuxiliaryKeyManager]s
  Iterable<dynamic> getAuxiliaryKeysForMainKeyAndValue(K key, V? value) sync* {
    for (final auxiliaryKeyMap in _auxiliaryKeyMaps) {
      if (value != null || !auxiliaryKeyMap.needsValue) {
        final auxiliaryKey =
            auxiliaryKeyMap.generateAuxiliaryKeyFromMainKeyAndValue(key, value);
        yield auxiliaryKey;
      }
    }
  }

  /// Given a main key-value pair, remove associated
  /// keys from all [AuxiliaryKeyManager]
  void removeAuxiliaryKeysForMainKeyAndValue(K key, V value) {
    for (final auxiliaryKeyMap in _auxiliaryKeyMaps) {
      final auxiliaryKey =
          auxiliaryKeyMap.generateAuxiliaryKeyFromMainKeyAndValue(key, value);
      auxiliaryKeyMap.removeAuxiliaryKey(auxiliaryKey);
    }
  }

  /// Given some auxiliary key and value, generate the associated main key.
  ///
  /// The first [AuxiliaryKeyManager] that can handle the [Type] of [key]
  /// returns the main key from [AuxiliaryKeyManager.generateMainKeyFromAuxiliaryKeyAndValue].
  ///
  /// throws [DynCacheAuxKeyCollisionException] if [checkAuxiliaryKeys] is
  /// `true` and a generated main key exists in the main key set or
  /// in another auxiliary key set.
  K generateNewMainKeyFromAuxiliaryKeyAndValue(dynamic key, V value) {
    for (final auxiliaryKeyMap in _auxiliaryKeyMaps) {
      if (auxiliaryKeyMap.canHandleAuxiliaryKey(key)) {
        try {
          final mainKey = auxiliaryKeyMap
              .generateMainKeyFromAuxiliaryKeyAndValue(key, value);
          if (checkAuxiliaryKeys) {
            if (keys.contains(mainKey) || key == mainKey) {
              throw DynCacheAuxKeyCollisionException(
                  'Main key $mainKey from ${auxiliaryKeyMap.id} using auxiliary key $key and value $value conflicts with the main keys');
            }
            for (final internalAuxiliaryKeyMap in _auxiliaryKeyMaps) {
              if (internalAuxiliaryKeyMap.containsKey(mainKey)) {
                throw DynCacheAuxKeyCollisionException(
                    'Main key $mainKey from ${auxiliaryKeyMap.id} using auxiliary key $key and value $value conflicts with auxiliary key manager ${internalAuxiliaryKeyMap.id}');
              }
            }
          }
          return mainKey;
        } on Exception {
          continue;
        }
      }
    }
    throw DynCacheTypeException('Auxiliary key $key cannot be handled.');
  }

  /// Given some auxiliary key and value, generate the associated main key.
  ///
  /// The first [AuxiliaryKeyManager] that can handle the [Type] of [key]
  /// and [AuxiliaryKeyManager.valueNeeded] is `false` is used.
  ///
  /// throws [DynCacheAuxKeyCollisionException] if [checkAuxiliaryKeys] is
  /// `true` and a generated main key exists in the main key set or
  /// in another auxiliary key set.
  K? generateNewMainKeyFromAuxiliaryKey(dynamic key) {
    bool validKey = false;
    for (final auxiliaryKeyMap in _auxiliaryKeyMaps) {
      if (auxiliaryKeyMap.canHandleAuxiliaryKey(key)) {
        validKey = true;
        if (!auxiliaryKeyMap.needsValue) {
          try {
            final mainKey = auxiliaryKeyMap
                .generateMainKeyFromAuxiliaryKeyAndValue(key, null);
            return mainKey;
          } on Exception {
            continue;
          }
        }
      }
    }
    if (!validKey) throw DynCacheTypeException('key $key cannot be handled.');
    return null;
  }

  @override
  int get length => _internalStorage.length;
  @override
  Iterable<K> get keys => _internalStorage.keys;
  @override
  Iterable<V> get values => _internalStorage.values.map((e) => e._value);
  @override
  Iterable<MapEntry<K, V>> get entries =>
      _internalStorage.entries.map((e) => MapEntry(e.key, e.value._value));

  Iterable<dynamic> auxKeysForHandlerAtIndex(int index) sync* {
    yield* _auxiliaryKeyMaps[index].keys;
  }

  Iterable<MapEntry<dynamic, V>> entriesForHandlerAtIndex(int index) sync* {
    final auxKeyMap = _auxiliaryKeyMaps[index];
    for (final entry in auxKeyMap.entries) {
      final auxKey = entry.key;
      final mainKey = entry.value;
      yield MapEntry(auxKey, _internalStorage[mainKey]!._value);
    }
  }

  /// Returns the value associated with [key], if any.
  @override
  V? get(dynamic key, {bool throwOnUnsafe = true});

  /// Associates [key] with [value].
  ///
  /// Removes the lightest entry if [cacheCapacity] is reached, no matter the
  /// [entryWeight] of [value].
  @override
  void set(dynamic key, V value);

  /// Removes the value associated with [key] and returns it.
  @override
  V? remove(dynamic key);
}

//kralverde (c) 2023
