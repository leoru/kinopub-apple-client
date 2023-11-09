//
//  PlayableItem.swift
//
//
//  Created by Kirill Kunst on 9.11.2023.
//

import Foundation

public protocol PlayableItem: Identifiable, Hashable, Equatable {
  var id: Int { get }
  var files: [FileInfo] { get }
  var trailer: Trailer? { get }
}
