//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// Modifications made by James Brown on October 18, 2024.
//
// - Added conditional import of Foundation.
//
// - Modified JSONReference.Backing:
//    - case number(String)
//    - case array([JSONReference])
//    - case object([String: JSONReference])
//    - case nonPrettyDirectArray(String)
//    - case directArray([String])
//    + case int(Int)
//    + case float(Float)
//    + case double(Double)
//    + case directArray([Any])
//    + case array([ValueReference])
//    + case object([String: ValueReference])
//
// - Changed name JSONReference -> ValueReference
//      and made small adjustments to methods.
//
// - Adapted __JSONEncoder, _JSONEncodingStorage, _JSONKeyedEncodingContainer,
//    _JSONUnkeyedEncodingContainer, and implementation of SingleValueEncodingContainer
//    to encode to [String: Any] instead of JSON.
//
// - Implemented a very reduced version of the API.
//
//===----------------------------------------------------------------------===//

#if canImport(Foundation)
  import Foundation
#endif

public struct DictionaryEncoder: Sendable {
  private let encoder: _DictionaryEncoder
  public init() { self.encoder = _DictionaryEncoder(userInfo: [:]) }
  public func encode<T>(_ value: T) throws -> [String: Any] where T: Encodable {
    try encoder.encode(value)
  }
}

final class ValueReference {
  enum Backing {
    case int(Int)
    case float(Float)
    case double(Double)
    case string(String)
    case bool(Bool)
    case null
    case directArray([Any])
    case array([ValueReference])
    case object([String: ValueReference])
  }
  private(set) var backing: Backing

  @inline(__always) func insert(_ ref: ValueReference, for key: String) {
    guard case var .object(object) = backing else {
      preconditionFailure("Wrong underlying Value reference type")
    }
    backing = .null
    object[key] = ref
    backing = .object(object)
  }

  @inline(__always) func insert(_ ref: ValueReference, atIndex index: Int) {
    guard case var .array(array) = backing else {
      preconditionFailure("Wrong underlying ValueReference type")
    }
    backing = .null
    array.insert(ref, at: index)
    backing = .array(array)
  }

  @inline(__always) func insert(_ ref: ValueReference) {
    guard case var .array(array) = backing else {
      preconditionFailure("Wrong underlying ValueReference type")
    }
    backing = .null
    array.append(ref)
    backing = .array(array)
  }

  @inline(__always) var count: Int {
    switch backing {
    case .array(let array): return array.count
    case .object(let dict): return dict.count
    default: preconditionFailure("Count does not apply to count")
    }
  }

  @inline(__always) init(_ backing: Backing) { self.backing = backing }

  @inline(__always) subscript(key: String) -> ValueReference? {
    switch backing {
    case let .object(object): return object[key]
    default: preconditionFailure("Wrong underlying ValueReference type")
    }
  }

  @inline(__always) subscript(index: Int) -> ValueReference? {
    switch backing {
    case let .array(array): return array[index]
    default: preconditionFailure("Wrong underlying ValueReference type")
    }
  }

  @inline(__always) var isObject: Bool {
    guard case .object = backing else { return false }
    return true
  }

  @inline(__always) var isArray: Bool {
    guard case .array = backing else { return false }
    return true
  }

  static func _int(_ i: some FixedWidthInteger) -> ValueReference {
    .init(.int(Int(i)))
  }
  static func float(_ f: Float) -> ValueReference { .init(.float(f)) }
  static func double(_ d: Double) -> ValueReference { .init(.double(d)) }
  static func string(_ str: String) -> ValueReference { .init(.string(str)) }
  static func bool(_ b: Bool) -> ValueReference { b ? .true : .false }
  nonisolated(unsafe) static let `null`: ValueReference = .init(.null)
  nonisolated(unsafe) static let `true`: ValueReference = .init(.bool(true))
  nonisolated(unsafe) static let `false`: ValueReference = .init(.bool(false))

  static var emptyArray: ValueReference { .init(.array([])) }
  static var emptyObject: ValueReference { .init(.object([:])) }
}

internal struct _DictionaryEncodingStorage {
  // MARK: Properties
  var refs = [ValueReference]()

  // MARK: - Initialization

  /// Initializes `self` with no containers.
  init() {}

  // MARK: - Modifying the Stack

  var count: Int { self.refs.count }

  mutating func pushKeyedContainer() -> ValueReference {
    let object = ValueReference.emptyObject
    self.refs.append(object)
    return object
  }

  mutating func pushUnkeyedContainer() -> ValueReference {
    let array = ValueReference.emptyArray
    self.refs.append(array)
    return array
  }

  mutating func push(ref: __owned ValueReference) { self.refs.append(ref) }

  mutating func popReference() -> ValueReference {
    precondition(!self.refs.isEmpty, "Empty reference stack.")
    return self.refs.popLast().unsafelyUnwrapped
  }
}

private final class _DictionaryEncoder: Encoder, @unchecked Sendable {
  var userInfo: [CodingUserInfoKey: Any]
  var encoderCodingPathNode: _CodingPathNode
  var codingPathDepth: Int
  var storage: _DictionaryEncodingStorage
  var codingPath: [any CodingKey] { encoderCodingPathNode.path }

  init(
    userInfo: [CodingUserInfoKey: Any],
    encoderCodingPathNode: _CodingPathNode = .root,
    initialDepth: Int = 0
  ) {
    self.userInfo = userInfo
    self.encoderCodingPathNode = encoderCodingPathNode
    self.codingPathDepth = initialDepth
    self.storage = _DictionaryEncodingStorage()
  }

  /// Returns whether a new element can be encoded at this coding path.
  ///
  /// `true` if an element has not yet been encoded at this coding path; `false` otherwise.
  var canEncodeNewValue: Bool {
    // Every time a new value gets encoded, the key it's encoded for is pushed onto
    // the coding path (even if it's a nil key from an unkeyed container).
    // At the same time, every time a container is requested, a new value gets
    // pushed onto the storage stack.
    // If there are more values on the storage stack than on the coding path,
    // it means the value is requesting more than one container, which violates the precondition.
    //
    // This means that anytime something that can request a new container goes onto the stack,
    // we MUST push a key onto the coding path.
    // Things which will not request containers do not need to have the coding
    // path extended for them (but it doesn't matter if it is, because they will not reach here).
    self.storage.count == self.codingPathDepth
  }

  func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key>
  where Key: CodingKey {
    let topRef: ValueReference
    if canEncodeNewValue {
      topRef = self.storage.pushKeyedContainer()
    } else {
      guard let ref = storage.refs.last, ref.isObject else {
        preconditionFailure(
          "Attempt to push new keyed encoding container when already previously encoded at this path."
        )
      }
      topRef = ref
    }
    let container = _DictionaryKeyedEncodingContainer<Key>(
      referencing: self,
      codingPathNode: encoderCodingPathNode,
      wrapping: topRef
    )
    return KeyedEncodingContainer(container)
  }
  func unkeyedContainer() -> any UnkeyedEncodingContainer {
    let topRef: ValueReference
    if canEncodeNewValue {
      topRef = self.storage.pushUnkeyedContainer()
    } else {
      guard let ref = storage.refs.last, ref.isArray else {
        preconditionFailure(
          "Attempt to push new keyed encoding container when already previously encoded at this path."
        )
      }
      topRef = ref
    }
    return _DictionaryUnkeyedEncodingContainer(
      referencing: self,
      codingPathNode: encoderCodingPathNode,
      wrapping: topRef
    )
  }
  func singleValueContainer() -> any SingleValueEncodingContainer { self }

  func encode<T>(_ value: T) throws -> [String: Any] where T: Encodable {
    try _encode({ try $0.wrapGeneric(value, for: .root) }, value: value)
  }

  private func _encode<T>(
    _ wrap: (_DictionaryEncoder) throws -> ValueReference?,
    value: T
  ) throws -> [String: Any] {
    let encoder = _DictionaryEncoder(userInfo: self.userInfo, initialDepth: 0)
    do {
      guard let topLevel = try wrap(encoder) else {
        throw EncodingError.invalidValue(
          value,
          EncodingError.Context(
            codingPath: [],
            debugDescription: "Top-level \(T.self) did not encode any values."
          )
        )
      }

      let writer = DictionaryWriter()
      return try writer.serialize(topLevel.backing)
    } catch {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: [],
          debugDescription:
            "Unable to encode the given top-level value to [String:Any].",
          underlyingError: error
        )
      )
    }
  }
}

// MARK: Encoding Containers

private struct _DictionaryKeyedEncodingContainer<K: CodingKey>:
  KeyedEncodingContainerProtocol
{

  typealias Key = K

  // MARK: Properties

  /// A reference to the encoder we're writing to.
  private let encoder: _DictionaryEncoder

  private let reference: ValueReference
  private let codingPathNode: _CodingPathNode

  /// The path of coding keys taken to get to this point in encoding.
  public var codingPath: [CodingKey] { codingPathNode.path }

  init(
    referencing encoder: _DictionaryEncoder,
    codingPathNode: _CodingPathNode,
    wrapping ref: ValueReference
  ) {
    self.encoder = encoder
    self.codingPathNode = codingPathNode
    self.reference = ref
  }

  func _converted(_ key: CodingKey) -> String { key.stringValue }

  func encode(_ value: UInt64, forKey key: K) throws {
    reference.insert(._int(value), for: _converted(key))
  }

  func encode(_ value: UInt32, forKey key: K) throws {
    reference.insert(._int(value), for: _converted(key))
  }

  func encode(_ value: UInt16, forKey key: K) throws {
    reference.insert(._int(value), for: _converted(key))
  }

  func encode(_ value: UInt8, forKey key: K) throws {
    reference.insert(._int(value), for: _converted(key))
  }

  func encode(_ value: UInt, forKey key: K) throws {
    reference.insert(._int(value), for: _converted(key))
  }

  func encode(_ value: Int64, forKey key: K) throws {
    reference.insert(._int(value), for: _converted(key))
  }

  func encode(_ value: Int32, forKey key: K) throws {
    reference.insert(._int(value), for: _converted(key))
  }

  func encode(_ value: Int16, forKey key: K) throws {
    reference.insert(._int(value), for: _converted(key))
  }

  func encode(_ value: Int8, forKey key: K) throws {
    reference.insert(._int(value), for: _converted(key))
  }

  func encode(_ value: Int, forKey key: K) throws {
    reference.insert(._int(value), for: _converted(key))
  }

  func encode(_ value: Float, forKey key: K) throws {
    reference.insert(.float(value), for: _converted(key))
  }

  func encode(_ value: Double, forKey key: K) throws {
    reference.insert(.double(value), for: _converted(key))
  }

  func encode(_ value: String, forKey key: K) throws {
    reference.insert(.string(value), for: _converted(key))
  }

  func encode(_ value: Bool, forKey key: K) throws {
    reference.insert(.bool(value), for: _converted(key))
  }

  func encodeNil(forKey key: K) throws {
    reference.insert(.null, for: _converted(key))
  }

  mutating func encode<T>(_ value: T, forKey key: K) throws where T: Encodable {
    let wrapped = try self.encoder.wrap(
      value,
      for: self.encoder.encoderCodingPathNode,
      key
    )
    self.reference.insert(wrapped, for: _converted(key))
  }

  mutating func nestedUnkeyedContainer(forKey key: K)
    -> any UnkeyedEncodingContainer
  {
    let containerKey = _converted(key)
    let nestedRef: ValueReference
    if let existingRef = self.reference[containerKey] {
      precondition(
        existingRef.isArray,
        """
        Attempt to re-encode into nested UnkeyedEncodingContainer for key \"\(containerKey)\" \
        is invalid: keyed container/single value already encoded for this key
        """
      )
      nestedRef = existingRef
    } else {
      nestedRef = .emptyArray
      self.reference.insert(nestedRef, for: containerKey)
    }
    return _DictionaryUnkeyedEncodingContainer(
      referencing: self.encoder,
      codingPathNode: self.codingPathNode.appending(key),
      wrapping: nestedRef
    )
  }

  mutating func nestedContainer<NestedKey>(
    keyedBy keyType: NestedKey.Type,
    forKey key: K
  ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
    let containerKey = _converted(key)
    let nestedRef: ValueReference
    if let existingRef = self.reference[containerKey] {
      precondition(
        existingRef.isObject,
        """
        Attempt to re-encode into nested KeyedEncodingContainer<\(Key.self)> for \
        key \"\(containerKey)\" is invalid: non-keyed container already encoded for this key
        """
      )
      nestedRef = existingRef
    } else {
      nestedRef = .emptyObject
      self.reference.insert(nestedRef, for: containerKey)
    }
    let container = _DictionaryKeyedEncodingContainer<NestedKey>(
      referencing: self.encoder,
      codingPathNode: self.codingPathNode.appending(key),
      wrapping: nestedRef
    )
    return KeyedEncodingContainer(container)
  }

  mutating func superEncoder() -> any Encoder {
    fatalError("Encoding a superclass is not supported.")
  }

  mutating func superEncoder(forKey key: K) -> any Encoder {
    fatalError("Encoding a superclass is not supported.")
  }
}

private struct _DictionaryUnkeyedEncodingContainer: UnkeyedEncodingContainer {

  /// A reference to the encoder we're writing to.
  private let encoder: _DictionaryEncoder

  private let reference: ValueReference
  private let codingPathNode: _CodingPathNode
  var count: Int { self.reference.count }

  /// The path of coding keys taken to get to this point in encoding.
  public var codingPath: [CodingKey] { codingPathNode.path }

  init(
    referencing encoder: _DictionaryEncoder,
    codingPathNode: _CodingPathNode,
    wrapping ref: ValueReference
  ) {
    self.encoder = encoder
    self.codingPathNode = codingPathNode
    self.reference = ref
  }

  func _converted(_ key: CodingKey) -> String { key.stringValue }

  func encode(_ value: UInt64) throws { reference.insert(._int(value)) }
  func encode(_ value: UInt32) throws { reference.insert(._int(value)) }
  func encode(_ value: UInt16) throws { reference.insert(._int(value)) }
  func encode(_ value: UInt8) throws { reference.insert(._int(value)) }
  func encode(_ value: UInt) throws { reference.insert(._int(value)) }
  func encode(_ value: Int64) throws { reference.insert(._int(value)) }
  func encode(_ value: Int32) throws { reference.insert(._int(value)) }
  func encode(_ value: Int16) throws { reference.insert(._int(value)) }
  func encode(_ value: Int8) throws { reference.insert(._int(value)) }
  func encode(_ value: Int) throws { reference.insert(._int(value)) }
  func encode(_ value: Float) throws { reference.insert(.float(value)) }
  func encode(_ value: Double) throws { reference.insert(.double(value)) }
  func encode(_ value: String) throws { reference.insert(.string(value)) }
  func encode(_ value: Bool) throws { reference.insert(.bool(value)) }
  func encodeNil() throws { reference.insert(.null) }

  mutating func encode<T>(_ value: T) throws where T: Encodable {
    let wrapped = try self.encoder.wrap(
      value,
      for: self.encoder.encoderCodingPathNode,
      _CodingKey(index: self.count)
    )
    self.reference.insert(wrapped)
  }

  mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
    -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
  {
    let key = _CodingKey(index: self.count)
    let nestedRef = ValueReference.emptyObject
    self.reference.insert(nestedRef)
    let container = _DictionaryKeyedEncodingContainer<NestedKey>(
      referencing: self.encoder,
      codingPathNode: self.codingPathNode.appending(key),
      wrapping: nestedRef
    )
    return KeyedEncodingContainer(container)
  }

  mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
    let key = _CodingKey(index: self.count)
    let nestedRef = ValueReference.emptyArray
    self.reference.insert(nestedRef)
    return _DictionaryUnkeyedEncodingContainer(
      referencing: self.encoder,
      codingPathNode: self.codingPathNode.appending(key),
      wrapping: nestedRef
    )
  }

  mutating func superEncoder() -> any Encoder {
    fatalError("Encoding a superclass is not supported.")
  }
}

extension _DictionaryEncoder: SingleValueEncodingContainer {
  private func assertCanEncodeNewValue() {
    precondition(
      self.canEncodeNewValue,
      """
      Attempt to encode value through single value container when \
      previously value already encoded.
      """
    )
  }

  func encode(_ value: UInt64) throws {
    assertCanEncodeNewValue()
    storage.push(ref: ._int(value))
  }

  func encode(_ value: UInt32) throws {
    assertCanEncodeNewValue()
    storage.push(ref: ._int(value))
  }

  func encode(_ value: UInt16) throws {
    assertCanEncodeNewValue()
    storage.push(ref: ._int(value))
  }

  func encode(_ value: UInt8) throws {
    assertCanEncodeNewValue()
    storage.push(ref: ._int(value))
  }

  func encode(_ value: UInt) throws {
    assertCanEncodeNewValue()
    storage.push(ref: ._int(value))
  }

  func encode(_ value: Int64) throws {
    assertCanEncodeNewValue()
    storage.push(ref: ._int(value))
  }

  func encode(_ value: Int32) throws {
    assertCanEncodeNewValue()
    storage.push(ref: ._int(value))
  }

  func encode(_ value: Int16) throws {
    assertCanEncodeNewValue()
    storage.push(ref: ._int(value))
  }

  func encode(_ value: Int8) throws {
    assertCanEncodeNewValue()
    storage.push(ref: ._int(value))
  }

  func encode(_ value: Int) throws {
    assertCanEncodeNewValue()
    storage.push(ref: ._int(value))
  }
  func encode(_ value: Float) throws {
    assertCanEncodeNewValue()
    storage.push(ref: .float(value))
  }
  func encode(_ value: Double) throws {
    assertCanEncodeNewValue()
    storage.push(ref: .double(value))
  }

  func encode(_ value: String) throws {
    assertCanEncodeNewValue()
    storage.push(ref: .string(value))
  }

  func encode(_ value: Bool) throws {
    assertCanEncodeNewValue()
    storage.push(ref: .bool(value))
  }

  func encode<T>(_ value: T) throws where T: Encodable {
    assertCanEncodeNewValue()
    try storage.push(ref: self.wrap(value, for: self.encoderCodingPathNode))
  }

  func encodeNil() throws {
    assertCanEncodeNewValue()
    self.storage.push(ref: .null)
  }
}

// MARK: - Generic Encoding Methods

extension _DictionaryEncoder {
  fileprivate func wrap(
    _ value: Encodable,
    for codingPathNode: _CodingPathNode,
    _ additionalKey: (some CodingKey)? = _CodingKey?.none
  ) throws -> ValueReference {
    try self.wrapGeneric(value, for: codingPathNode, additionalKey)
      ?? .emptyObject
  }

  fileprivate func wrapGeneric<T: Encodable>(
    _ value: T,
    for node: _CodingPathNode,
    _ additionalKey: (some CodingKey)? = _CodingKey?.none
  ) throws -> ValueReference? {
    switch T.self { #if canImport(Foundation)
      case is Date.Type:
        // Respect Date encoding strategy
        return try self.wrap(value as! Date, for: node, additionalKey)
      case is Data.Type:
        // Encode Data using base64EncodedString()
        return try self.wrap(value as! Data, for: node, additionalKey)
      case is URL.Type:
        // Encode URLs as single strings.
        let url = value as! URL
        return .string(url.absoluteString)
    #endif
    case is _DictionaryEncodableMarker.Type:
      return try self.wrap(
        value as! [String: Encodable],
        for: node,
        additionalKey
      )
    case is _DictionaryDirectArrayEncodable.Type:
      let array = value as! _DictionaryDirectArrayEncodable
      return array.directRepresentation()
    default: break
    }

    return try _wrapGeneric(
      { try value.encode(to: $0) },
      for: node,
      additionalKey
    )
  }

  // Instead of creating a new _DictionaryEncoder for passing to methods that
  // take Encoder arguments, wrap the access in this method,
  // which temporarily mutates this _DictionaryEncoder instance
  // with the additional nesting depth and its coding path.
  @inline(__always) func with<T>(
    path: _CodingPathNode?,
    perform closure: () throws -> T
  ) rethrows -> T {
    let oldPath = self.encoderCodingPathNode
    let oldDepth = self.codingPathDepth
    if let path {
      self.encoderCodingPathNode = path
      self.codingPathDepth = path.depth
    }

    defer {
      if path != nil {
        self.encoderCodingPathNode = oldPath
        self.codingPathDepth = oldDepth
      }
    }

    return try closure()
  }

  fileprivate func _wrapGeneric(
    _ encode: (_DictionaryEncoder) throws -> Void,
    for node: _CodingPathNode,
    _ additionalKey: (some CodingKey)? = _CodingKey?.none
  ) throws -> ValueReference? {
    // The value should request a container from the __JSONEncoder.
    let depth = self.storage.count
    do {
      try self.with(path: node.appending(additionalKey)) { try encode(self) }
    } catch {
      // If the value pushed a container before throwing, pop it back off to restore state.
      if self.storage.count > depth { let _ = self.storage.popReference() }

      throw error
    }

    // The top container should be a new container.
    guard self.storage.count > depth else { return nil }

    return self.storage.popReference()
  }
}

// MARK: - Specialized Encoding Methods

extension _DictionaryEncoder {
  fileprivate func wrap(
    _ dict: [String: Encodable],
    for codingPathNode: _CodingPathNode,
    _ additionalKey: (some CodingKey)? = _CodingKey?.none
  ) throws -> ValueReference? {
    let depth = self.storage.count
    let result = self.storage.pushKeyedContainer()
    let rootPath = codingPathNode.appending(additionalKey)
    do {
      for (key, value) in dict {
        result.insert(
          try wrap(value, for: rootPath, _CodingKey(stringValue: key)),
          for: key
        )
      }
    } catch {
      // If the value pushed a container before throwing, pop it back off to restore state.
      if self.storage.count > depth { let _ = self.storage.popReference() }

      throw error
    }

    // The top container should be a new container.
    guard self.storage.count > depth else { return nil }

    return self.storage.popReference()
  }

  #if canImport(Foundation)
    fileprivate func wrap(
      _ date: Date,
      for codingPathNode: _CodingPathNode,
      _ additionalKey: (some CodingKey)? = _CodingKey?.none
    ) throws -> ValueReference {
      // Dates encode as single-value objects; this can't both throw and push a container, so no need to catch the error.
      try self.with(path: codingPathNode.appending(additionalKey)) {
        try date.encode(to: self)
      }
      return self.storage.popReference()
    }

    fileprivate func wrap(
      _ data: Data,
      for codingPathNode: _CodingPathNode,
      _ additionalKey: (some CodingKey)? = _CodingKey?.none
    ) throws -> ValueReference {
      let depth = self.storage.count
      do {
        try self.with(path: codingPathNode.appending(additionalKey)) {
          try data.encode(to: self)
        }
      } catch {
        // If the value pushed a container before throwing, pop it back off to restore state.
        // This shouldn't be possible for Data (which encodes as an array of bytes),
        // but it can't hurt to catch a failure.
        if self.storage.count > depth { let _ = self.storage.popReference() }

        throw error
      }

      return self.storage.popReference()
    }
  #endif  // canImport(Foundation)
}

/// A marker protocol used to determine whether a value is a `String`-keyed `Dictionary`
/// containing `Encodable` values (in which case it should be exempt from key conversion strategies).
private protocol _DictionaryEncodableMarker {}

extension Dictionary: _DictionaryEncodableMarker
where Key == String, Value: Encodable {}

private protocol _DictionaryDirectArrayEncodable {
  func directRepresentation() -> ValueReference
}

private protocol _DictionarySimpleArrayElement {}
extension UInt64: _DictionarySimpleArrayElement {}
extension UInt32: _DictionarySimpleArrayElement {}
extension UInt16: _DictionarySimpleArrayElement {}
extension UInt8: _DictionarySimpleArrayElement {}
extension UInt: _DictionarySimpleArrayElement {}
extension Int64: _DictionarySimpleArrayElement {}
extension Int32: _DictionarySimpleArrayElement {}
extension Int8: _DictionarySimpleArrayElement {}
extension Int: _DictionarySimpleArrayElement {}
extension String: _DictionarySimpleArrayElement {}
extension Bool: _DictionarySimpleArrayElement {}

extension Array: _DictionaryDirectArrayEncodable
where Element: _DictionarySimpleArrayElement {
  func directRepresentation() -> ValueReference { .init(.directArray(self)) }
}
