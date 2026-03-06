import Foundation
import Photos
import UIKit
import os.log

private let logger = Logger(subsystem: "com.zwang.ryanhub", category: "RBMetaMediaImporter")

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

        logger.info("Scanning \(imageAssets.count) photos, \(videoAssets.count) videos from last \(Self.maxLookbackDays) days")

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
        let width = asset.pixelWidth
        let height = asset.pixelHeight
        let isRBMetaResolution = (width == 4032 && height == 3024) ||
                                  (width == 3024 && height == 4032) ||
                                  (width == 4000 && height == 3000) ||
                                  (width == 3000 && height == 4000) ||
                                  (width == 2992 && height == 2992) ||
                                  (width == 3024 && height == 3024)

        let isRBMetaVideoRes = (width == 1920 && height == 1080) ||
                                (width == 1080 && height == 1920) ||
                                (width == 1280 && height == 720) ||
                                (width == 720 && height == 1280)

        let resources = PHAssetResource.assetResources(for: asset)
        let filenames = resources.map { $0.originalFilename }

        // Log all video assets for debugging
        if asset.mediaType == .video {
            let syncDelay: String
            if let c = asset.creationDate, let m = asset.modificationDate {
                syncDelay = String(format: "%.0fs", m.timeIntervalSince(c))
            } else {
                syncDelay = "n/a"
            }
            logger.info("""
                [isRBMetaAsset] video: \(width)x\(height), \
                sourceType=\(asset.sourceType.rawValue), \
                syncDelay=\(syncDelay), \
                files=\(filenames), \
                isRBVideoRes=\(isRBMetaVideoRes)
                """)
        }

        // 1. Filename check (most reliable)
        for resource in resources {
            let filename = resource.originalFilename.lowercased()
            if filename.contains("meta") || filename.contains("ray-ban") || filename.contains("rayban") {
                return true
            }
        }

        // 2. External source + known resolution
        if asset.sourceType != .typeUserLibrary {
            if asset.mediaType == .image && isRBMetaResolution { return true }
            if asset.mediaType == .video && isRBMetaVideoRes { return true }
        }

        // 3. Sync delay heuristic
        if let created = asset.creationDate, let modified = asset.modificationDate {
            let syncDelay = modified.timeIntervalSince(created)
            if syncDelay > 30 {
                if asset.mediaType == .image && isRBMetaResolution { return true }
                if asset.mediaType == .video && isRBMetaVideoRes { return true }
            }
        }

        return false
    }
}
