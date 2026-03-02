//
//  PipelineNeoTypeAliases.swift
//  SwiftSecuenciaTests
//
//  Type aliases for PipelineNeo types that collide with SwiftSecuencia types.
//
//  These aliases reduce qualification noise in test code. In production code
//  (Sources/), fully-qualified `PipelineNeo.` prefixes are used instead.
//
//  See sortie-0-type-collisions.md for the full list of 24 collisions.
//

#if os(macOS)
  import PipelineNeo

  // MARK: - Timeline & Clip Types

  typealias PNTimeline = PipelineNeo.Timeline
  typealias PNTimelineClip = PipelineNeo.TimelineClip
  typealias PNTimelineFormat = PipelineNeo.TimelineFormat

  // MARK: - Annotation Types

  typealias PNMarker = PipelineNeo.Marker
  typealias PNChapterMarker = PipelineNeo.ChapterMarker
  typealias PNKeyword = PipelineNeo.Keyword
  typealias PNRating = PipelineNeo.Rating
  typealias PNMetadata = PipelineNeo.Metadata

  // MARK: - Format Types

  typealias PNColorSpace = PipelineNeo.ColorSpace

  // MARK: - Export Types

  typealias PNFCPXMLExportAsset = PipelineNeo.FCPXMLExportAsset
  typealias PNFCPXMLExporter = PipelineNeo.FCPXMLExporter
  typealias PNFCPXMLExportError = PipelineNeo.FCPXMLExportError
  typealias PNFCPXMLBundleExporter = PipelineNeo.FCPXMLBundleExporter

  // MARK: - Timeline Operation Types

  typealias PNClipPlacement = PipelineNeo.ClipPlacement
  typealias PNRippleInsertResult = PipelineNeo.RippleInsertResult
  typealias PNClipShift = PipelineNeo.ClipShift
  typealias PNRippleLaneOption = PipelineNeo.RippleLaneOption

  // MARK: - Validation Types

  typealias PNValidationError = PipelineNeo.ValidationError
  typealias PNValidationWarning = PipelineNeo.ValidationWarning
  typealias PNValidationResult = PipelineNeo.ValidationResult
  typealias PNTimelineError = PipelineNeo.TimelineError

  // MARK: - DTD & Utility Types

  typealias PNFCPXMLDTDValidator = PipelineNeo.FCPXMLDTDValidator
  typealias PNFCPXMLValidator = PipelineNeo.FCPXMLValidator
  typealias PNFCPXMLVersion = PipelineNeo.FCPXMLVersion
  typealias PNFCPXMLElementType = PipelineNeo.FCPXMLElementType
  typealias PNFCPXMLUtility = PipelineNeo.FCPXMLUtility

#endif  // os(macOS)
