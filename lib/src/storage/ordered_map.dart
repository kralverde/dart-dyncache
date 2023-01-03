part of dart_dyncache;

class _OrderedMapEntry<K, V> {
  final K _key;
  V _value;

  _OrderedMapEntry(this._key, this._value);
}

/// An implementation of [OrderedStorage] using a sorted array and a key-to-index map.
class OrderedMap<K, V> extends OrderedStorage<K, V> {
  final _keyMap = <K, int>{};
  final _sortedEntries = <_OrderedMapEntry<K, V>>[];

  OrderedMap({required super.entryWeight});

  _OrderedMapEntry<K, V> _shiftEntriesForExisting(int index) {
    final entry = _sortedEntries[index];
    int compareIndex = index - 1;
    while (compareIndex >= 0 &&
        entryWeight(entry._key, entry._value) >
            entryWeight(_sortedEntries[compareIndex]._key,
                _sortedEntries[compareIndex]._value)) {
      // Shift down
      _sortedEntries[compareIndex + 1] = _sortedEntries[compareIndex];
      _keyMap[_sortedEntries[compareIndex]._key] = compareIndex + 1;
      compareIndex--;
    }
    _sortedEntries[compareIndex + 1] = entry;
    _keyMap[entry._key] = compareIndex + 1;
    return entry;
  }

  void _shiftEntriesForNew(_OrderedMapEntry<K, V> entry) {
    int compareIndex = _sortedEntries.length - 1;
    _sortedEntries.add(entry); // Temp add so can shift down by indexing
    while (compareIndex >= 0 &&
        entryWeight(entry._key, entry._value) >=
            entryWeight(_sortedEntries[compareIndex]._key,
                _sortedEntries[compareIndex]._value)) {
      // Shift down
      _sortedEntries[compareIndex + 1] = _sortedEntries[compareIndex];
      _keyMap[_sortedEntries[compareIndex]._key] = compareIndex + 1;
      compareIndex--;
    }
    _sortedEntries[compareIndex + 1] = entry;
    _keyMap[entry._key] = compareIndex + 1;
  }

  @override
  V? operator [](Object? key) {
    final index = _keyMap[key];
    if (index == null) return null;
    final entry = _shiftEntriesForExisting(index);
    return entry._value;
  }

  @override
  void operator []=(K key, V value) {
    if (containsKey(key)) {
      final index = _keyMap[key]!;
      final entry = _sortedEntries[index];
      entry._value = value;
      _shiftEntriesForExisting(index);
    } else {
      final entry = _OrderedMapEntry(key, value);
      _shiftEntriesForNew(entry);
    }
  }

  @override
  void addAll(Map<K, V> other) => addEntries(other.entries);

  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    for (final entry in newEntries) {
      this[entry.key] = entry.value;
    }
  }

  @override
  Map<RK, RV> cast<RK, RV>() {
    final newMap = <RK, RV>{};
    for (final entry in entries) {
      newMap[entry.key as RK] = entry.value as RV;
    }
    return newMap;
  }

  @override
  void clear() {
    _keyMap.clear();
    _sortedEntries.clear();
  }

  @override
  bool containsKey(Object? key) => _keyMap.containsKey(key);

  @override
  bool containsValue(Object? value) => _sortedEntries.contains(value);

  @override
  Iterable<MapEntry<K, V>> get entries => () sync* {
        for (final entry in _keyMap.entries) {
          final key = entry.key;
          final index = entry.value;
          final value = _sortedEntries[index]._value;
          yield MapEntry(key, value);
        }
      }();

  @override
  void forEach(void Function(K key, V value) action) {
    for (final entry in entries) {
      action(entry.key, entry.value);
    }
  }

  @override
  bool get isEmpty => _keyMap.isEmpty;

  @override
  bool get isNotEmpty => _keyMap.isNotEmpty;

  @override
  Iterable<K> get keys => _keyMap.keys;

  @override
  int get length => _keyMap.length;

  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) convert) {
    return Map.fromEntries(() sync* {
      for (final entry in entries) {
        yield convert(entry.key, entry.value);
      }
    }());
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    if (containsKey(key)) {
      return this[key]!;
    }
    final value = ifAbsent();
    this[key] = value;
    return value;
  }

  @override
  V? remove(Object? key) {
    int? index = _keyMap.remove(key);
    if (index == null) return null;
    final entry = _sortedEntries[index];

    // Shift up
    while (index! < _sortedEntries.length - 1) {
      _sortedEntries[index] = _sortedEntries[index + 1];
      _keyMap[_sortedEntries[index]._key] = index;
      index++;
    }
    _sortedEntries.removeLast();
    return entry._value;
  }

  @override
  MapEntry<K, V>? removeHeaviestEntry() {
    if (_sortedEntries.isEmpty) return null;
    int index = 0;
    final entry = _sortedEntries[index];
    // Shift up
    while (index < _sortedEntries.length - 1) {
      _sortedEntries[index] = _sortedEntries[index + 1];
      _keyMap[_sortedEntries[index]._key] = index;
      index++;
    }
    _sortedEntries.removeLast();
    _keyMap.remove(entry._key);
    return MapEntry(entry._key, entry._value);
  }

  @override
  MapEntry<K, V>? removeLightestEntry() {
    if (_sortedEntries.isEmpty) return null;
    final entry = _sortedEntries.removeLast();
    _keyMap.remove(entry._key);
    return MapEntry(entry._key, entry._value);
  }

  @override
  Iterable<MapEntry<K, V>> removeNHeaviestEntries(int count) {
    count = min(count, _sortedEntries.length);
    final removed = _sortedEntries.sublist(0, count);
    int index = 0;
    while (index < _sortedEntries.length - count) {
      _sortedEntries[index] = _sortedEntries[index + count];
      _keyMap[_sortedEntries[index]._key] = index;
      index++;
    }
    _sortedEntries.removeRange(
        _sortedEntries.length - count, _sortedEntries.length);
    for (final entry in removed) {
      _keyMap.remove(entry._key);
    }
    return removed.map((e) => MapEntry(e._key, e._value));
  }

  @override
  Iterable<MapEntry<K, V>> removeNLightestEntries(int count) {
    count = min(count, _sortedEntries.length);
    final removed = _sortedEntries.sublist(
        _sortedEntries.length - count, _sortedEntries.length);
    _sortedEntries.removeRange(
        _sortedEntries.length - count, _sortedEntries.length);
    for (final entry in removed) {
      _keyMap.remove(entry._key);
    }
    return removed.map((e) => MapEntry(e._key, e._value));
  }

  @override
  void removeWhere(bool Function(K key, V value) test) {
    final removeSet = <K>{};
    for (final entry in entries) {
      if (test(entry.key, entry.value)) {
        removeSet.add(entry.key);
      }
    }
    removeSet.forEach(remove);
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final index = _keyMap[key];
    if (index == null) {
      final newValue = ifAbsent!();
      this[key] = newValue;
      return newValue;
    }
    final entry = _sortedEntries[index];
    final newValue = update(entry._value);
    entry._value = newValue;
    _shiftEntriesForExisting(index);
    return newValue;
  }

  @override
  void updateAll(V Function(K key, V value) update) {
    for (final entry in _sortedEntries) {
      entry._value = update(entry._key, entry._value);
    }
  }

  @override
  Iterable<V> get values => _sortedEntries.map((e) => e._value);
}

//kralverde (c) 2023
