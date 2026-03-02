import Foundation
import Testing

@testable import SwiftSecuencia

@Suite("ResourceMap Tests")
struct ResourceMapTests {

  // MARK: - Format Resource ID

  @Test("Format resource ID is always r1")
  func formatResourceIDIsR1() {
    let map = ResourceMap()
    #expect(map.formatResourceID() == "r1")
  }

  @Test("Format resource ID is r1 even after registering assets")
  func formatResourceIDUnchangedAfterRegistrations() {
    var map = ResourceMap()
    let uuid = UUID()
    map.registerAsset(uuid)
    #expect(map.formatResourceID() == "r1")
  }

  // MARK: - Sequential Asset IDs

  @Test("First registered asset gets r2")
  func firstAssetGetsR2() {
    var map = ResourceMap()
    let uuid = UUID()
    let id = map.registerAsset(uuid)
    #expect(id == "r2")
  }

  @Test("Second registered asset gets r3")
  func secondAssetGetsR3() {
    var map = ResourceMap()
    let id1 = map.registerAsset(UUID())
    let id2 = map.registerAsset(UUID())
    #expect(id1 == "r2")
    #expect(id2 == "r3")
  }

  @Test("Multiple assets get sequential IDs starting from r2")
  func multipleAssetsGetSequentialIDs() {
    var map = ResourceMap()
    var ids: [String] = []
    for _ in 0..<5 {
      ids.append(map.registerAsset(UUID()))
    }
    #expect(ids == ["r2", "r3", "r4", "r5", "r6"])
  }

  // MARK: - Idempotency

  @Test("Same UUID returns same ID on repeated calls")
  func idempotentRegistration() {
    var map = ResourceMap()
    let uuid = UUID()
    let first = map.registerAsset(uuid)
    let second = map.registerAsset(uuid)
    let third = map.registerAsset(uuid)
    #expect(first == second)
    #expect(second == third)
    #expect(first == "r2")
  }

  @Test("Idempotent registration does not consume new IDs")
  func idempotentDoesNotConsumeIDs() {
    var map = ResourceMap()
    let uuid1 = UUID()
    let uuid2 = UUID()
    map.registerAsset(uuid1)  // r2
    map.registerAsset(uuid1)  // still r2 (idempotent)
    map.registerAsset(uuid1)  // still r2 (idempotent)
    let id2 = map.registerAsset(uuid2)
    #expect(id2 == "r3", "Second unique UUID should get r3, not r5")
  }

  // MARK: - Lookup

  @Test("Lookup returns nil for unregistered UUID")
  func lookupUnregisteredReturnsNil() {
    let map = ResourceMap()
    let uuid = UUID()
    #expect(map.assetResourceID(for: uuid) == nil)
  }

  @Test("Lookup returns correct ID for registered UUID")
  func lookupRegisteredReturnsCorrectID() {
    var map = ResourceMap()
    let uuid = UUID()
    let registered = map.registerAsset(uuid)
    let looked = map.assetResourceID(for: uuid)
    #expect(looked == registered)
    #expect(looked == "r2")
  }

  @Test("Lookup distinguishes between multiple registered UUIDs")
  func lookupDistinguishesMultipleUUIDs() {
    var map = ResourceMap()
    let uuid1 = UUID()
    let uuid2 = UUID()
    let uuid3 = UUID()
    map.registerAsset(uuid1)
    map.registerAsset(uuid2)
    map.registerAsset(uuid3)
    #expect(map.assetResourceID(for: uuid1) == "r2")
    #expect(map.assetResourceID(for: uuid2) == "r3")
    #expect(map.assetResourceID(for: uuid3) == "r4")
  }

  // MARK: - Sorted Bulk Registration

  @Test("registerAssets sorts UUIDs deterministically")
  func registerAssetsSortsDeterministically() {
    // Create UUIDs with known string representations for sorting verification
    let uuid1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let uuid2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let uuid3 = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!

    // Pass them in reverse order
    var map = ResourceMap()
    let result = map.registerAssets([uuid3, uuid1, uuid2])

    // uuid1 sorts first (lowest string), should get r2
    #expect(result[uuid1] == "r2")
    // uuid2 sorts second, should get r3
    #expect(result[uuid2] == "r3")
    // uuid3 sorts last (highest string), should get r4
    #expect(result[uuid3] == "r4")
  }

  @Test("registerAssets produces same mapping regardless of input order")
  func registerAssetsOrderIndependent() {
    let uuid1 = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    let uuid2 = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    let uuid3 = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    var map1 = ResourceMap()
    map1.registerAssets([uuid1, uuid2, uuid3])

    var map2 = ResourceMap()
    map2.registerAssets([uuid3, uuid1, uuid2])

    var map3 = ResourceMap()
    map3.registerAssets([uuid2, uuid3, uuid1])

    // All three should produce identical mappings
    #expect(map1.assetResourceID(for: uuid1) == map2.assetResourceID(for: uuid1))
    #expect(map2.assetResourceID(for: uuid1) == map3.assetResourceID(for: uuid1))

    #expect(map1.assetResourceID(for: uuid2) == map2.assetResourceID(for: uuid2))
    #expect(map2.assetResourceID(for: uuid2) == map3.assetResourceID(for: uuid2))

    #expect(map1.assetResourceID(for: uuid3) == map2.assetResourceID(for: uuid3))
    #expect(map2.assetResourceID(for: uuid3) == map3.assetResourceID(for: uuid3))
  }

  @Test("registerAssets skips already-registered UUIDs")
  func registerAssetsSkipsExisting() {
    var map = ResourceMap()
    let uuid1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let uuid2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let uuid3 = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    // Register uuid2 first (gets r2)
    map.registerAsset(uuid2)
    #expect(map.assetResourceID(for: uuid2) == "r2")

    // Bulk register all three — uuid2 should keep r2
    map.registerAssets([uuid3, uuid1, uuid2])

    #expect(map.assetResourceID(for: uuid2) == "r2", "Previously registered UUID keeps its ID")
    // uuid1 sorts before uuid3, so uuid1 gets r3, uuid3 gets r4
    #expect(map.assetResourceID(for: uuid1) == "r3")
    #expect(map.assetResourceID(for: uuid3) == "r4")
  }

  // MARK: - Asset Count

  @Test("Asset count tracks unique registrations")
  func assetCountTracksUniqueRegistrations() {
    var map = ResourceMap()
    #expect(map.assetCount == 0)

    let uuid1 = UUID()
    map.registerAsset(uuid1)
    #expect(map.assetCount == 1)

    map.registerAsset(uuid1)  // idempotent, no change
    #expect(map.assetCount == 1)

    map.registerAsset(UUID())
    #expect(map.assetCount == 2)
  }
}
