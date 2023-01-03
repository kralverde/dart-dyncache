part of dart_dyncache;

/// A wrapper for a [BaseDynamicCache] that implements [DynamicCache] and
/// natively supports [Future] values.
class AsyncBasicDynamicCache<K, V> implements DynamicCache<K, V> {
  late BaseDynamicCache<K, V> _wrappedCache;

  final _waitingForMap = <dynamic, Set<Future<V>>>{};
  int _waitingOnCount = 0;

  AsyncBasicDynamicCache(final BaseDynamicCache<K, V> wrappedCache) {
    _wrappedCache = wrappedCache;
  }

  /// [getAsync] should be used instead.
  ///
  /// This function will miss for all future values passed into [setAsync]
  /// that have not yet completed.
  @override
  V? get(dynamic key, {bool throwOnUnsafe = true}) {
    if (throwOnUnsafe) {
      throw DynCacheUnsafeException(
          'Consider using `getAsync`. If you know what you are doing, set `throwOnUnsafe` to `false`');
    }
    return _wrappedCache.get(key);
  }

  /// Returns true if this key is associated with a future value.
  bool doesKeyHaveAssociatedFuture(dynamic key) =>
      _waitingForMap.containsKey(key);

  /// Waits for all future values passed into [setAsync] to complete.
  Future<void> awaitAllCurrentFutureValues() async {
    await Future.wait(_waitingForMap.values.expand((element) => element));
  }

  /// The current count of futures passed into [setAsync] that have not completed.
  int get waitingOnCount => _waitingOnCount;

  @override
  int get cacheCapacity => _wrappedCache.cacheCapacity;

  @override
  get keys => _wrappedCache.keys;

  @override
  get values => _wrappedCache.values;

  @override
  get entries => _wrappedCache.entries;

  @override
  get length => _wrappedCache.length;

  @override
  get onEvict => _wrappedCache.onEvict;

  @override
  get hits => _wrappedCache.hits;

  @override
  set hits(int newHits) => _wrappedCache.hits = newHits;

  @override
  get misses => _wrappedCache.misses;

  @override
  set misses(int newMisses) => _wrappedCache.misses = newMisses;

  @override
  bool containsKey(dynamic key) => _wrappedCache.containsKey(key);

  /// If [key] is known to be associated with a future value, this method waits
  /// until that future is completed.
  ///
  /// If [key] is an auxiliary key and the associated [AuxiliaryKeyManager.valueNeeded]
  /// is `true`, or if [setAsync] was called with an auxiliary [key] who's associated
  /// [AuxiliaryKeyManager.valueNeeded] is `true` this method will miss even
  /// if the future is known.
  ///
  /// If [setAsync] is called for [key] while [getAsync] is waiting, it will not be
  /// caught by the waiting [getAsync]
  Future<V?> getAsync(dynamic key) async {
    V? futureValue;
    if (_waitingForMap.containsKey(key)) {
      final futures = <Future<void>>[];
      for (final future in _waitingForMap[key]!) {
        futures.add(future.then((value) => futureValue = value));
      }
      await Future.wait(futures);
    }
    // Incase this element is removed in between the future completion and the
    // get; the future we are awaiting is the internal completer, not the
    // actual passed in future.
    return get(key, throwOnUnsafe: false) ?? futureValue;
  }

  @override
  void clear() => _wrappedCache.clear();

  @override
  void set(dynamic key, V value) => _wrappedCache.set(key, value);

  /// If a value exists in the cache for [key], returns that value.
  ///
  /// Removes associated futures with [key] as soon as then complete.
  @override
  V? remove(dynamic key) {
    _waitingForMap[key]?.forEach((element) {
      element.then((value) => _wrappedCache.remove(key));
    });
    _waitingForMap.remove(key);
    return _wrappedCache.remove(key);
  }

  void _setFutureForKeys(Iterable<dynamic> keys, Future<V> future) {
    for (final key in keys) {
      _waitingForMap.putIfAbsent(key, () => {}).add(future);
    }
  }

  void _removeFutureForKeys(Iterable<dynamic> keys, Future<V> future) {
    for (final key in keys) {
      final cache = _waitingForMap[key]!;
      cache.remove(future);
      if (cache.isEmpty) {
        _waitingForMap.remove(key);
      }
    }
  }

  /// Associates [key] with the future result of [value].
  ///
  /// The [Future] that completes last will be the value that is reflected.
  ///
  /// If [key] is a main key, calling [getAsync] with [key] or any derived
  /// auxiliary key whose associated [AuxiliaryKeyManager.valueNeeded] is `false`
  /// will wait for [value] to complete.
  ///
  /// If [key] is an auxililary key and the associated [AuxiliaryKeyManager.valueNeeded]
  /// is `true`, [getAsync] will only await for [key], other associated main and
  /// auxiliary keys will miss.
  ///
  /// Any auxiliary key associated with [key] will miss with [getAsync] if
  /// the associated [AuxiliaryKeyManager.valueNeeded] is `true`.
  void setAsync(dynamic key, Future<V> value) {
    final completer = Completer<V>();
    if (keys.contains(key)) {
      final keySet = <dynamic>{};
      keySet.add(key);
      keySet
          .addAll(_wrappedCache.getAuxiliaryKeysForMainKeyAndValue(key, null));
      _setFutureForKeys(keySet, completer.future);
      _waitingOnCount++;
      value.then((value) {
        set(key, value);
        _removeFutureForKeys(keySet, completer.future);
        completer.complete(value);
        _waitingOnCount--;
      });
      return;
    }
    final mainKey = _wrappedCache.getMainKeyFromAuxiliaryKey(key, true);
    if (mainKey != null) {
      final keySet = <dynamic>{};
      keySet.add(key);
      keySet.add(mainKey);
      keySet.addAll(_wrappedCache
          .getAuxiliaryKeysForMainKeyAndValue(mainKey, null)
          .toSet());
      _setFutureForKeys(keySet, completer.future);
      _waitingOnCount++;
      value.then((value) {
        set(mainKey, value);
        _removeFutureForKeys(keySet, completer.future);
        completer.complete(value);
        _waitingOnCount--;
      });
      return;
    }

    // New insertion
    if (key is K) {
      final keySet = <dynamic>{};
      keySet.add(key);
      keySet
          .addAll(_wrappedCache.getAuxiliaryKeysForMainKeyAndValue(key, null));
      _setFutureForKeys(keySet, completer.future);
      _waitingOnCount++;
      value.then((value) {
        set(key, value);
        _removeFutureForKeys(keySet, completer.future);
        completer.complete(value);
        _waitingOnCount--;
      });
    } else {
      final keySet = <dynamic>{};
      keySet.add(key);
      final maybeMainKey =
          _wrappedCache.generateNewMainKeyFromAuxiliaryKey(key);
      if (maybeMainKey != null) {
        keySet.add(maybeMainKey);
        keySet.addAll(_wrappedCache.getAuxiliaryKeysForMainKeyAndValue(
            maybeMainKey, null));
      }
      _setFutureForKeys(keySet, completer.future);
      _waitingOnCount++;
      value.then((value) {
        final mainKey = _wrappedCache
            .generateNewMainKeyFromAuxiliaryKeyAndValue(key, value);
        set(mainKey, value);
        _removeFutureForKeys(keySet, completer.future);
        completer.complete(value);
        _waitingOnCount--;
      });
    }
  }
}

//kralverde (c) 2023
