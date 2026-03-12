import Foundation

struct UserDTO: Codable {
    let id: Int
    let email: String
}

struct LoginResponse: Codable {
    let user: UserDTO
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

struct RefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

struct Track: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let thumbnail: String
    let duration: Int
    let viewCount: Int?
    let likeCount: Int?
    let rowId: Int?

    var formattedDuration: String {
        let h = duration / 3600
        let m = (duration % 3600) / 60
        let s = duration % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artist
        case thumbnail
        case duration
        case viewCount
        case likeCount
        case rowId = "_rowId"
    }
}

struct SearchResult: Codable {
    let tracks: [Track]
    let nextPageToken: String?
}

struct Playlist: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct PlayerState: Codable {
    let queue: [Track]
    let currentIndex: Int
    let position: Double
    let repeatMode: String
    let currentTrack: Track?
}

struct SavePlayerStateRequest: Codable {
    let queue: [Track]
    let currentIndex: Int
    let position: Double
    let repeatMode: String
    let currentTrack: Track?
}

struct FavoritesResponse: Codable {
    let tracks: [Track]
}

struct AddTrackRequest: Codable {
    let video_id: String
    let title: String
    let artist: String
    let thumbnail: String
    let duration: Int
    let viewCount: Int
    let likeCount: Int
}

struct AddFavoriteRequest: Codable {
    let video_id: String
    let title: String
    let artist: String
    let thumbnail: String
    let duration: Int
}


struct APIErrorResponse: Codable, Error {
    struct ErrorBody: Codable {
        let code: String
        let message: String
    }
    let error: ErrorBody
}
