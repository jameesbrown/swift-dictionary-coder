internal struct DictionaryWriter: ~Copyable {

  init() {}

  // MARK: Top Level
  consuming func serialize(_ value: ValueReference.Backing, depth: Int = 0)
    throws -> [String: Any]
  {
    switch value {
    case let .object(object):
      return try serializeObject(object, depth: depth + 1)
    default: throw CancellationError()
    }
  }

  func serializeArray(_ array: [ValueReference], depth: Int) throws -> [Any] {
    try array.withUnsafeBufferPointer({
      var serialized = [Any]()
      serialized.reserveCapacity($0.count)
      for elem in $0 { try serialized.append(extract(elem, depth: depth)) }
      return serialized
    })
  }

  func serializeObject(_ object: [String: ValueReference], depth: Int) throws
    -> [String: Any]
  {
    guard !object.keys.isEmpty else { return [:] }
    var dictionary = [String: Any]()
    dictionary.reserveCapacity(object.keys.count)
    for (key, value) in object {
      try dictionary[key] = extract(value, depth: depth)
    }
    return dictionary
  }

  private func extract(_ value: ValueReference, depth: Int) throws -> Any {
    switch value.backing {
    case let .int(v): v
    case let .float(v): v
    case let .double(v): v
    case let .string(v): v
    case let .bool(v): v
    case let .directArray(arr): arr
    case let .array(arr): try serializeArray(arr, depth: depth + 1)
    case let .object(object): try serializeObject(object, depth: depth + 1)
    case .null: Any?(nil) as Any
    }
  }
}
