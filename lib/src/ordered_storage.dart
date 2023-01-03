part of dart_dyncache;

typedef StorageWeightFunction<K, V> = double Function(K key, V value);

/// A class that keeps a weighted [K]-[V] pairing.
abstract class OrderedStorage<K, V> implements Map<K, V> {
  /// The weight of an entry given its key and value.
  StorageWeightFunction<K, V> entryWeight;

  OrderedStorage({required this.entryWeight});

  /// Removes the entry with the largest [entryWeight].
  MapEntry<K, V>? removeHeaviestEntry();

  /// Removes N entries which have the largest [entryWeight].
  Iterable<MapEntry<K, V>> removeNHeaviestEntries(final int count);

  /// Removes the entry with the lowest [entryWeight].

  MapEntry<K, V>? removeLightestEntry();

  /// Removes N entries which have the lowest [entryWeight].

  Iterable<MapEntry<K, V>> removeNLightestEntries(final int count);

  /// Returns the values of this storaged sorted from greatest weight to
  /// lowest weight as defined by [entryWeight].
  ///
  /// If two elements have the same weight, the insertion order is the tie breaker.
  /// The newer element should be before the older element.
  @override
  Iterable<V> get values;
}

//kralverde (c) 2023
