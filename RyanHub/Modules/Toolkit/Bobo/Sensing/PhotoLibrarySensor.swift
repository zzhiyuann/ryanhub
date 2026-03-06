import Foundation
import Photos
import UIKit

// MARK: - Photo Library Sensor

/// Monitors the system photo library for newly captured photos.
/// When a new photo is taken with the Camera app (or any camera),
/// it emits a .photo event with a compressed thumbnail saved to disk.
final class PhotoLibrarySensor: NSObject {
    private var isRunning = false

    /// Callback invoked when a new photo is detected.
    var onEvent: ((SensingEvent) -> Void)?

    /// Tracks the most recent photo creation date we've processed,
    /// so we only emit events for truly new photos.
    private var lastKnownPhotoDate: Date?

    /// Debounce: ignore photos older than this threshold before start.
    private static let startGracePeriod: TimeInterval = 5

    /// Photos directory for saving thumbnails.
    private static var photosDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bobo/photos", isDirectory: true)
    }

    // MARK: - Lifecycle

    /// Start monitoring the photo library for new photos.
    func start() {
        guard !isRunning else { return }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            // Request permission — will start observing once granted
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.async {
                        self?.beginObserving()
                    }
                }
            }
            return
        }

        beginObserving()
    }

    /// Stop monitoring the photo library.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    /// Check for new photos since last check. Called on foreground resume.
    func checkNow() {
        guard isRunning else { return }
        fetchNewPhotos()
    }

    // MARK: - Internal

    private func beginObserving() {
        guard !isRunning else { return }
        isRunning = true

        // Seed with the latest photo date so we don't import the entire library
        lastKnownPhotoDate = fetchLatestPhotoDate() ?? Date()

        PHPhotoLibrary.shared().register(self)
        print("[PhotoLibrarySensor] Started — monitoring for new photos")
    }

    /// Get the creation date of the most recent photo in the library.
    private func fetchLatestPhotoDate() -> Date? {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        let result = PHAsset.fetchAssets(with: .image, options: options)
        return result.firstObject?.creationDate
    }

    /// Fetch photos added after our last known date and emit events.
    private func fetchNewPhotos() {
        guard let cutoff = lastKnownPhotoDate else { return }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate > %@", cutoff as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result = PHAsset.fetchAssets(with: .image, options: options)
        guard result.count > 0 else { return }

        print("[PhotoLibrarySensor] Found \(result.count) new photo(s)")

        let imageManager = PHImageManager.default()
        let thumbnailSize = CGSize(width: 800, height: 800)
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact

        result.enumerateObjects { [weak self] asset, _, _ in
            guard let self else { return }

            // Skip screenshots — they clutter the timeline
            if asset.mediaSubtypes.contains(.photoScreenshot) {
                self.updateHighWaterMark(asset)
                return
            }

            // Skip RB Meta photos — handled by RBMetaMediaImporter
            if RBMetaMediaImporter.isRBMetaAsset(asset) {
                self.updateHighWaterMark(asset)
                return
            }

            imageManager.requestImage(
                for: asset,
                targetSize: thumbnailSize,
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, info in
                // Skip degraded (low-quality placeholder) callbacks
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded, let image else { return }

                guard let jpegData = image.jpegData(compressionQuality: 0.7) else { return }

                let event = SensingEvent(
                    timestamp: asset.creationDate ?? Date(),
                    modality: .photo,
                    payload: [:]
                )

                // Save thumbnail to disk
                let photosDir = Self.photosDirectory
                try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
                let fileURL = photosDir.appendingPathComponent("\(event.id.uuidString).jpg")
                try? jpegData.write(to: fileURL)

                var mutableEvent = event
                mutableEvent.payload["imageFileId"] = event.id.uuidString
                mutableEvent.payload["source"] = "camera"

                self.onEvent?(mutableEvent)
            }

            self.updateHighWaterMark(asset)
        }
    }

    private func updateHighWaterMark(_ asset: PHAsset) {
        if let date = asset.creationDate, date > (lastKnownPhotoDate ?? .distantPast) {
            lastKnownPhotoDate = date
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension PhotoLibrarySensor: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Dispatch to main to avoid threading issues
        DispatchQueue.main.async { [weak self] in
            self?.fetchNewPhotos()
        }
    }
}
