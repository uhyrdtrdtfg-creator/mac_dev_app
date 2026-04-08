import Testing
import Foundation
@testable import ConversionTools

@Test func uuidV4Format() { let uuid = UUIDGenerator.generateV4(); #expect(uuid.count == 36); #expect(uuid.contains("-")) }
@Test func uuidBatch() { let batch = UUIDGenerator.generateBatch(5); #expect(batch.count == 5); #expect(Set(batch).count == 5) }
@Test func uuidDecode() { let info = UUIDGenerator.decode(UUIDGenerator.generateV4()); #expect(info != nil); #expect(info?.version == 4) }
@Test func uuidDecodeInvalid() { #expect(UUIDGenerator.decode("not-a-uuid") == nil) }
