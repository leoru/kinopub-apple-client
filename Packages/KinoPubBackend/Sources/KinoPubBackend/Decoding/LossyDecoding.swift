//
//  LossyDecoding.swift
//

import Foundation

/// Throwaway type used to consume an undecodable array element so a lossy decode can advance.
private struct LossySkippedElement: Decodable {}

public extension KeyedDecodingContainer {
  /// Decodes an array of `T` lossily: each element is decoded independently and
  /// any element that fails to decode is skipped instead of throwing and dropping
  /// the entire array. Returns an empty array when the key is absent.
  func decodeLossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T] {
    guard contains(key) else { return [] }
    guard var unkeyed = try? nestedUnkeyedContainer(forKey: key) else { return [] }

    var result: [T] = []
    if let count = unkeyed.count {
      result.reserveCapacity(count)
    }
    while !unkeyed.isAtEnd {
      if let value = try? unkeyed.decode(T.self) {
        result.append(value)
      } else {
        _ = try? unkeyed.decode(LossySkippedElement.self)
      }
    }
    return result
  }
}
