//
//  VideoAudio.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public struct VideoAudio: Codable {
    public let id: Int
    public let index: Int
    public let codec: String
    public let channels: Int
    public let lang: String
    public let type: TypeClass?
    public let author: TypeClass?
  
    private enum CodingKeys: String, CodingKey {
        case id = "id"
        case index = "index"
        case codec = "codec"
        case channels = "channels"
        case lang = "lang"
        case type = "type"
        case author = "author"
    }
}
