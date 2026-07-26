import Foundation

/// External person overlay for the credits page. Empty when TMDB is unset or
/// the person id is unknown — the page then draws name + role from kino.pub alone.
public struct PersonMetadata: Sendable, Hashable {
  public var biography: String?
  public var birthday: Date?
  public var placeOfBirth: String?
  public var photo: URL?
  public var knownForDepartment: String?
  public var attribution: Set<MetadataSourceID> = []

  public init(
    biography: String? = nil,
    birthday: Date? = nil,
    placeOfBirth: String? = nil,
    photo: URL? = nil,
    knownForDepartment: String? = nil,
    attribution: Set<MetadataSourceID> = []
  ) {
    self.biography = biography
    self.birthday = birthday
    self.placeOfBirth = placeOfBirth
    self.photo = photo
    self.knownForDepartment = knownForDepartment
    self.attribution = attribution
  }

  public mutating func merge(_ other: PersonMetadata) {
    if biography == nil || biography?.isEmpty == true { biography = other.biography }
    if birthday == nil { birthday = other.birthday }
    if placeOfBirth == nil || placeOfBirth?.isEmpty == true { placeOfBirth = other.placeOfBirth }
    if photo == nil { photo = other.photo }
    if knownForDepartment == nil { knownForDepartment = other.knownForDepartment }
    attribution.formUnion(other.attribution)
  }
}
