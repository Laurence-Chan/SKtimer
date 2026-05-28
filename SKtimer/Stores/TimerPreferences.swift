import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class TimerPreferences: ObservableObject {
    static let showMenuBarKey = "SKtimer.Preference.showMenuBar"
    static let showMenuBarCountdownKey = "SKtimer.Preference.showMenuBarCountdown"
    static let notificationSoundFileNameKey = "SKtimer.Preference.notificationSoundFileName"
    static let supportedNotificationSoundExtensions = Set(["aiff", "aif", "wav", "caf"])
    static let supportedNotificationSoundContentTypes = supportedNotificationSoundExtensions
        .flatMap { UTType.types(tag: $0, tagClass: .filenameExtension, conformingTo: .audio) }

    private static let maximumNotificationSoundDuration: TimeInterval = 30

    @Published var showMenuBar: Bool {
        didSet {
            defaults.set(showMenuBar, forKey: Self.showMenuBarKey)
        }
    }

    @Published var showMenuBarCountdown: Bool {
        didSet {
            defaults.set(showMenuBarCountdown, forKey: Self.showMenuBarCountdownKey)
        }
    }

    @Published var notificationSoundFileName: String? {
        didSet {
            defaults.set(notificationSoundFileName, forKey: Self.notificationSoundFileNameKey)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Self.showMenuBarKey) == nil {
            self.showMenuBar = true
        } else {
            self.showMenuBar = defaults.bool(forKey: Self.showMenuBarKey)
        }

        if defaults.object(forKey: Self.showMenuBarCountdownKey) == nil {
            self.showMenuBarCountdown = true
        } else {
            self.showMenuBarCountdown = defaults.bool(forKey: Self.showMenuBarCountdownKey)
        }

        self.notificationSoundFileName = defaults.string(forKey: Self.notificationSoundFileNameKey)
    }

    var notificationSoundDisplayName: String? {
        notificationSoundFileName?.removingPercentEncoding ?? notificationSoundFileName
    }

    var notificationSoundURL: URL? {
        guard let notificationSoundFileName else {
            return nil
        }

        return Self.soundsDirectoryURL.appendingPathComponent(notificationSoundFileName)
    }

    func reset() {
        showMenuBar = true
        showMenuBarCountdown = true
        clearNotificationSound()
    }

    func importNotificationSound(from sourceURL: URL) throws {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try Self.validateNotificationSound(at: sourceURL)
        try FileManager.default.createDirectory(at: Self.soundsDirectoryURL, withIntermediateDirectories: true)

        let fileName = Self.notificationSoundFileName(for: sourceURL)
        let destinationURL = Self.soundsDirectoryURL.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        removeStoredNotificationSound(except: fileName)
        notificationSoundFileName = fileName
    }

    func clearNotificationSound() {
        removeStoredNotificationSound(except: nil)
        notificationSoundFileName = nil
    }

    static func resetStoredValues(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Self.showMenuBarKey)
        defaults.removeObject(forKey: Self.showMenuBarCountdownKey)
        defaults.removeObject(forKey: Self.notificationSoundFileNameKey)
    }

    private func removeStoredNotificationSound(except keptFileName: String?) {
        guard let currentFileName = notificationSoundFileName, currentFileName != keptFileName else {
            return
        }

        let url = Self.soundsDirectoryURL.appendingPathComponent(currentFileName)
        try? FileManager.default.removeItem(at: url)
    }

    private static var soundsDirectoryURL: URL {
        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return libraryURL.appendingPathComponent("Sounds", isDirectory: true)
    }

    private static func notificationSoundFileName(for sourceURL: URL) -> String {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let safeBaseName = baseName.isEmpty ? "notification-sound" : baseName
        let fileExtension = sourceURL.pathExtension.isEmpty ? "aiff" : sourceURL.pathExtension

        return "SKtimer-\(safeBaseName)-\(UUID().uuidString).\(fileExtension)"
    }

    private static func validateNotificationSound(at url: URL) throws {
        let fileExtension = url.pathExtension.lowercased()
        guard supportedNotificationSoundExtensions.contains(fileExtension) else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }

        guard
            let sound = NSSound(contentsOf: url, byReference: false),
            sound.duration > 0,
            sound.duration < maximumNotificationSoundDuration
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }
}
