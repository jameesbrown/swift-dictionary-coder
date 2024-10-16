import DictionaryCoder
import Foundation

enum Bar: Codable, Equatable {
  case foo
  case baz(Baz)
  enum Baz: Codable, Equatable {
    case hi
    case bye(Foo)
    enum Foo: Codable, Equatable {
      case fubar
      case bazbar
    }
  }
}
struct UserProfile: Codable, Equatable {
  struct Address: Codable, Equatable {
    let street: String
    let bar: Bar
    let city: String
    let postalCode: String
    let country: String
    func dictionary() -> [String: Any] {
      [
        "street": street, "city": city, "postalCode": postalCode,
        "country": country,
      ]
    }
  }
  struct Preferences: Codable, Equatable {
    let notificationsEnabled: Bool
    let favoriteGenres: [String]
    let preferredLanguage: String?
    func dictionary() -> [String: Any] {
      [
        "notificationsEnabled": notificationsEnabled,
        "favoriteGenres": favoriteGenres,
        "preferredLanguage": preferredLanguage as Any,
      ]
    }
    static func from(_ dictionary: [String: Any]) -> Self {
      .init(
        notificationsEnabled: dictionary["notificationsEnabled"] as! Bool,
        favoriteGenres: dictionary["favoriteGenres"] as! [String],
        preferredLanguage: dictionary["preferredLanguage"] as! String?
      )
    }
  }
  struct PaymentInfo: Codable, Equatable {
    struct Card: Codable, Equatable {
      let cardType: String
      let lastFourDigits: String
      let expiryDate: String
      func dictionary() -> [String: Any] {
        [
          "cardType": "\(cardType)", "expiryDate": "\(expiryDate)",
          "lastFourDigits": "\(lastFourDigits)",
        ]
      }
    }
    let cards: [Card]
    func dictionary() -> [String: Any] {
      var result: [String: Any] = ["cards": ()]
      result["cards"] = cards as [Any]
      return result
    }
  }

  struct ActivityLog: Codable, Equatable {
    struct Activity: Codable, Equatable {
      let timestamp: Date
      let description: String
      func dictionary() -> [String: Any] {
        ["timestamp": timestamp, "description": description]
      }
    }
    let activities: [Activity]
    func dictionary() -> [String: Any] {
      var result: [String: [[String: Any]]] = ["activities": []]
      for activity in activities {
        result["activities"]?.append(activity.dictionary())
      }
      return result
    }
  }

  let id: UUID
  let name: String
  let email: String?
  let address: Address
  let preferences: Preferences
  let paymentInfo: PaymentInfo
  let activityLog: ActivityLog
  let isActive: Bool
  let creationDate: Date
  let tags: [String]
  let nestedOptionalValue: [String: [Int?]?]
}
extension UserProfile {
  nonisolated(unsafe) static var dictionary: [String: Any] = [:]
}

let testUser: UserProfile = {
  UserProfile(
    id: UUID(),
    name: "Alice Johnson",
    email: "alice@example.com",
    address: UserProfile.Address(
      street: "123 Main St",
      bar: .baz(.bye(.bazbar)),
      city: "Metropolis",
      postalCode: "12345",
      country: "Wonderland"
    ),
    preferences: UserProfile.Preferences(
      notificationsEnabled: true,
      favoriteGenres: ["Fantasy", "Sci-Fi", "Mystery"],
      preferredLanguage: "English"
    ),
    paymentInfo: UserProfile.PaymentInfo(cards: [
      UserProfile.PaymentInfo.Card(
        cardType: "Visa",
        lastFourDigits: "1234",
        expiryDate: "12/26"
      ),
      UserProfile.PaymentInfo.Card(
        cardType: "MasterCard",
        lastFourDigits: "5678",
        expiryDate: "10/25"
      ),
    ]),
    activityLog: UserProfile.ActivityLog(activities: [
      UserProfile.ActivityLog.Activity(
        timestamp: Date(timeIntervalSince1970: 1_684_156_800),
        description: "Logged in"
      ),
      UserProfile.ActivityLog.Activity(
        timestamp: Date(),
        description: "Purchased a new book"
      ),
    ]),
    isActive: true,
    creationDate: Date(timeIntervalSince1970: 1_684_156_800),
    tags: ["new_user", "premium_member"],
    nestedOptionalValue: ["example": [1, nil, 3], "empty": nil]
  )
}()

@_transparent func measureDictionaryEncoder() throws {
  let _ = try DictionaryEncoder().encode(testUser)
}

@_transparent func measureDictionaryDecoding(_ dictionary: [String: Any]) throws
{ _ = try DictionaryDecoder().decode(UserProfile.self, from: dictionary) }

@_transparent func measureDictionaryCodingRoundTrip() throws {
  let testUser = try DictionaryEncoder().encode(testUser)
  let _ = try DictionaryDecoder().decode(UserProfile.self, from: testUser)
}

func measureJSONEncoder() throws { let _ = try JSONEncoder().encode(testUser) }
var duration = ContinuousClock.Duration.seconds(0)
let clock = ContinuousClock()
UserProfile.dictionary = try DictionaryEncoder().encode(testUser)
for _ in 0..<100_000 { try measureDictionaryEncoder() }
for _ in 0..<100_000 {
  duration += try clock.measure { try measureDictionaryEncoder() }
}
print("DICTIONARY ENCODER AVG: \(duration / 100_000)")
duration = .seconds(0)
for _ in 0..<100_000 {
  duration += try clock.measure { try measureJSONEncoder() }
}
print("JSON ENCODER AVG: \(duration / 100_000)")

duration = .seconds(0)
for _ in 0..<100_000 {
  duration += try clock.measure { try measureDictionaryCodingRoundTrip() }
}
print("DICTIONARY CODING ROUND TRIP AVG: \(duration / 100_000)")
duration = .seconds(0)
for _ in 0..<100_000 {
  duration += try clock.measure {
    try measureDictionaryDecoding(UserProfile.dictionary)
  }
}
print("DICTIONARY DECODING AVG: \(duration / 100_000)")
