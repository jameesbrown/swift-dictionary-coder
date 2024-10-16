#if canImport(Foundation)
  import Foundation
#endif

public struct DictionaryDecoder: Sendable {
  private let _decoder: _DictionaryDecoder
  public init() { self._decoder = .init() }
  public func decode<T: Decodable>(
    _ type: T.Type,
    from dictionary: [String: Any]
  ) throws -> T { try _decoder.decode(type, from: dictionary) }
}

final class _DictionaryDecoder: Decoder, @unchecked Sendable {
  var codingPath: [any CodingKey] { decoderCodingPathNode.path }
  var userInfo: [CodingUserInfoKey: Any]
  private(set) var decoderCodingPathNode: _CodingPathNode
  private(set) var codingPathDepth: Int
  // The portion of the dictionary we are currently decoding.
  private(set) var topValue: Any?
  init(
    userInfo: [CodingUserInfoKey: Any] = [:],
    decoderCodingPathNode: _CodingPathNode = .root,
    initialDepth: Int = 0
  ) {
    self.userInfo = userInfo
    self.decoderCodingPathNode = decoderCodingPathNode
    self.codingPathDepth = initialDepth
  }
  func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<
    Key
  > where Key: CodingKey {
    let currentValue = topValue
    switch currentValue {
    case let dictionary as [String: Any]:
      return .init(
        _DictionaryKeyedDecodingContainer(
          referencing: self,
          codingPathNode: decoderCodingPathNode,
          unwrapping: dictionary
        )
      )
    case is [Any]:
      throw DecodingError.typeMismatch(
        [String: Any].self,
        .init(
          codingPath: self.codingPath,
          debugDescription: """
            Expected to decode \([String:Any].self) \
            but found \([Any].self) instead.
            """
        )
      )
    default:
      throw DecodingError.valueNotFound(
        [String: Any].self,
        .init(
          codingPath: self.codingPath,
          debugDescription:
            "Expected to decode \([String:Any].self) but found nil instead."
        )
      )
    }
  }
  func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
    let topValue = topValue
    switch topValue {
    case let topArray as any Sequence:
      return _DictionaryUnkeyedDecodingContainer(
        referencing: self,
        codingPathNode: self.decoderCodingPathNode,
        unwrapping: topArray
      )
    case is [String: Any]:
      throw DecodingError.typeMismatch(
        [Any].self,
        .init(
          codingPath: self.codingPath,
          debugDescription: """
            Expected to decode \([Any].self) \
            but found \([String: Any].self) instead.
            """
        )
      )
    default:
      throw DecodingError.valueNotFound(
        [Any].self,
        .init(
          codingPath: self.codingPath,
          debugDescription:
            "Expected to decode \([Any].self) but found nil instead."
        )
      )
    }
  }
  func singleValueContainer() throws -> any SingleValueDecodingContainer {
    self
  }
  func decode<T: Decodable>(_ type: T.Type, from dictionary: [String: Any])
    throws -> T
  {
    self.topValue = dictionary
    return try type.init(from: self)
  }
}

// MARK: - Decoding Containers

struct _DictionaryKeyedDecodingContainer<K: CodingKey>:
  KeyedDecodingContainerProtocol
{
  typealias Key = K
  private let decoder: _DictionaryDecoder
  var dictionary: [String: Any]
  var codingPath: [any CodingKey] { codingPathNode.path }
  var codingPathNode: _CodingPathNode
  var allKeys: [K]
  fileprivate init(
    referencing decoder: _DictionaryDecoder,
    codingPathNode: _CodingPathNode,
    unwrapping dictionary: [String: Any]
  ) {
    self.dictionary = dictionary
    self.codingPathNode = codingPathNode
    self.decoder = decoder
    self.allKeys = dictionary.keys.compactMap({ K(stringValue: $0) })
  }
  @inline(__always) func contains(_ key: K) -> Bool {
    dictionary[key.stringValue] != nil
  }
  func _converted(_ key: K) -> String { key.stringValue }
  func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
    try decoder.decodeUInt64(dictionary[_converted(key)])
  }
  func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
    try decoder.decodeUInt32(dictionary[_converted(key)])
  }
  func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
    try decoder.decodeUInt16(dictionary[_converted(key)])
  }
  func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
    try decoder.decodeUInt8(dictionary[_converted(key)])
  }
  func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
    try decoder.decodeUInt(dictionary[_converted(key)])
  }
  func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
    try decoder.decodeInt64(dictionary[_converted(key)])
  }
  func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
    try decoder.decodeInt32(dictionary[_converted(key)])
  }
  func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
    try decoder.decodeInt16(dictionary[_converted(key)])
  }
  func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
    try decoder.decodeInt8(dictionary[_converted(key)])
  }
  func decode(_ type: Int.Type, forKey key: K) throws -> Int {
    try decoder.decodeInt(dictionary[_converted(key)])
  }
  func decode(_ type: Float.Type, forKey key: K) throws -> Float {
    try decoder.decodeFloat(dictionary[_converted(key)])
  }
  func decode(_ type: Double.Type, forKey key: K) throws -> Double {
    try decoder.decodeDouble(dictionary[_converted(key)])
  }
  func decode(_ type: String.Type, forKey key: K) throws -> String {
    try decoder.decodeString(dictionary[_converted(key)])
  }
  func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
    try decoder.decodeBool(dictionary[_converted(key)])
  }
  func decodeNil(forKey key: K) throws -> Bool {
    decoder._decodeNil(dictionary[_converted(key)])
  }
  func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T: Decodable {
    guard let value = self.dictionary[_converted(key)] else {
      throw DecodingError.valueNotFound(
        T.self,
        .init(
          codingPath: codingPath,
          debugDescription: "Value not found for \(key)."
        )
      )
    }
    guard let t = value as? T else {
      return try self.decoder.with(
        value: value,
        path: self.codingPathNode.appending(key),
        operation: { try decoder.unwrap(type) }
      )
    }
    return t
  }
  func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K)
    throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
  {
    let nestedValue = self.dictionary[_converted(key)]
    switch nestedValue {
    case let nestedDictionary as [String: Any]:
      return .init(
        _DictionaryKeyedDecodingContainer<NestedKey>(
          referencing: self.decoder,
          codingPathNode: self.codingPathNode.appending(key),
          unwrapping: nestedDictionary
        )
      )
    case is [Any]:
      throw DecodingError.typeMismatch(
        [String: Any].self,
        .init(
          codingPath: self.codingPath,
          debugDescription: """
            Expected to decode \([String:Any].self) for \(key) \
            but found \([Any].self) instead.
            """
        )
      )
    default:
      throw DecodingError.valueNotFound(
        [String: Any].self,
        .init(
          codingPath: self.codingPath,
          debugDescription:
            "Expected to decode \([String:Any].self) for \(key) but found nil instead."
        )
      )
    }
  }
  func nestedUnkeyedContainer(forKey key: K) throws
    -> any UnkeyedDecodingContainer
  {
    let nestedValue = self.dictionary[_converted(key)]
    switch nestedValue {
    case let nestedArray as any RandomAccessCollection:
      return _DictionaryUnkeyedDecodingContainer(
        referencing: self.decoder,
        codingPathNode: self.codingPathNode.appending(key),
        unwrapping: nestedArray
      )
    case is [String: Any]:
      throw DecodingError.typeMismatch(
        [Any].self,
        .init(
          codingPath: self.codingPath,
          debugDescription: """
            Expected to decode \([Any].self) for \(key) \
            but found \([String: Any].self) instead.
            """
        )
      )
    default:
      throw DecodingError.valueNotFound(
        [Any].self,
        .init(
          codingPath: self.codingPath,
          debugDescription:
            "Expected to decode \([Any].self) for \(key) but found nil instead."
        )
      )
    }
  }
  func superDecoder() throws -> any Decoder {
    fatalError("Decoding a superclass is not supported.")
  }
  func superDecoder(forKey key: K) throws -> any Decoder {
    fatalError("Decoding a superclass is not supported.")
  }
}

struct _DictionaryUnkeyedDecodingContainer: UnkeyedDecodingContainer {
  var iterator: any IteratorProtocol
  var currentValue: Any?
  var codingPath: [any CodingKey] { codingPathNode.path }
  var codingPathNode: _CodingPathNode
  var count: Int?
  var isAtEnd: Bool = false
  var currentIndex: Int
  private let decoder: _DictionaryDecoder
  fileprivate init(
    referencing decoder: _DictionaryDecoder,
    codingPathNode: _CodingPathNode,
    unwrapping values: some Sequence
  ) {
    self.iterator = values.makeIterator()
    self.codingPathNode = codingPathNode
    self.decoder = decoder
    self.currentIndex = 0
  }
  @inline(__always) mutating func withPeekedValue<T>(
    _ operation: (Any?) throws -> T
  ) rethrows -> T {
    // Preserve state if a user catches an error,
    // i.e, don't advance if the decode fails.
    let result = try operation(peekValue())
    advance()
    return result
  }
  // Access the next value to decode without consuming it.
  @inline(__always) mutating func peekValue() -> Any? {
    guard let currentValue else {
      currentValue = iterator.next()
      return currentValue
    }
    return currentValue
  }
  // Advance the container to the next value,
  // and check if we are at the end.
  @inline(__always) mutating func advance() {
    currentIndex += 1
    currentValue = nil
    if self.peekValue() == nil { self.isAtEnd = true }
  }
  mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
    try withPeekedValue(decoder.decodeUInt64)
  }
  mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
    try withPeekedValue(decoder.decodeUInt32)
  }
  mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
    try withPeekedValue(decoder.decodeUInt16)
  }
  mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
    try withPeekedValue(decoder.decodeUInt8)
  }
  mutating func decode(_ type: UInt.Type) throws -> UInt {
    try withPeekedValue(decoder.decodeUInt)
  }
  mutating func decode(_ type: Int64.Type) throws -> Int64 {
    try withPeekedValue(decoder.decodeInt64)
  }
  mutating func decode(_ type: Int32.Type) throws -> Int32 {
    try withPeekedValue(decoder.decodeInt32)
  }
  mutating func decode(_ type: Int16.Type) throws -> Int16 {
    try withPeekedValue(decoder.decodeInt16)
  }
  mutating func decode(_ type: Int8.Type) throws -> Int8 {
    try withPeekedValue(decoder.decodeInt8)
  }
  mutating func decode(_ type: Int.Type) throws -> Int {
    try withPeekedValue(decoder.decodeInt)
  }
  mutating func decode(_ type: Float.Type) throws -> Float {
    try withPeekedValue(decoder.decodeFloat)
  }
  mutating func decode(_ type: Double.Type) throws -> Double {
    try withPeekedValue(decoder.decodeDouble)
  }
  mutating func decode(_ type: String.Type) throws -> String {
    try withPeekedValue(decoder.decodeString)
  }
  mutating func decode(_ type: Bool.Type) throws -> Bool {
    try withPeekedValue(decoder.decodeBool)
  }
  mutating func decodeNil() throws -> Bool {
    let result = decoder._decodeNil(self.peekValue())
    defer { if result { advance() } }
    return result
  }

  mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
    let value = peekValue()
    guard let value else {
      throw DecodingError.valueNotFound(
        type,
        .init(
          codingPath: self.codingPath,
          debugDescription: """
            Expected to decode \(type) at index \(currentIndex) \
            but found nil instead.
            """
        )
      )
    }
    guard let t = value as? T else {
      let t = try self.decoder.with(
        value: value,
        path: self.codingPathNode.appending(_CodingKey(index: currentIndex)),
        operation: { try decoder.unwrap(type) }
      )
      self.advance()
      return t
    }
    self.advance()
    return t
  }
  mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws
    -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
  {
    let nestedValue = self.peekValue()
    switch nestedValue {
    case let nestedDictionary as [String: Any]:
      return .init(
        _DictionaryKeyedDecodingContainer<NestedKey>(
          referencing: self.decoder,
          codingPathNode: self.codingPathNode.appending(
            _CodingKey(index: currentIndex)
          ),
          unwrapping: nestedDictionary
        )
      )
    case is [Any]:
      throw DecodingError.typeMismatch(
        [String: Any].self,
        .init(
          codingPath: self.codingPath,
          debugDescription: """
            Expected to decode \([String:Any].self) \
            but found \([Any].self) instead.
            """
        )
      )
    default:
      throw DecodingError.valueNotFound(
        [String: Any].self,
        .init(
          codingPath: self.codingPath,
          debugDescription:
            "Expected to decode \([String:Any].self) but found nil instead."
        )
      )
    }
  }
  mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer
  {
    let nestedValue = self.peekValue()
    switch nestedValue {
    case let nestedArray as [Any]:
      return _DictionaryUnkeyedDecodingContainer(
        referencing: decoder,
        codingPathNode: self.codingPathNode.appending(
          _CodingKey(index: currentIndex)
        ),
        unwrapping: nestedArray
      )
    case is [String: Any]:
      throw DecodingError.typeMismatch(
        [Any].self,
        .init(
          codingPath: self.codingPath,
          debugDescription: """
            Expected to decode \([Any].self) at index \(currentIndex) \
            but found \([String: Any].self) instead.
            """
        )
      )
    default:
      throw DecodingError.valueNotFound(
        [Any].self,
        .init(
          codingPath: self.codingPath,
          debugDescription:
            "Expected to decode \([Any].self) at index \(currentIndex) but found nil instead."
        )
      )
    }
  }
  mutating func superDecoder() throws -> any Decoder {
    fatalError("Decoding a superclass is not supported.")
  }
}

extension _DictionaryDecoder: SingleValueDecodingContainer {
  func decode(_ type: UInt64.Type) throws -> UInt64 {
    try decodeUInt64(topValue)
  }
  func decode(_ type: UInt32.Type) throws -> UInt32 {
    try decodeUInt32(topValue)
  }
  func decode(_ type: UInt16.Type) throws -> UInt16 {
    try decodeUInt16(topValue)
  }
  func decode(_ type: UInt8.Type) throws -> UInt8 { try decodeUInt8(topValue) }
  func decode(_ type: UInt.Type) throws -> UInt { try decodeUInt(topValue) }
  func decode(_ type: Int64.Type) throws -> Int64 { try decodeInt64(topValue) }
  func decode(_ type: Int32.Type) throws -> Int32 { try decodeInt32(topValue) }
  func decode(_ type: Int16.Type) throws -> Int16 { try decodeInt16(topValue) }
  func decode(_ type: Int8.Type) throws -> Int8 { try decodeInt8(topValue) }
  func decode(_ type: Int.Type) throws -> Int { try decodeInt(topValue) }
  func decode(_ type: Float.Type) throws -> Float { try decodeFloat(topValue) }
  func decode(_ type: Double.Type) throws -> Double {
    try decodeDouble(topValue)
  }
  func decode(_ type: String.Type) throws -> String {
    try decodeString(topValue)
  }
  func decode(_ type: Bool.Type) throws -> Bool { try decodeBool(topValue) }
  func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
    try type.init(from: self)
  }
  func decodeNil() -> Bool { _decodeNil(topValue) }
}

// MARK: - Specialized Decoding Methods

extension _DictionaryDecoder {
  @inline(__always) func decodeUInt8(_ value: Any?) throws -> UInt8 {
    guard case let i as Int = value else {
      throw typeMismatch(target: UInt8.self, underlyingValue: value)
    }
    return .init(truncatingIfNeeded: i)
  }
  @inline(__always) func decodeUInt16(_ value: Any?) throws -> UInt16 {
    guard case let i as Int = value else {
      throw typeMismatch(target: UInt16.self, underlyingValue: value)
    }
    return .init(truncatingIfNeeded: i)
  }
  @inline(__always) func decodeUInt32(_ value: Any?) throws -> UInt32 {
    guard case let i as Int = value else {
      throw typeMismatch(target: UInt32.self, underlyingValue: value)
    }
    return .init(truncatingIfNeeded: i)
  }
  @inline(__always) func decodeUInt64(_ value: Any?) throws -> UInt64 {
    guard case let i as Int = value else {
      throw typeMismatch(target: UInt64.self, underlyingValue: value)
    }
    return .init(truncatingIfNeeded: i)
  }
  @inline(__always) func decodeUInt(_ value: Any?) throws -> UInt {
    guard case let i as Int = value else {
      throw typeMismatch(target: UInt.self, underlyingValue: value)
    }
    return .init(truncatingIfNeeded: i)
  }
  @inline(__always) func decodeInt8(_ value: Any?) throws -> Int8 {
    guard case let i as Int = value else {
      throw typeMismatch(target: Int8.self, underlyingValue: value)
    }
    return .init(truncatingIfNeeded: i)
  }
  @inline(__always) func decodeInt16(_ value: Any?) throws -> Int16 {
    guard case let i as Int = value else {
      throw typeMismatch(target: Int16.self, underlyingValue: value)
    }
    return .init(truncatingIfNeeded: i)
  }
  @inline(__always) func decodeInt32(_ value: Any?) throws -> Int32 {
    guard case let i as Int = value else {
      throw typeMismatch(target: Int32.self, underlyingValue: value)
    }
    return .init(truncatingIfNeeded: i)
  }
  @inline(__always) func decodeInt64(_ value: Any?) throws -> Int64 {
    guard case let i as Int = value else {
      throw typeMismatch(target: Int64.self, underlyingValue: value)
    }
    return .init(truncatingIfNeeded: i)
  }
  @inline(__always) func decodeInt(_ value: Any?) throws -> Int {
    guard case let i as Int = value else {
      throw typeMismatch(target: Int.self, underlyingValue: value)
    }
    return i
  }
  @inline(__always) func decodeFloat(_ value: Any?) throws -> Float {
    guard case let f as Float = value else {
      throw typeMismatch(target: Float.self, underlyingValue: value)
    }
    return f
  }
  @inline(__always) func decodeDouble(_ value: Any?) throws -> Double {
    guard case let d as Double = value else {
      throw typeMismatch(target: Double.self, underlyingValue: value)
    }
    return d
  }
  @inline(__always) func decodeString(_ value: Any?) throws -> String {
    guard case let s as String = value else {
      throw typeMismatch(target: String.self, underlyingValue: value)
    }
    return s
  }
  @inline(__always) func decodeBool(_ value: Any?) throws -> Bool {
    guard case let b as Bool = value else {
      throw typeMismatch(target: Bool.self, underlyingValue: value)
    }
    return b
  }
  // Instead of creating a new _DictionaryDecoder for passing to methods that
  // take Decoder arguments, wrap the access in this method,
  // which temporarily mutates this _DictionaryDecoder instance
  // with the additional nesting depth and its coding path.
  @inline(__always) func with<T>(
    value: Any,
    path: _CodingPathNode,
    operation: () throws -> T
  ) throws -> T {
    let oldNode = self.decoderCodingPathNode
    let oldDepth = self.codingPathDepth
    self.decoderCodingPathNode = path
    self.codingPathDepth = path.depth
    self.topValue = value
    defer {
      self.decoderCodingPathNode = oldNode
      self.codingPathDepth = oldDepth
      self.topValue = nil
    }
    return try operation()
  }
  @inline(__always) func typeMismatch<T>(target: T.Type, underlyingValue: Any?)
    -> DecodingError
  {
    DecodingError.typeMismatch(
      T.self,
      .init(
        codingPath: self.codingPath,
        debugDescription: """
          Expected to decode \(T.self) \
          but found \(type(of: underlyingValue)) instead.
          """
      )
    )
  }
  @inline(__always) func _decodeNil(_ value: Any?) -> Bool {
    #if canImport(Foundation)
      value == nil || value is NSNull
    #else
      value == nil
    #endif
  }

  // Data Encoded as a String needs special handling.
  func unwrap<T: Decodable>(_ type: T.Type) throws -> T {
    #if canImport(Foundation)
      switch T.self {
      case is Data.Type:
        guard case let d as Data = topValue else {
          guard case let str as String = topValue else { break }
          return Data(str.utf8) as! T
        }
        return d as! T
      case is URL.Type:
        guard case let url as URL = topValue else {
          guard case let str as String = topValue else { break }
          return URL(string: str) as! T
        }
        return url as! T
      default: break
      }
    #endif
    return try type.init(from: self)
  }
}
