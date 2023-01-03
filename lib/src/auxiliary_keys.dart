part of dart_dyncache;

/// A class used to manage conversions between a main key of type [KO] and
/// an auxiliary key of type [KA].
///
/// [KA] is required to implement `operator==` and `hashCode` as if it were
/// a key in a standard [Map].
///
/// Auxiliary key associations work as follows:
///    +-->[AuxiliaryKeyManager.generateAuxiliaryKeyFromMainKeyAndValue]--+
///    |                                                                  V
/// (Main Key)                                                  (Auxiliary Key)
///    ^                                                                  V
///    +-[AuxiliaryKeyManager.generateMainKeyFromAuxiliaryKeyAndValue]----+
///
/// Auxiliary keys associate with other auxiliary keys through the associated
/// main key.
class AuxiliaryKeyManager<KA, KO, V> {
  static int _uniqueId = 0;

  /// An identifier for debugging purposes.
  late String identifier;

  /// A function to generate an auxiliary key based on a main key-value pair.
  ///
  /// If [valueNeeded] is `false`, `value` will be `null`. Otherwise, `value`
  /// is the value of the main key-value pair.
  ///
  /// There SHALL be a one-to-one correspondence between the set of main keys
  /// and the set of auxiliary keys and the result of this function SHALL
  /// be reversable given the same `value` to the main key.
  ///
  /// The auxiliary keys generated should be unique; no two [AuxiliaryKeyManager]
  /// should be able to generate any of the same keys.
  ///
  /// For example:
  /// ```dart
  /// String (int mainKey, V? value) => '$originalKey';
  /// ```
  /// or
  /// ```dart
  /// String (int mainKey, V? value) => value.aUniqueString;
  /// ```
  /// are valid functions while
  /// ```dart
  /// String (int mainKey, V? value) => 'thisIsTheSameString';
  /// ```
  /// or
  /// ```dart
  /// int (int mainKey, V? value) => someGlobalInt++;
  /// ```
  /// are invalid.
  final KA Function(KO mainKey, V? value)
      generateAuxiliaryKeyFromMainKeyAndValue;

  late KO Function(KA auxiliaryKey, V? value)
      _generateMainKeyFromAuxiliaryKeyAndValue;

  /// If false, the `value` input into [generateAuxiliaryKeyFromMainKeyAndValue]
  /// and [generateMainKeyFromAuxiliaryKeyAndValue] will be null.
  final bool valueNeeded;

  AuxiliaryKeyManager(
      {required this.generateAuxiliaryKeyFromMainKeyAndValue,
      required KO Function(KA auxiliaryKey, V? value)
          generateMainKeyFromAuxiliaryKeyAndValue,
      this.valueNeeded = true,
      String? id}) {
    identifier = id ?? 'aux_${_uniqueId++}';
    _generateMainKeyFromAuxiliaryKeyAndValue =
        generateMainKeyFromAuxiliaryKeyAndValue;
  }

  /// A function to generate a main key based on an auxiliary key-value pair.
  ///
  /// If [valueNeeded] is `false`, `value` will be `null`. Otherwise, `value`
  /// is the value of the auxiliary key-value pair.
  ///
  /// There SHALL be a one-to-one correspondence between the set of main keys
  /// and the set of auxiliary keys and the result of this function SHALL
  /// be reversable given the same `value` to the auxiliary key.
  ///
  /// For example:
  /// ```dart
  /// int (String auxiliaryKey, V? value) => Int.parse(auxiliaryKey);
  /// ```
  /// or
  /// ```
  /// int (String auxiliaryKey, V? value) => value.theOriginalKey;
  /// ```
  /// are valid functions while
  /// ```dart
  /// int (String auxiliaryKey, V? value) => 0;
  /// ```
  /// or
  /// ```dart
  /// int (int auxiliaryKey, V? value) => someGlobalInt++;
  /// ```
  /// are invalid.
  KO generateMainKeyFromAuxiliaryKeyAndValue(dynamic auxiliaryKey, V? value) =>
      _generateMainKeyFromAuxiliaryKeyAndValue(auxiliaryKey as KA, value);

  /// Returns `true` if [key] is the same type as an auxiliary key.
  bool canHandleAuxiliaryKey(Object? key) => key is KA;
}

//kralverde (c) 2023
