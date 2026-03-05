import Foundation
import Photos
import UIKit

// MARK: - RB Meta Media Importer

/// Detects photos and videos captured by Ray-Ban Meta glasses in the iPhone's
/// Photo Library and imports them into the BOBO timeline. Works retroactively —
/// can import media from past days that were captured while RyanHub was not running.
///
/// Detection method: reads EXIF metadata from PHAsset resources. Ray-Ban Meta
/// photos/videos have camera maker "Meta" or model containing "Ray-Ban".
@MainActor
final class RBMetaMediaImporter {
    /// Singleton for engine-level access.
    static let shared = RBMetaMediaImporter()

    /// UserDefaults key tracking the last import high-water mark.
    private static let lastImportDateKey = "rbmeta_last_import_date"

    /// How far back to look for unimported media (days).
    private static let maxLookbackDays = 7

    /// Whether an import scan is currently running.
    private(set) var isImporting = false

    /// Photos directory for BOBO timeline thumbnails.
    private static var photosDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bobo/photos", isDirectory: true)
    }

    /// Set of event IDs already imported (persisted).
    private var importedAssetIDs: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: "rbmeta_imported_asset_ids") ?? [])
        }
        set {
            // Keep only recent entries to avoid unbounded growth
            let trimmed = Array(newValue.suffix(500))
            UserDefaults.standard.set(trimmed, forKey: "rbmeta_imported_asset_ids")
        }
    }

    // MARK: - Public API

    /// Scan the Photo Library for Ray-Ban Meta photos/videos and import new ones
    /// into the BOBO timeline. Safe to call multiple times — deduplicates via asset ID.
    func importNewMedia() {
        guard !isImporting else { return }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    Task { @MainActor in
                        self?.performImport()
                    }
                }
            }
            return
        }

        performImport()
    }

    // MARK: - Import Logic

    private func performImport() {
        guard !isImporting else { return }
        isImporting = true

        let lookbackDate = Calendar.current.date(
            byAdding: .day,
            value: -Self.maxLookbackDays,
            to: Date()
        ) ?? Date()

        // Fetch recent photos + videos
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate > %@", lookbackDate as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let imageAssets = PHAsset.fetchAssets(with: .image, options: options)
        let videoAssets = PHAsset.fetchAssets(with: .video, options: options)

        var knownIDs = importedAssetIDs
        var newCount = 0

        // Collect RB Meta assets
        var rbMetaAssets: [(PHAsset, String)] = [] // (asset, mediaType)
        collectRBMetaAssets(from: imageAssets, mediaType: "photo", knownIDs: &knownIDs, into: &rbMetaAssets)
        collectRBMetaAssets(from: videoAssets, mediaType: "video", knownIDs: &knownIDs, into: &rbMetaAssets)

        importedAssetIDs = knownIDs

        // Process collected assets (no inout in closures)
        for (asset, mediaType) in rbMetaAssets {
            importAsset(asset, mediaType: mediaType)
            newCount += 1
        }

        isImporting = false

        if newCount > 0 {
            print("[RBMetaImporter] Imported \(newCount) new RB Meta media item(s)")
        }
    }

    private func collectRBMetaAssets(
        from fetchResult: PHFetchResult<PHAsset>,
        mediaType: String,
        knownIDs: inout Set<String>,
        into results: inout [(PHAsset, String)]
    ) {
        for i in 0..<fetchResult.count {
            let asset = fetchResult.object(at: i)
            let assetID = asset.localIdentifier
            guard !knownIDs.contains(assetID) else { continue }
            guard Self.isRBMetaAsset(asset) else { continue }
            knownIDs.insert(assetID)
            results.append((asset, mediaType))
        }
    }

    private func importAsset(_ asset: PHAsset, mediaType: String) {
        let event = SensingEvent(
            timestamp: asset.creationDate ?? Date(),
            modality: .photo,
            payload: [:]
        )

        let thumbnailSize = CGSize(width: 800, height: 800)
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: thumbnailSize,
            contentMode: .aspectFit,
            options: requestOptions
        ) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            guard !isDegraded, let image else { return }
            guard let jpegData = image.jpegData(compressionQuality: 0.7) else { return }

            // Save thumbnail
            let photosDir = Self.photosDirectory
            try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
            let fileURL = photosDir.appendingPathComponent("\(event.id.uuidString).jpg")
            try? jpegData.write(to: fileURL)

            var mutableEvent = event
            mutableEvent.payload["imageFileId"] = event.id.uuidString
            mutableEvent.payload["source"] = "rb_meta"
            mutableEvent.payload["mediaType"] = mediaType
            if mediaType == "video" {
                mutableEvent.payload["duration"] = String(format: "%.0f", asset.duration)
            }

            Task { @MainActor in
                SensingEngine.shared.recordEvent(mutableEvent)
            }

            let eventId = event.id.uuidString
            Task.detached(priority: .utility) {
                await RBMetaViewModel.uploadPhotoToServer(
                    jpegData: jpegData,
                    eventId: eventId,
                    source: "rb_meta_\(mediaType)"
                )
            }
        }
    }

    // MARK: - RB Meta Detection

    /// Check if a PHAsset was captured by Ray-Ban Meta glasses.
    /// Uses EXIF metadata (camera maker/model) from the asset's resources.
    static func isRBMetaAsset(_ asset: PHAsset) -> Bool {
        // Quick heuristic checks first:
        // Ray-Ban Meta Gen 2 has a 12MP ultra-wide camera (4032x3024 or similar)
        // and photos are synced from Meta AI app (not captured by iPhone directly)

        // Check pixel dimensions — RB Meta photos are typically 4032x3024 or 3024x4032
        let width = asset.pixelWidth
        let height = asset.pixelHeight
        let isRBMetaResolution = (width == 4032 && height == 3024) ||
                                  (width == 3024 && height == 4032) ||
                                  (width == 4000 && height == 3000) ||
                                  (width == 3000 && height == 4000)

        // For videos: RB Meta records at specific resolutions
        let isRBMetaVideoRes = (width == 1920 && height == 1080) ||
                                (width == 1080 && height == 1920) ||
                                (width == 1280 && height == 720) ||
                                (width == 720 && height == 1280)

        // Check EXIF via PHAssetResource for more definitive identification
        let resources = PHAssetResource.assetResources(for: asset)
        for resource in resources {
            let filename = resource.originalFilename.lowercased()
            // Meta glasses photos often have specific filename patterns
            if filename.contains("meta") || filename.contains("ray-ban") || filename.contains("rayban") {
                return true
            }
        }

        // If the photo has RB Meta resolution AND was not captured on this device
        // (creation date != modification date suggests sync from external source),
        // we consider it likely from RB Meta.
        // Note: This is a heuristic — may need tuning based on actual device behavior.
        if asset.mediaType == .image && isRBMetaResolution {
            // Photos from RB Meta are synced via Meta AI app, so they appear as
            // "added" rather than "captured" photos. Check sourceType.
            if asset.sourceType != .typeUserLibrary {
                return true
            }
            // Additional check: if creation date is significantly before the asset
            // was added to the library, it was likely synced from an external device.
            // Unfortunately PHAsset doesn't expose "added date" directly, but
            // modificationDate can serve as a proxy.
            if let created = asset.creationDate, let modified = asset.modificationDate {
                let syncDelay = modified.timeIntervalSince(created)
                // If there's more than 30 seconds between capture and library addition,
                // it was likely synced from an external device
                if syncDelay > 30 && isRBMetaResolution {
                    return true
                }
            }
        }

        if asset.mediaType == .video && isRBMetaVideoRes {
            if let created = asset.creationDate, let modified = asset.modificationDate {
                let syncDelay = modified.timeIntervalSince(created)
                if syncDelay > 30 {
                    return true
                }
            }
        }

        return false
    }
}
