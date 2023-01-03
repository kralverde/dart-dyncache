# DynCache

DynCache is an attempt a dynamic and flexible library for all caching needs in `dart`.

DynCache is intended to store the results of resource or time intensive methods like database queries. 
Elements in the cache are garbage collected immediately when evicted from the cache. (e.g. calling `set`
when the `length` == `cacheCapacity`).

## Features

* Ordered storage (weighted key-value pairs)
* A cache implementation that supports eviction call backs, custom entry weight, and auxiliary keys
* Implementations of FIFO, LRU, and LFU caches

## Auxiliary Keys

When caching objects, you may want to query the same object using two distinct keys. When initializing
a cache, you have the option of adding `AuxiliaryKeyManager`s; a way to map one key to another.

The set of all possible auxiliary keys from a given `AuxiliaryKeyManager` should not intersect with
the set of all possible main keys. There should be a 1-1 mapping between main keys and auxiliary keys.
The main key should be recoverable given the auxiliary key and value and vice-versa.

## Usage

### Basic Cache Usage
```dart
final cache = FIFODynamicCache<int, String>(10,
    storageGenerator: <K, V>(entryWeight) =>
        OrderedMap(entryWeight: entryWeight));

cache.set(1, 'val1');
cache.get(1); // 'val1'
cache.get(2); // null

for (int i = 10; i < 20; i++) {
    cache.set(i, 'val$i');
}
cache.get(1); // null
```

### A LFRU Cache Implementation
```dart
final cache = FIFODynamicCache<int, String>(10,
    entryWeight: (key, value, accessWeight, accessesSinceLastHit) => accessWeight - (accessesSinceLastHit / 1000),
    storageGenerator: <K, V>(entryWeight) =>
        OrderedMap(entryWeight: entryWeight));
```

### Auxiliary Key Mapping
```dart
final manager = AuxiliaryKeyManager<String, int, String>(
    generateAuxiliaryKeyFromMainKeyAndValue: (mainKey, value) =>
        '$mainKey',
    generateMainKeyFromAuxiliaryKeyAndValue: (auxiliaryKey, value) =>
        int.parse(auxiliaryKey));

final cache = FIFODynamicCache<int, String>(10,
    storageGenerator: <K, V>(entryWeight) =>
        OrderedMap(entryWeight: entryWeight),
    auxiliaryKeyManagers: [manager]);

cache.set(1, 'val1');
cache.get(1);   // 'val1'
cache.get('1'); // 'val1'

cache.set('2', 'val2');
cache.get(2);   // 'val2'
cache.get('2'); // 'val2'
```

### On Eviction Callbacks
```dart
void callback(int key, String value) {
    print('$key:$value');
}

final cache = FIFODynamicCache<int, String>(10,
    storageGenerator: <K, V>(entryWeight) =>
        OrderedMap(entryWeight: entryWeight),
    onEvict: callback);

cache.set(1, 'val1');
cache.remove(1); // >'1:val1'

cache.set(2, 'val2');
for (int i = 3; i < 11; i++) {
    cache.set(i, '');
}
// >'2:val2'
```

See the `/example` folder for more in-depth commented cases. 

