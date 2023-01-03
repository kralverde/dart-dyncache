part of dart_dyncache;

/// A Dynamic cache using a First In First Out implementation.
class FIFODynamicCache<K, V> extends SimpleDynamicCache<K, V> {
  FIFODynamicCache(super.cacheCapacity,
      {super.onEvict,
      required super.storageGenerator,
      super.checkAuxiliaryKeys = true,
      super.auxiliaryKeyManagers})
      : super(entryWeight: (ignored1, ignored2, ignored3, ignored4) => 0);
}

/// A Dynamic cache using a Least Frequently Used implementation.
class LFUDynamicCache<K, V> extends SimpleDynamicCache<K, V> {
  LFUDynamicCache(super.cacheCapacity,
      {super.onEvict,
      required super.storageGenerator,
      super.checkAuxiliaryKeys = true,
      super.auxiliaryKeyManagers})
      : super(
            entryWeight: (ignored1, ignored2, accessWeight, ignored3) =>
                accessWeight);
}

/// A Dynamic cache using a Least Recently Used implementation.
class LRUDynamicCache<K, V> extends SimpleDynamicCache<K, V> {
  LRUDynamicCache(super.cacheCapacity,
      {super.onEvict,
      required super.storageGenerator,
      super.checkAuxiliaryKeys = true,
      super.auxiliaryKeyManagers})
      : super(
            entryWeight: (ignored1, ignored2, ignored3, queriesSinceLastHit) =>
                -queriesSinceLastHit.toDouble());
}

//kralverde (c) 2023
