import Foundation
import Photos
import UIKit
import os.log

private let logger = Logger(subsystem: "com.zwang.ryanhub", category: "PhotoLibrarySensor")

// MARK: - Photo Library Sensor

/// Monitors the system photo library for newly captured photos AND videos.
/// Classifies each asset by source (camera, rb_meta, etc.) and skips screenshots.
final class PhotoLibrarySensor: NSObject {
    private var isRunning = false

    /// Callback invoked when a new media asset is detected.
    var onEvent: ((SensingEvent) -> Void)?

    /// Callback invoked whenever the photo library changes (regardless of whether
    /// new assets matched our criteria). Used to trigger RBMetaMediaImporter scans.
    var onLibraryChange: (() -> Void)?

    /// Tracks the most recent asset creation date we've processed.
    private var lastKnownAssetDate: Date?

    /// Photos directory for saving thumbnails.
    private static var photosDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("bobo/photos", isDirectory: true)
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
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

    func stop() {
        guard isRunning else { return }
        isRunning = false
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func checkNow() {
        guard isRunning else { return }
        fetchNewAssets()
    }

    // MARK: - Internal

    private func beginObserving() {
        guard !isRunning else { return }
        isRunning = true

        lastKnownAssetDate = fetchLatestAssetDate() ?? Date()

        PHPhotoLibrary.shared().register(self)
        logger.info("Started — monitoring for new photos and videos")
    }

    private func fetchLatestAssetDate() -> Date? {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        // Fetch both images and videos to get the true latest date
        let result = PHAsset.fetchAssets(with: options)
        return result.firstObject?.creationDate
    }

    // MARK: - Fetch & Process

    /// Asset IDs already processed by PhotoLibrarySensor.
    /// Kept separate from RBMeta importer so importer can still reclassify
    /// previously ingested "camera" media as rb_meta when better evidence appears.
    private static let processedIDsKey = "bobo_photo_sensor_processed_asset_ids"

    private var processedAssetIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.processedIDsKey) ?? []) }
        set {
            let trimmed = Array(newValue.suffix(1000))
            UserDefaults.standard.set(trimmed, forKey: Self.processedIDsKey)
        }
    }

    private func fetchNewAssets() {
        guard let cutoff = lastKnownAssetDate else { return }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate > %@", cutoff as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        // Fetch new images by creation date
        let imageResult = PHAsset.fetchAssets(with: .image, options: options)

        // Fetch videos — PHFetchOptions does NOT support OR predicates,
        // so we do two fetches and merge the results.
        let videoByCreation = PHFetchOptions()
        videoByCreation.predicate = NSPredicate(format: "creationDate > %@", cutoff as NSDate)
        videoByCreation.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let videoResult1 = PHAsset.fetchAssets(with: .video, options: videoByCreation)

        // Synced videos may have old creationDate but recent modificationDate
        let videoByModification = PHFetchOptions()
        videoByModification.predicate = NSPredicate(format: "modificationDate > %@", cutoff as NSDate)
        videoByModification.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let videoResult2 = PHAsset.fetchAssets(with: .video, options: videoByModification)

        // Merge both video fetches into a unique set
        var videoAssets: [PHAsset] = []
        var seenVideoIDs = Set<String>()
        for result in [videoResult1, videoResult2] {
            result.enumerateObjects { asset, _, _ in
                if seenVideoIDs.insert(asset.localIdentifier).inserted {
                    videoAssets.append(asset)
                }
            }
        }

        let totalCount = imageResult.count + videoAssets.count
        guard totalCount > 0 else { return }

        logger.info("Found \(imageResult.count) new photo(s), \(videoAssets.count) new video(s)")

        processImageAssets(imageResult)
        processVideoAssetList(videoAssets)
    }

    private func processImageAssets(_ result: PHFetchResult<PHAsset>) {
        let imageManager = PHImageManager.default()
        let thumbnailSize = CGSize(width: 800, height: 800)
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact

        result.enumerateObjects { [weak self] asset, _, _ in
            guard let self else { return }

            // Skip already-processed assets (dedup with RBMetaMediaImporter)
            let assetID = asset.localIdentifier
            guard !self.processedAssetIDs.contains(assetID) else {
                self.updateHighWaterMark(asset)
                return
            }

            // Skip screenshots
            if asset.mediaSubtypes.contains(.photoScreenshot) {
                self.updateHighWaterMark(asset)
                return
            }

            // Skip RB Meta assets — RBMetaMediaImporter handles them exclusively
            // to avoid duplicate timeline events from concurrent processing.
            if RBMetaMediaImporter.isRBMetaAsset(asset) {
                self.updateHighWaterMark(asset)
                return
            }

            let source = Self.classifySource(asset)
            Self.logAssetDetails(asset, mediaType: "photo", classified: source)

            // Mark as processed
            self.processedAssetIDs.insert(assetID)

            imageManager.requestImage(
                for: asset,
                targetSize: thumbnailSize,
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded, let image else { return }
                guard let jpegData = image.jpegData(compressionQuality: 0.7) else { return }

                var event = self.saveAndCreateEvent(
                    jpegData: jpegData,
                    timestamp: Self.eventTimestamp(for: asset)
                )
                event.payload["source"] = source
                event.payload["mediaType"] = "photo"
                event.payload["assetId"] = asset.localIdentifier
                self.onEvent?(event)
            }

            self.updateHighWaterMark(asset)
        }
    }

    private func processVideoAssetList(_ assets: [PHAsset]) {
        let imageManager = PHImageManager.default()
        let thumbnailSize = CGSize(width: 800, height: 800)
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .exact

        for asset in assets {
            // Skip already-processed assets (dedup with RBMetaMediaImporter)
            let assetID = asset.localIdentifier
            guard !processedAssetIDs.contains(assetID) else {
                updateHighWaterMark(asset)
                continue
            }

            // Skip RB Meta assets — RBMetaMediaImporter handles them exclusively
            if RBMetaMediaImporter.isRBMetaAsset(asset) {
                updateHighWaterMark(asset)
                continue
            }

            let source = Self.classifySource(asset)
            Self.logAssetDetails(asset, mediaType: "video", classified: source)

            // Mark as processed
            processedAssetIDs.insert(assetID)

            // Get video thumbnail (same flow as photos — all videos go to timeline)
            imageManager.requestImage(
                for: asset,
                targetSize: thumbnailSize,
                contentMode: .aspectFit,
                options: requestOptions
            ) { [weak self] image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded, let image else { return }
                guard let jpegData = image.jpegData(compressionQuality: 0.7) else { return }

                guard let self else { return }
                var event = self.saveAndCreateEvent(
                    jpegData: jpegData,
                    timestamp: Self.eventTimestamp(for: asset)
                )
                event.payload["source"] = source
                event.payload["mediaType"] = "video"
                event.payload["duration"] = String(format: "%.0f", asset.duration)
                event.payload["assetId"] = asset.localIdentifier
                self.onEvent?(event)
            }

            updateHighWaterMark(asset)
        }
    }

    // MARK: - Helpers

    private func saveAndCreateEvent(jpegData: Data, timestamp: Date) -> SensingEvent {
        let event = SensingEvent(
            timestamp: timestamp,
            modality: .photo,
            payload: [:]
        )

        let photosDir = Self.photosDirectory
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        let fileURL = photosDir.appendingPathComponent("\(event.id.uuidString).jpg")
        try? jpegData.write(to: fileURL)

        var mutableEvent = event
        mutableEvent.payload["imageFileId"] = event.id.uuidString
        return mutableEvent
    }

    // MARK: - Source Classification

    /// Classify a PHAsset source: "rb_meta", "camera", or "camera" (default).
    static func classifySource(_ asset: PHAsset) -> String {
        // 1. Check filenames for Meta/Ray-Ban patterns (most reliable)
        let resources = PHAssetResource.assetResources(for: asset)
        for resource in resources {
            let filename = resource.originalFilename.lowercased()
            if filename.contains("meta") || filename.contains("ray-ban") || filename.contains("rayban") {
                return "rb_meta"
            }
        }

        // 2. External source + known RB Meta resolution
        let w = asset.pixelWidth
        let h = asset.pixelHeight
        let isRBPhotoRes = (w == 4032 && h == 3024) || (w == 3024 && h == 4032) ||
                           (w == 4000 && h == 3000) || (w == 3000 && h == 4000) ||
                           (w == 2992 && h == 2992) || (w == 3024 && h == 3024)
        let isRBVideoRes = (w == 1920 && h == 1080) || (w == 1080 && h == 1920) ||
                           (w == 1280 && h == 720) || (w == 720 && h == 1280)

        if asset.sourceType != .typeUserLibrary {
            if asset.mediaType == .image && isRBPhotoRes { return "rb_meta" }
            if asset.mediaType == .video && isRBVideoRes { return "rb_meta" }
        }

        // 3. Sync delay heuristic: capture time vs library addition time
        if let created = asset.creationDate, let modified = asset.modificationDate {
            let syncDelay = modified.timeIntervalSince(created)
            if syncDelay > 30 {
                if asset.mediaType == .image && isRBPhotoRes { return "rb_meta" }
                if asset.mediaType == .video && isRBVideoRes { return "rb_meta" }
            }
        }

        return "camera"
    }

    private static func logAssetDetails(_ asset: PHAsset, mediaType: String, classified: String) {
        let resources = PHAssetResource.assetResources(for: asset)
        let filenames = resources.map { $0.originalFilename }
        let syncDelay: String
        if let c = asset.creationDate, let m = asset.modificationDate {
            syncDelay = String(format: "%.0fs", m.timeIntervalSince(c))
        } else {
            syncDelay = "n/a"
        }
        logger.info("""
            New \(mediaType): \(asset.pixelWidth)x\(asset.pixelHeight), \
            sourceType=\(asset.sourceType.rawValue), \
            subtypes=\(asset.mediaSubtypes.rawValue), \
            syncDelay=\(syncDelay), \
            files=\(filenames), \
            -> \(classified)
            """)
    }

    private func updateHighWaterMark(_ asset: PHAsset) {
        if let date = asset.creationDate, date > (lastKnownAssetDate ?? .distantPast) {
            lastKnownAssetDate = date
        }
    }

    /// Timeline timestamp for media events.
    /// Prefer modificationDate so recently synced imports show up immediately.
    private static func eventTimestamp(for asset: PHAsset) -> Date {
        asset.modificationDate ?? asset.creationDate ?? Date()
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension PhotoLibrarySensor: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            self?.fetchNewAssets()
            self?.onLibraryChange?()
        }
    }
}
