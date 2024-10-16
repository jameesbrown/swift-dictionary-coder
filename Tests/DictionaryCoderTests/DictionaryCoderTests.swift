import Foundation
import Testing

@testable import DictionaryCoder

@Test func example() throws {
  try roundTripEquality("Hello World!")
  try roundTripEquality(100)
  try roundTripEquality(UInt8(100))
  try roundTripEquality(UInt16(100))
  try roundTripEquality(UInt32(100))
  try roundTripEquality(UInt64(100))
  try roundTripEquality(UInt(100))
  try roundTripEquality(true)
  try roundTripEquality(Float(100))
  try roundTripEquality(100.00)
  try roundTripEquality(Data([1, 2, 3]))
  try roundTripEquality(Date.timeIntervalSinceReferenceDate)
  try roundTripArrayEquality("Hello World!")
  try roundTripArrayEquality(100)
  try roundTripArrayEquality(UInt8(100))
  try roundTripArrayEquality(UInt16(100))
  try roundTripArrayEquality(UInt32(100))
  try roundTripArrayEquality(UInt64(100))
  try roundTripArrayEquality(UInt(100))
  try roundTripArrayEquality(Float(100))
  try roundTripArrayEquality(100.00)
  try roundTripArrayEquality(Data([1, 2, 3]))
  try roundTripArrayEquality(true)
  try roundTripArrayEquality(Date.timeIntervalSinceReferenceDate)
  try roundTripArrayEquality([Key(id: 0): 1, Key(id: 1): 5])
}

struct Key: Codable, Hashable { var id: Int }

func roundTripEquality<T: Codable & Equatable>(_ input: T) throws {
  let value = ["_0": input]
  let decodedValue = try DictionaryDecoder()
    .decode([String: T].self, from: DictionaryEncoder().encode(value))
  #expect(value == decodedValue)
}

func roundTripArrayEquality<T: Codable & Equatable>(_ input: T) throws {
  let value = ["_0": [T].init(repeating: input, count: 10)]
  let decodedValue = try DictionaryDecoder()
    .decode([String: [T]].self, from: DictionaryEncoder().encode(value))
  #expect(value == decodedValue)
}

struct Test<T: Codable>: Codable { let value: T }

struct UserProfile: Codable, Equatable {
  struct Address: Codable, Equatable {
    let street: String
    let city: String
    let postalCode: String
    let country: String
  }

  struct Preferences: Codable, Equatable {
    let notificationsEnabled: Bool
    let favoriteGenres: [String]
    let preferredLanguage: String?
  }

  struct PaymentInfo: Codable, Equatable {
    struct Card: Codable, Equatable {
      let cardType: String
      let lastFourDigits: String
      let expiryDate: String
    }
    let cards: [Card]
  }

  struct ActivityLog: Codable, Equatable {
    struct Activity: Codable, Equatable {
      let timestamp: Date
      let description: String
    }
    let activities: [Activity]
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

let testUser: @Sendable () -> UserProfile = {
  UserProfile(
    id: UUID(),
    name: "Alice Johnson",
    email: "alice@example.com",
    address: UserProfile.Address(
      street: "123 Main St",
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
}
