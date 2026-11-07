//
//  TimelineAdapters.swift
//  SwiftSecuencia
//
//  Adapters for converting SwiftSecuencia timeline models to OpenFCPXMLKit equivalents.
//
//  These adapters form the bridge layer between SwiftSecuencia's SwiftData-persisted
//  models and OpenFCPXMLKit's value types, which are used for FCPXML export.
//
//  ## Architecture
//
//  SwiftSecuencia models (SwiftData) → Adapter layer → OpenFCPXMLKit types → FCPXML
//
//  Adapters are macOS-only because OpenFCPXMLKit is a macOS-only dependency.
//  On iOS, only audio export and timeline persistence are available; FCPXML export
//  requires macOS.
//
//  ## ResourceMap Integration
//
//  ResourceMap is required for any adapter that converts asset references. All
//  clip-level conversions accept a `resourceMap:` parameter. Raw UUIDs are NEVER
//  passed to OpenFCPXMLKit — all resource IDs flow through ResourceMap.
//
//  ## Timescale Convention
//
//  OpenFCPXMLKit uses timescale 600 for general CMTime calculations (confirmed in
//  Sortie 0 research, TimecodeConverter.swift line 71). When constructing CMTime
//  values that are NOT derived directly from a SwiftSecuencia Timecode (e.g.,
//  defaults and fallbacks), use CMTimeMakeWithSeconds with preferredTimescale 600.
//  Timecodes already encoded in the SwiftSecuencia model are converted verbatim via
//  Timecode.toCMTime(), preserving the original rational value.
//
//  ## Sequence-Level Metadata (Bug B)
//
//  Sortie 0 confirmed that OpenFCPXMLKit adds markers, keywords, chapter-markers, and
//  ratings as direct children of <sequence>. The FCPXML DTD v1.11 does NOT permit
//  these elements as sequence children:
//
//      DTD: sequence = (note?, spine, metadata?)
//
//  Only the <metadata> element is valid at the sequence level. Markers, keywords,
//  chapter-markers, and ratings are only valid inside <asset-clip> elements.
//
//  Decision: Timeline-level markers, keywords, chapter-markers, and ratings stored in
//  the SwiftSecuencia Timeline model are silently dropped during Timeline → OpenFCPXMLKit
//  conversion. The Timeline's <metadata> element IS preserved (it IS valid per DTD).
//
//  Rationale: Attaching them to the first clip is semantically incorrect (they annotate
//  the whole project, not a single clip). Stripping them post-export via XMLDocument
//  adds coupling between the adapter layer and the exporter. Dropping them here is the
//  cleanest approach and is documented in this comment. Clip-level metadata is fully
//  preserved — only the Timeline-level marker/keyword/rating arrays are dropped.
//
//  If sequence-level annotation support is required in a future release, the recommended
//  approach is to file an upstream bug with TheAcharya/OpenFCPXMLKit to fix the DTD
//  non-compliance, and then re-enable the conversion here.

#if os(macOS)
  import Foundation
  import CoreMedia
  import OpenFCPXMLKit

  // MARK: - Timecode → CMTime

  extension Timecode {

    /// Converts this `Timecode` to a `CMTime` for use with OpenFCPXMLKit.
    ///
    /// The conversion preserves the rational time representation exactly:
    /// `CMTime(value: self.value, timescale: self.timescale)`.
    ///
    /// Frame-accurate timing is maintained because the value/timescale pair
    /// is carried verbatim (e.g., 23.976fps frame duration 1001/24000 remains
    /// CMTime(value: 1001, timescale: 24000)).
    ///
    /// - Returns: A `CMTime` with the same rational value as this `Timecode`.
    func toCMTime() -> CMTime {
      CMTime(value: self.value, timescale: self.timescale)
    }
  }

  // MARK: - Metadata Adapters

  extension Marker {

    /// Converts this `SwiftSecuencia.Marker` to a `OpenFCPXMLKit.Marker`.
    ///
    /// All fields are preserved:
    /// - `start` → converted from `Timecode` to `CMTime` (verbatim rational value)
    /// - `duration` → converted from `Timecode` to `CMTime`
    /// - `value`, `note`, `completed` → copied directly
    ///
    /// These adapters are used for CLIP-level markers only. See the file-level comment
    /// for the decision to drop Timeline-level markers (DTD violation in OpenFCPXMLKit).
    ///
    /// - Returns: A `OpenFCPXMLKit.Marker` with equivalent values.
    func toOpenFCPXMLMarker() -> OpenFCPXMLKit.Marker {
      OpenFCPXMLKit.Marker(
        start: start.toCMTime(),
        duration: duration.toCMTime(),
        value: value,
        note: note,
        completed: completed
      )
    }
  }

  extension ChapterMarker {

    /// Converts this `SwiftSecuencia.ChapterMarker` to a `OpenFCPXMLKit.ChapterMarker`.
    ///
    /// All fields are preserved:
    /// - `start` → converted from `Timecode` to `CMTime`
    /// - `posterOffset` → converted from `Timecode?` to `CMTime?`
    /// - `value`, `note` → copied directly
    ///
    /// - Returns: A `OpenFCPXMLKit.ChapterMarker` with equivalent values.
    func toOpenFCPXMLChapterMarker() -> OpenFCPXMLKit.ChapterMarker {
      OpenFCPXMLKit.ChapterMarker(
        start: start.toCMTime(),
        value: value,
        posterOffset: posterOffset?.toCMTime(),
        note: note
      )
    }
  }

  extension Keyword {

    /// Converts this `SwiftSecuencia.Keyword` to a `OpenFCPXMLKit.Keyword`.
    ///
    /// All fields are preserved:
    /// - `start`, `duration` → converted from `Timecode` to `CMTime`
    /// - `value`, `note` → copied directly
    ///
    /// - Returns: A `OpenFCPXMLKit.Keyword` with equivalent values.
    func toOpenFCPXMLKeyword() -> OpenFCPXMLKit.Keyword {
      OpenFCPXMLKit.Keyword(
        start: start.toCMTime(),
        duration: duration.toCMTime(),
        value: value,
        note: note
      )
    }
  }

  extension Rating {

    /// Converts this `SwiftSecuencia.Rating` to a `OpenFCPXMLKit.Rating`.
    ///
    /// All fields are preserved:
    /// - `start`, `duration` → converted from `Timecode` to `CMTime`
    /// - `value` → converted between identical `RatingValue` raw values
    ///   (`"favorite"` / `"rejected"`) via explicit switch
    /// - `note` → copied directly
    ///
    /// The switch is intentional (not a raw-value bridge) so that the compiler
    /// enforces exhaustiveness if either enum gains new cases in the future.
    ///
    /// - Returns: A `OpenFCPXMLKit.Rating` with equivalent values.
    func toOpenFCPXMLRating() -> OpenFCPXMLKit.Rating {
      let openFCPXMLRatingValue: OpenFCPXMLKit.Rating.RatingValue
      switch value {
      case .favorite:
        openFCPXMLRatingValue = .favorite
      case .rejected:
        openFCPXMLRatingValue = .rejected
      }

      return OpenFCPXMLKit.Rating(
        start: start.toCMTime(),
        duration: duration.toCMTime(),
        value: openFCPXMLRatingValue,
        note: note
      )
    }
  }

  extension Metadata {

    /// Converts this `SwiftSecuencia.Metadata` to a `OpenFCPXMLKit.Metadata`.
    ///
    /// The `entries` dictionary is copied directly; both types use `[String: String]`.
    /// This adapter is used for both clip-level and sequence-level metadata.
    /// The `<metadata>` element IS valid as a `<sequence>` child per DTD:
    ///
    ///     DTD: sequence = (note?, spine, metadata?)
    ///
    /// - Returns: A `OpenFCPXMLKit.Metadata` with the same key-value entries.
    func toOpenFCPXMLMetadata() -> OpenFCPXMLKit.Metadata {
      OpenFCPXMLKit.Metadata(entries: entries)
    }
  }

  // MARK: - VideoFormat Adapter

  /// Conversion errors for `VideoFormat → OpenFCPXMLKit.TimelineFormat`.
  enum VideoFormatConversionError: Error, LocalizedError {

    /// The frame dimensions are invalid (width or height ≤ 0).
    case invalidDimensions(width: Int, height: Int)

    public var errorDescription: String? {
      switch self {
      case .invalidDimensions(let width, let height):
        return
          "Invalid video format dimensions: \(width)×\(height). Both width and height must be greater than zero."
      }
    }
  }

  extension VideoFormat {

    /// Converts this `VideoFormat` to a `OpenFCPXMLKit.TimelineFormat`.
    ///
    /// ## Property Mapping
    ///
    /// | SwiftSecuencia   | OpenFCPXMLKit       | Notes                              |
    /// |------------------|-------------------|------------------------------------|
    /// | `width`          | `width`           | Copied directly                    |
    /// | `height`         | `height`          | Copied directly                    |
    /// | `frameDuration`  | `frameDuration`   | `Timecode` → `CMTime` (verbatim)   |
    /// | `colorSpace`     | `colorSpace`      | Enum-to-enum via exhaustive switch |
    /// | `interlaced`     | `interlaced`      | Copied directly                    |
    ///
    /// ## ResourceMap Note
    ///
    /// `VideoFormat` does not reference assets, so no `resourceMap:` parameter is needed.
    /// The ResourceMap is used only for asset UUID → r-prefixed ID conversions.
    ///
    /// ## ColorSpace Mapping
    ///
    /// Both `SwiftSecuencia.ColorSpace` and `OpenFCPXMLKit.ColorSpace` share the same 5 cases,
    /// all mapping 1:1:
    /// - `.rec709`     → `OpenFCPXMLKit.ColorSpace.rec709`
    /// - `.rec2020`    → `OpenFCPXMLKit.ColorSpace.rec2020`
    /// - `.rec2020HLG` → `OpenFCPXMLKit.ColorSpace.rec2020HLG`
    /// - `.rec2020PQ`  → `OpenFCPXMLKit.ColorSpace.rec2020PQ`
    /// - `.sRGB`       → `OpenFCPXMLKit.ColorSpace.sRGB`
    ///
    /// - Returns: A `OpenFCPXMLKit.TimelineFormat` with equivalent properties.
    /// - Throws: `VideoFormatConversionError.invalidDimensions` if dimensions are ≤ 0.
    func toOpenFCPXMLTimelineFormat() throws -> OpenFCPXMLKit.TimelineFormat {
      guard width > 0, height > 0 else {
        throw VideoFormatConversionError.invalidDimensions(width: width, height: height)
      }

      // Explicit switch enforces exhaustiveness at compile time. If SwiftSecuencia.ColorSpace
      // gains new cases, the compiler will require this switch to be updated.
      let openFCPXMLColorSpace: OpenFCPXMLKit.ColorSpace
      switch colorSpace {
      case .rec709:
        openFCPXMLColorSpace = .rec709
      case .rec2020:
        openFCPXMLColorSpace = .rec2020
      case .rec2020HLG:
        openFCPXMLColorSpace = .rec2020HLG
      case .rec2020PQ:
        openFCPXMLColorSpace = .rec2020PQ
      case .sRGB:
        openFCPXMLColorSpace = .sRGB
      }

      return OpenFCPXMLKit.TimelineFormat(
        width: width,
        height: height,
        frameDuration: frameDuration.toCMTime(),
        colorSpace: openFCPXMLColorSpace,
        interlaced: interlaced
      )
    }
  }

  extension Optional where Wrapped == VideoFormat {

    /// Converts an optional `VideoFormat` to a `OpenFCPXMLKit.TimelineFormat`.
    ///
    /// When the format is `nil` (e.g., for audio-only timelines), returns the default
    /// HD 1080p format at 23.976fps with Rec. 709 color space. This matches Final Cut
    /// Pro's default timeline settings for new projects.
    ///
    /// The default frame duration is expressed using timescale 600 (OpenFCPXMLKit's
    /// preferred timescale per Sortie 0 research): `CMTimeMakeWithSeconds(1.0/23.976, 600)`.
    /// However, to preserve rational accuracy for 23.976fps (1001/24000s), we use the
    /// known exact rational: `CMTime(value: 1001, timescale: 24000)`.
    ///
    /// ## Default Format
    ///
    /// When `self` is `nil`:
    /// - Resolution: 1920×1080 (HD 1080p)
    /// - Frame rate: 23.976fps (`CMTime(value: 1001, timescale: 24000)`)
    /// - Color space: Rec. 709
    /// - Scan type: Progressive
    ///
    /// - Returns: A `OpenFCPXMLKit.TimelineFormat`.
    /// - Throws: `VideoFormatConversionError.invalidDimensions` if format has invalid dimensions.
    func toOpenFCPXMLTimelineFormat() throws -> OpenFCPXMLKit.TimelineFormat {
      switch self {
      case .some(let format):
        return try format.toOpenFCPXMLTimelineFormat()
      case .none:
        // Default: HD 1080p @ 23.976fps, Rec. 709 — Final Cut Pro's default timeline format.
        // Use exact rational 1001/24000s (not seconds-based) to preserve frame accuracy.
        let defaultFrameDuration = CMTime(value: 1001, timescale: 24000)
        return OpenFCPXMLKit.TimelineFormat(
          width: 1920,
          height: 1080,
          frameDuration: defaultFrameDuration,
          colorSpace: .rec709,
          interlaced: false
        )
      }
    }
  }

  // MARK: - TimelineClip Adapter

  extension TimelineClip {

    /// Converts this `SwiftSecuencia.TimelineClip` to a `OpenFCPXMLKit.TimelineClip`,
    /// using a `ResourceMap` to translate the `assetStorageId` UUID into a
    /// DTD-compliant r-prefixed resource ID (e.g. `"r2"`, `"r3"`).
    ///
    /// ## Why ResourceMap is Required
    ///
    /// FCPXML DTD requires `<asset-clip ref="...">` values to match the `id` attribute
    /// of an `<asset>` element, which must follow the `r\d+` pattern. Raw UUID strings
    /// (e.g. `"550E8400-E29B-41D4-A716-446655440000"`) are NOT valid FCPXML resource IDs.
    ///
    /// ResourceMap tracks the mapping UUID → r-prefixed ID. Assets must be registered
    /// in the ResourceMap BEFORE calling this adapter (typically in the exporter's
    /// `buildResourceMap()` phase).
    ///
    /// If a UUID is not registered in the ResourceMap, this method falls back to the
    /// UUID string and logs a warning. This should not happen in correctly assembled
    /// export pipelines.
    ///
    /// ## Property Mapping
    ///
    /// | SwiftSecuencia       | OpenFCPXMLKit       | Notes                            |
    /// |----------------------|-------------------|----------------------------------|
    /// | `assetStorageId`     | `assetRef`        | UUID → ResourceMap lookup        |
    /// | `offset`             | `offset`          | `Timecode` → `CMTime`            |
    /// | `duration`           | `duration`        | `Timecode` → `CMTime`            |
    /// | `sourceStart`        | `start`           | `Timecode` → `CMTime`            |
    /// | `lane`               | `lane`            | Copied directly                  |
    /// | `name`               | `name`            | Copied directly (`String?`)      |
    /// | `isVideoDisabled`    | `isVideoDisabled` | Copied directly                  |
    /// | `markers`            | `markers`         | Each converted via adapter       |
    /// | `chapterMarkers`     | `chapterMarkers`  | Each converted via adapter       |
    /// | `keywords`           | `keywords`        | Each converted via adapter       |
    /// | `ratings`            | `ratings`         | Each converted via adapter       |
    /// | `metadata`           | `metadata`        | Converted via adapter, or nil    |
    ///
    /// - Parameter resourceMap: A `ResourceMap` with asset UUIDs pre-registered.
    /// - Returns: A `OpenFCPXMLKit.TimelineClip` with DTD-compliant asset reference.
    func toOpenFCPXMLTimelineClip(resourceMap: ResourceMap) -> OpenFCPXMLKit.TimelineClip {
      // Look up the r-prefixed resource ID. If not found, fall back to UUID string
      // with a runtime assertion to catch misconfigured export pipelines in development.
      let assetRef: String
      if let mappedID = resourceMap.assetResourceID(for: assetStorageId) {
        assetRef = mappedID
      } else {
        assertionFailure(
          "TimelineClip.toOpenFCPXMLTimelineClip: asset UUID \(assetStorageId) was not registered in ResourceMap. "
            + "Register all asset UUIDs before calling adapters. Falling back to UUID string."
        )
        assetRef = assetStorageId.uuidString
      }

      return OpenFCPXMLKit.TimelineClip(
        name: name,
        assetRef: assetRef,
        offset: offset.toCMTime(),
        duration: duration.toCMTime(),
        start: sourceStart.toCMTime(),
        lane: lane,
        isVideoDisabled: isVideoDisabled,
        markers: markers.map { $0.toOpenFCPXMLMarker() },
        chapterMarkers: chapterMarkers.map { $0.toOpenFCPXMLChapterMarker() },
        keywords: keywords.map { $0.toOpenFCPXMLKeyword() },
        ratings: ratings.map { $0.toOpenFCPXMLRating() },
        metadata: metadata?.toOpenFCPXMLMetadata()
      )
    }
  }

  // MARK: - Timeline Adapter

  extension Timeline {

    /// Converts this `SwiftSecuencia.Timeline` to a `OpenFCPXMLKit.Timeline`,
    /// using a `ResourceMap` to translate asset UUID references in clips to
    /// DTD-compliant r-prefixed IDs.
    ///
    /// This is the primary adapter used before FCPXML export. The resulting
    /// `OpenFCPXMLKit.Timeline` is an in-memory value type with no persistence.
    ///
    /// ## ResourceMap Requirements
    ///
    /// All asset UUIDs referenced by clips on this timeline MUST be registered
    /// in `resourceMap` before calling this method. The ResourceMap is typically
    /// built in the exporter's `buildResourceMap()` phase (Sortie 5).
    ///
    /// ## Sequence-Level Metadata Handling (Bug B)
    ///
    /// Timeline-level markers, chapterMarkers, keywords, and ratings are NOT
    /// included in the resulting OpenFCPXMLKit.Timeline. See the file-level comment
    /// for the full explanation.
    ///
    /// Summary: The FCPXML DTD (v1.11) defines `sequence = (note?, spine, metadata?)`.
    /// Markers, keywords, ratings, and chapter-markers are NOT valid sequence children.
    /// OpenFCPXMLKit places them there anyway (a known bug), which causes DTD validation
    /// failures. To produce DTD-valid output, we omit timeline-level markers/keywords/
    /// ratings/chapter-markers entirely and only preserve the `<metadata>` element,
    /// which IS valid as a sequence child.
    ///
    /// ## What IS Preserved
    ///
    /// - `timeline.metadata` → included as `OpenFCPXMLKit.Timeline.metadata`
    ///   (`<metadata>` IS valid per DTD as the last child of `<sequence>`)
    /// - All clip-level markers, keywords, ratings, chapter-markers → preserved on clips
    ///   (valid per DTD inside `<asset-clip>`)
    ///
    /// ## Property Mapping
    ///
    /// | SwiftSecuencia      | OpenFCPXMLKit         | Notes                                      |
    /// |---------------------|---------------------|--------------------------------------------|
    /// | `name`              | `name`              | Copied directly                            |
    /// | `videoFormat`       | `format`            | `Optional<VideoFormat>` → `TimelineFormat` |
    /// | `clips`             | `clips`             | Each clip converted with ResourceMap       |
    /// | `markers`           | (omitted)           | DTD violation at sequence level — dropped  |
    /// | `chapterMarkers`    | (omitted)           | DTD violation at sequence level — dropped  |
    /// | `keywords`          | (omitted)           | DTD violation at sequence level — dropped  |
    /// | `ratings`           | (omitted)           | DTD violation at sequence level — dropped  |
    /// | `metadata`          | `metadata`          | Preserved — `<metadata>` IS valid in DTD   |
    /// | `createdAt`         | `createdAt`         | Copied directly (`Date`)                   |
    /// | `modifiedAt`        | `modifiedAt`        | Copied directly (`Date`)                   |
    ///
    /// - Parameter resourceMap: A `ResourceMap` with all asset UUIDs pre-registered.
    /// - Returns: A `OpenFCPXMLKit.Timeline` ready for FCPXML export.
    /// - Throws: `VideoFormatConversionError.invalidDimensions` if the video format has
    ///   invalid dimensions.
    func toOpenFCPXMLTimeline(resourceMap: ResourceMap) throws -> OpenFCPXMLKit.Timeline {
      OpenFCPXMLKit.Timeline(
        name: name,
        format: try videoFormat.toOpenFCPXMLTimelineFormat(),
        clips: clips.map { $0.toOpenFCPXMLTimelineClip(resourceMap: resourceMap) },
        // Timeline-level markers, chapterMarkers, keywords, and ratings are intentionally
        // omitted. See the detailed explanation in the method documentation and the
        // file-level comment (Sequence-Level Metadata, Bug B).
        markers: [],
        chapterMarkers: [],
        keywords: [],
        ratings: [],
        // <metadata> IS valid as a sequence child per DTD — preserve it.
        metadata: metadata?.toOpenFCPXMLMetadata(),
        createdAt: createdAt,
        modifiedAt: modifiedAt
      )
    }
  }

#endif  // os(macOS)
