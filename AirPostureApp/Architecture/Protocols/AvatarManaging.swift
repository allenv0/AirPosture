import Foundation

@MainActor
protocol AvatarManaging: AnyObject {
    var selectedAvatar: AvatarType { get set }
}
