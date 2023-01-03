part of dart_dyncache;

/// A basic implementation of [BaseDynamicCache].
class SimpleDynamicCache<K, V> extends BaseDynamicCache<K, V> {
  SimpleDynamicCache(super.cacheCapacity,
      {required super.entryWeight,
      super.onEvict,
      super.insertWeight = 0,
      super.updateWeight = 0,
      super.lookupWeight = 1,
      required super.storageGenerator,
      super.checkAuxiliaryKeys = true,
      super.auxiliaryKeyManagers});

  /// Get the value associated with [key].
  ///
  /// If [key] exists in the cache, [lookupWeight] is added to the entry
  /// access weight and [hits] is incremented by 1.
  ///
  /// If [key] does not exist in the cache, [misses] is incremented by 1.
  ///
  /// If [key] is an auxiliary key, the main key is queried from
  /// the [AuxiliaryKeyManager]s.
  ///
  /// The internal [OrderedStorage] is then
  /// queried directly.
  ///
  /// If [key] is not of type [K] and cannot be handled by the
  /// [AuxiliaryKeyManager]s, a [DynCacheTypeException] is thrown.
  ///
  /// [throwOnUnsafe] is ignored.
  @override
  V? get(key, {bool throwOnUnsafe = true}) {
    if (keys.contains(key)) {
      hits++;
      return getValueForMainKey(key);
    }
    final mainKey = getMainKeyFromAuxiliaryKey(key, false);
    if (mainKey != null) {
      // Main key exists -> value exists
      hits++;
      return getValueForMainKey(mainKey);
    }
    misses++;
    return null;
  }

  /// Removes the key-value pair associated with [key] from the cache and
  /// returns the associated value.
  ///
  /// If [key] is an auxiliary key, the main key is queried from
  /// the [AuxiliaryKeyManager]s.
  ///
  /// The internal [OrderedStorage] is then queried directly.
  ///
  /// If [key] is not of type [K] and cannot be handled by the
  /// [AuxiliaryKeyManager]s, a [DynCacheTypeException] is thrown.
  @override
  V? remove(key) {
    if (keys.contains(key)) {
      final value = removeValueForMainKey(key);
      if (value != null) {
        removeAuxiliaryKeysForMainKeyAndValue(key, value);
        return value;
      }
    }
    final mainKey = getMainKeyFromAuxiliaryKey(key, false);
    if (mainKey != null) {
      final value = removeValueForMainKey(mainKey);
      if (value != null) {
        removeAuxiliaryKeysForMainKeyAndValue(mainKey, value);
        return value;
      }
    }
    return null;
  }

  /// Associate [key] with [value] in the cache.
  ///
  /// If [key] exists in the cache, the value of the entry is updated to [value]
  /// and [updateWeight] is added to the entry access weight.
  ///
  /// If [key] does not exist in the cache, [key] is inserted into the cache
  /// with [value] and the entry access weight is initialized to [insertWeight].
  ///
  /// If [key] is of type [K] is is inserted as a main key. Otherwise, it is
  /// converted to a main key by the first [AuxiliaryKeyManager] that can handle
  /// the [Type] of [key].
  ///
  /// If [length] is greater than [cacheCapacity], the lowest weighted
  /// entry is removed from the internal [OrderedStorage].
  ///
  /// If [key] is not of type [K] and cannot be handled by the
  /// [AuxiliaryKeyManager]s, a [DynCacheTypeException] is thrown.
  @override
  void set(key, V value) {
    if (length >= cacheCapacity) {
      removeNLightestEntries(length - cacheCapacity + 1);
    }
    if (keys.contains(key)) {
      updateValueForMainKey(key, value);
      return;
    }
    final mainKey = getMainKeyFromAuxiliaryKey(key, true);
    if (mainKey != null) {
      updateValueForMainKey(mainKey, value);
      return;
    }
    // New insertion
    if (key is K) {
      setValueForMainKey(key, value);
      try {
        setAuxiliaryKeysForMainKeyAndValue(key, value);
      } on DynCacheAuxKeyCollisionException {
        removeValueForMainKey(key);
        rethrow;
      }
    } else {
      final mainKey = generateNewMainKeyFromAuxiliaryKeyAndValue(key, value);
      setValueForMainKey(mainKey, value);
      try {
        setAuxiliaryKeysForMainKeyAndValue(mainKey, value);
      } on DynCacheAuxKeyCollisionException {
        removeValueForMainKey(mainKey);
        rethrow;
      }
    }
  }
}

//kralverde (c) 2023
