//
//  OpenFCPXMLKitTypeAliases.swift
//  SwiftSecuenciaTests
//
//  Type aliases for OpenFCPXMLKit types that collide with SwiftSecuencia types.
//
//  These aliases reduce qualification noise in test code. In production code
//  (Sources/), fully-qualified `OpenFCPXMLKit.` prefixes are used instead.
//
//  See sortie-0-type-collisions.md for the full list of 24 collisions.
//

#if os(macOS)
  import OpenFCPXMLKit

  // MARK: - Timeline & Clip Types

  typealias PNTimeline = OpenFCPXMLKit.Timeline
  typealias PNTimelineClip = OpenFCPXMLKit.TimelineClip
  typealias PNTimelineFormat = OpenFCPXMLKit.TimelineFormat

  // MARK: - Annotation Types

  typealias PNMarker = OpenFCPXMLKit.Marker
  typealias PNChapterMarker = OpenFCPXMLKit.ChapterMarker
  typealias PNKeyword = OpenFCPXMLKit.Keyword
  typealias PNRating = OpenFCPXMLKit.Rating
  typealias PNMetadata = OpenFCPXMLKit.Metadata

  // MARK: - Format Types

  typealias PNColorSpace = OpenFCPXMLKit.ColorSpace

  // MARK: - Export Types

  typealias PNFCPXMLExportAsset = OpenFCPXMLKit.FCPXMLExportAsset
  typealias PNFCPXMLExporter = OpenFCPXMLKit.FCPXMLExporter
  typealias PNFCPXMLExportError = OpenFCPXMLKit.FCPXMLExportError
  typealias PNFCPXMLBundleExporter = OpenFCPXMLKit.FCPXMLBundleExporter

  // MARK: - Timeline Operation Types

  typealias PNClipPlacement = OpenFCPXMLKit.ClipPlacement
  typealias PNRippleInsertResult = OpenFCPXMLKit.RippleInsertResult
  typealias PNClipShift = OpenFCPXMLKit.ClipShift
  typealias PNRippleLaneOption = OpenFCPXMLKit.RippleLaneOption

  // MARK: - Validation Types

  typealias PNValidationError = OpenFCPXMLKit.ValidationError
  typealias PNValidationWarning = OpenFCPXMLKit.ValidationWarning
  typealias PNValidationResult = OpenFCPXMLKit.ValidationResult
  typealias PNTimelineError = OpenFCPXMLKit.TimelineError

  // MARK: - DTD & Utility Types

  typealias PNFCPXMLDTDValidator = OpenFCPXMLKit.FCPXMLDTDValidator
  typealias PNFCPXMLValidator = OpenFCPXMLKit.FCPXMLValidator
  typealias PNFCPXMLVersion = OpenFCPXMLKit.FCPXMLVersion
  typealias PNFCPXMLElementType = OpenFCPXMLKit.FCPXMLElementType
  typealias PNFCPXMLUtility = OpenFCPXMLKit.FCPXMLUtility

#endif  // os(macOS)
