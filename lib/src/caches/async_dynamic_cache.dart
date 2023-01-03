part of dart_dyncache;

/// A wrapper for a [BaseDynamicCache] that implements [DynamicCache] and
/// natively supports [Future] values.
class AsyncBasicDynamicCache<K, V> implements DynamicCache<K, V> {
  late BaseDynamicCache<K, V> _wrappedCache;
  final _waitingOnMap = <dynamic, List<Future<V>>>{};
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
      _waitingOnMap.containsKey(key);

  /// Waits for all future values passed into [setAsync] to complete.
  Future<void> awaitAllCurrentFutureValues() async {
    await Future.wait(_waitingOnMap.values.expand((element) => element));
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
  /// If [setAsync] is called after [getAsync], the new future will not be awaited.
  Future<V?> getAsync(dynamic key) async {
    V? futureValue;
    if (_waitingOnMap.containsKey(key)) {
      final results = await Future.wait(_waitingOnMap[key]!);
      futureValue ??= results.last;
    }
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
    _waitingOnMap[key]?.forEach((element) {
      element.then((value) => _wrappedCache.remove(key));
    });
    return _wrappedCache.remove(key);
  }

  List<Future<V>> _futureSetForKey(dynamic key) {
    return _waitingOnMap.putIfAbsent(key, () => []);
  }

  void _removeFutureForKey(dynamic key, Future<V> future) {
    final keySet = _waitingOnMap[key];
    keySet?.remove(future);
    if (keySet?.isEmpty ?? false) {
      _waitingOnMap.remove(key);
    }
  }

  /// Associates [key] with the future result of [value].
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
      _futureSetForKey(key).add(completer.future);
      final auxKeys =
          _wrappedCache.getAuxiliaryKeysForMainKeyAndValue(key, null);
      for (final auxKey in auxKeys) {
        _futureSetForKey(auxKey).add(completer.future);
      }
      _waitingOnCount++;
      value.then((value) {
        set(key, value);
        _removeFutureForKey(key, completer.future);
        for (final auxKey in auxKeys) {
          _removeFutureForKey(auxKey, completer.future);
        }
        completer.complete(value);
        _waitingOnCount--;
      });
      return;
    }
    final mainKey = _wrappedCache.getMainKeyFromAuxiliaryKey(key, true);
    if (mainKey != null) {
      _futureSetForKey(mainKey).add(completer.future);
      final auxKeys =
          _wrappedCache.getAuxiliaryKeysForMainKeyAndValue(mainKey, null);
      for (final auxKey in auxKeys) {
        _futureSetForKey(auxKey).add(completer.future);
      }
      _waitingOnCount++;
      value.then((value) {
        set(mainKey, value);
        _removeFutureForKey(mainKey, completer.future);
        for (final auxKey in auxKeys) {
          _removeFutureForKey(auxKey, completer.future);
        }
        completer.complete(value);
        _waitingOnCount--;
      });
      return;
    }

    // New insertion
    if (key is K) {
      _futureSetForKey(key).add(completer.future);
      final auxKeys =
          _wrappedCache.getAuxiliaryKeysForMainKeyAndValue(key, null);
      for (final auxKey in auxKeys) {
        _futureSetForKey(auxKey).add(completer.future);
      }
      _waitingOnCount++;
      value.then((value) {
        set(key, value);
        _removeFutureForKey(key, completer.future);
        for (final auxKey in auxKeys) {
          _removeFutureForKey(auxKey, completer.future);
        }
        completer.complete(value);
        _waitingOnCount--;
      });
    } else {
      _futureSetForKey(key).add(completer.future);
      final otherKeys = <dynamic>{};
      final maybeMainKey =
          _wrappedCache.generateNewMainKeyFromAuxiliaryKey(key);
      if (maybeMainKey != null) {
        otherKeys.add(maybeMainKey);
        otherKeys.addAll(_wrappedCache.getAuxiliaryKeysForMainKeyAndValue(
            maybeMainKey, null));
      }
      for (final key in otherKeys) {
        _futureSetForKey(key).add(completer.future);
      }
      _waitingOnCount++;
      value.then((value) {
        final mainKey = _wrappedCache
            .generateNewMainKeyFromAuxiliaryKeyAndValue(key, value);
        set(mainKey, value);
        _removeFutureForKey(key, completer.future);
        for (final key in otherKeys) {
          _removeFutureForKey(key, completer.future);
        }
        completer.complete(value);
        _waitingOnCount--;
      });
    }
  }
}

//kralverde (c) 2023
