#!/usr/bin/env swift

import AppKit
import Foundation

// MARK: - Configuration

let motionTemplatesBase = NSHomeDirectory() + "/Movies/Motion Templates.localized"
let titlesBase = motionTemplatesBase + "/Titles.localized/casting-software-spells"
let generatorsBase = motionTemplatesBase + "/Generators.localized/casting-software-spells"

// MARK: - Layout Constants
//
// Design spec (SUP-INFOGRAPHICS-PLAN.md): Left Panel = x=150 to x=1400 on the 4096×2160 canvas.
// infoPanelX/Width describe the zone on the full 4K canvas (used for coordinate reference).
// Infographic elements within this zone are positioned relative to the panel's local coordinate space.

let infoPanelX: Double = 150          // Left edge of infographic panel (canvas coords)
let infoPanelY: Double = 40           // Top margin for infographic panel
let infoPanelWidth: Double = 1250     // Width of infographic panel (150 → 1400)
let infoPanelHeight: Double = 2000    // Height of infographic panel (canvas coords)

// MARK: - Color Palette

struct RGBColor {
  let r: Double
  let g: Double
  let b: Double
}

let missionRed = RGBColor(r: 0.902, g: 0.353, b: 0.314)      // RGB(230, 90, 80)
let operatorGreen = RGBColor(r: 0.298, g: 0.902, b: 0.400)    // RGB(76, 230, 102)
let intelBlue = RGBColor(r: 0.314, g: 0.706, b: 0.902)        // RGB(80, 180, 230)
let cautionYellow = RGBColor(r: 1.000, g: 0.800, b: 0.200)    // RGB(255, 204, 51)
let neutralGray = RGBColor(r: 0.706, g: 0.706, b: 0.706)      // RGB(180, 180, 180)
let commandWhite = RGBColor(r: 1.0, g: 1.0, b: 1.0)           // RGB(255, 255, 255)

// MARK: - Font Awesome 5 Pro Unicode Constants

struct FAIcon {
  static let userShield = "\u{f505}"
  static let exchangeAlt = "\u{f362}"
  static let fighterJet = "\u{f0fb}"
  static let codeBranch = "\u{f126}"
  static let exclamationTriangle = "\u{f071}"
  static let book = "\u{f02d}"
  static let checkCircle = "\u{f058}"
  static let timesCircle = "\u{f057}"
  static let bug = "\u{f188}"
  static let fileCode = "\u{f1c9}"
  static let shieldAlt = "\u{f3ed}"
  static let clock = "\u{f017}"
  static let memory = "\u{f538}"
  static let chartBar = "\u{f080}"
  static let brain = "\u{f5dc}"
  static let road = "\u{f018}"
  static let broom = "\u{f51a}"
  static let search = "\u{f002}"
  static let lightbulb = "\u{f0eb}"
  static let listOl = "\u{f0cb}"
  static let lock = "\u{f023}"
  static let bullseye = "\u{f140}"
  static let powerOff = "\u{f011}"
  static let fileAlt = "\u{f15c}"
  static let sitemap = "\u{f0e8}"
  static let syncAlt = "\u{f2f1}"
  static let circle = "\u{f111}"
  static let shieldCheck = "\u{f2f7}"
  static let arrowDown = "\u{f063}"
}

// MARK: - Models

struct ExecutionPlan {
  let featureName: String
  let operationWord: String  // e.g. "OPERATION"
  let operationName: String  // e.g. "PIPELINE EXODUS"
  let branch: String
  let iteration: String
  let sorties: [Sortie]
}

struct Sortie {
  let number: Int
  let task: String
  let model: String
  let context: String
  let deliverables: String
  let status: SortieStatus
}

enum SortieStatus: String {
  case pending = "pending"
  case inProgress = "in_progress"
  case complete = "complete"
  case blocked = "blocked"

  var displayLabel: String {
    switch self {
    case .pending: return "PENDING"
    case .inProgress: return "IN PROGRESS"
    case .complete: return "COMPLETE"
    case .blocked: return "BLOCKED"
    }
  }

  var color: (r: CGFloat, g: CGFloat, b: CGFloat) {
    switch self {
    case .pending: return (0.5, 0.5, 0.5)
    case .inProgress: return (1.0, 0.8, 0.2)
    case .complete: return (0.3, 0.9, 0.4)
    case .blocked: return (0.9, 0.3, 0.3)
    }
  }
}

/// Represents one chapter of the EP01 infographic sequence.
/// Each chapter corresponds to one audio clip and one .motn template.
struct Chapter {
  let number: Int          // e.g. 1, 2, 3... (note: 2A=18, 2B=19, 2C=20 for sub-chapters)
  let tag: String          // e.g. "CH01", "CH02", "CH02A"
  let slug: String         // e.g. "opening", "mission-briefing"
  let title: String        // e.g. "Opening", "Mission Briefing"
  let startSeconds: Double
  let durationSeconds: Double
  let heading: String      // Main heading text for the infographic
  let infographicLines: [InfographicElement]
}

/// An element within a chapter's infographic layer
struct InfographicElement {
  let text: String
  let font: String
  let size: Int
  let x: Double
  let y: Double
  let color: RGBColor
  let alignment: Int      // 0=left, 1=center, 2=right
  let isIcon: Bool        // If true, use Font Awesome font
  let isProgressBar: Bool // If true, render as progress bar (text = percentage string like "0.65")
  let barWidth: Double    // Width of progress bar in canvas pixels (used when isProgressBar=true)

  /// Convenience initializer for standard text or icon elements (backward compatible)
  init(
    text: String, font: String, size: Int,
    x: Double, y: Double, color: RGBColor,
    alignment: Int, isIcon: Bool
  ) {
    self.text = text
    self.font = font
    self.size = size
    self.x = x
    self.y = y
    self.color = color
    self.alignment = alignment
    self.isIcon = isIcon
    self.isProgressBar = false
    self.barWidth = 0
  }

  /// Initializer for progress bar elements
  init(
    percentage: Double, barWidth: Double,
    x: Double, y: Double, color: RGBColor
  ) {
    self.text = String(percentage)
    self.font = ""
    self.size = 24
    self.x = x
    self.y = y
    self.color = color
    self.alignment = 1
    self.isIcon = false
    self.isProgressBar = true
    self.barWidth = barWidth
  }
}

// MARK: - Chapter Definitions

func allChapters() -> [Chapter] {
  return [
    Chapter(
      number: 1, tag: "CH01", slug: "opening", title: "Opening",
      startSeconds: 0.000, durationSeconds: 17.408,
      heading: "MISSION SUPERVISOR",
      infographicLines: [
        InfographicElement(text: FAIcon.userShield, font: "FontAwesome5ProSolid", size: 120,
                           x: 600, y: 500, color: commandWhite, alignment: 1, isIcon: true),
        InfographicElement(text: "MISSION SUPERVISOR", font: "HelveticaNeue-CondensedBold", size: 64,
                           x: 600, y: 350, color: commandWhite, alignment: 1, isIcon: false),
        InfographicElement(text: "FIELD REPORT COMMENCING", font: "HelveticaNeue-Light", size: 36,
                           x: 600, y: 270, color: neutralGray, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 2, tag: "CH02", slug: "mission-briefing", title: "Mission Briefing",
      startSeconds: 17.408, durationSeconds: 16.043,
      heading: "OBJECTIVE: LIBRARY SWAP",
      infographicLines: [
        InfographicElement(text: "OBJECTIVE: LIBRARY SWAP", font: "HelveticaNeue-CondensedBold", size: 56,
                           x: 600, y: 650, color: commandWhite, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.exchangeAlt, font: "FontAwesome5ProSolid", size: 80,
                           x: 600, y: 480, color: intelBlue, alignment: 1, isIcon: true),
        InfographicElement(text: "Pipeline", font: "HelveticaNeue-Bold", size: 44,
                           x: 350, y: 400, color: missionRed, alignment: 1, isIcon: false),
        InfographicElement(text: "Pipeline Neo", font: "HelveticaNeue-Bold", size: 44,
                           x: 850, y: 400, color: operatorGreen, alignment: 1, isIcon: false),
        InfographicElement(text: "\"Should've been a Tuesday\"", font: "HelveticaNeue-LightItalic", size: 32,
                           x: 600, y: 250, color: neutralGray, alignment: 1, isIcon: false),
      ]),
    // CH02A: Original Requirements checklist
    Chapter(
      number: 18, tag: "CH02A", slug: "original-requirements", title: "Original Requirements",
      startSeconds: 17.408, durationSeconds: 5.0,
      heading: "ORIGINAL REQUIREMENTS",
      infographicLines: [
        InfographicElement(text: "ORIGINAL REQUIREMENTS", font: "HelveticaNeue-CondensedBold", size: 52,
                           x: 600, y: 700, color: intelBlue, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.fileAlt, font: "FontAwesome5ProSolid", size: 60,
                           x: 600, y: 560, color: intelBlue, alignment: 1, isIcon: true),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 32,
                           x: 200, y: 450, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Port SwiftSecuencia to Pipeline Neo", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 445, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 32,
                           x: 200, y: 385, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Preserve all existing tests", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 380, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 32,
                           x: 200, y: 320, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Maintain iOS compatibility", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 315, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 32,
                           x: 200, y: 255, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "No breaking API changes", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 250, color: commandWhite, alignment: 0, isIcon: false),
      ]),
    // CH02B: Breakdown + 4 refinement passes
    Chapter(
      number: 19, tag: "CH02B", slug: "breakdown-refinement", title: "Breakdown and Refinement",
      startSeconds: 22.408, durationSeconds: 5.5,
      heading: "BREAKDOWN + REFINEMENT",
      infographicLines: [
        InfographicElement(text: "BREAKDOWN + REFINEMENT", font: "HelveticaNeue-CondensedBold", size: 52,
                           x: 600, y: 700, color: cautionYellow, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.sitemap, font: "FontAwesome5ProSolid", size: 60,
                           x: 600, y: 560, color: cautionYellow, alignment: 1, isIcon: true),
        InfographicElement(text: "Pass 1: API surface mapping", font: "HelveticaNeue-Light", size: 32,
                           x: 200, y: 450, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: "Pass 2: Type collision resolution", font: "HelveticaNeue-Light", size: 32,
                           x: 200, y: 385, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: "Pass 3: Adapter pattern design", font: "HelveticaNeue-Light", size: 32,
                           x: 200, y: 320, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: "Pass 4: Test migration strategy", font: "HelveticaNeue-Light", size: 32,
                           x: 200, y: 255, color: commandWhite, alignment: 0, isIcon: false),
      ]),
    // CH02C: Context reset + 4 agent jets
    Chapter(
      number: 20, tag: "CH02C", slug: "context-reset", title: "Context Reset",
      startSeconds: 27.908, durationSeconds: 5.543,
      heading: "CONTEXT RESET",
      infographicLines: [
        InfographicElement(text: "CONTEXT RESET", font: "HelveticaNeue-CondensedBold", size: 56,
                           x: 600, y: 700, color: missionRed, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.syncAlt, font: "FontAwesome5ProSolid", size: 80,
                           x: 600, y: 550, color: missionRed, alignment: 1, isIcon: true),
        InfographicElement(text: FAIcon.fighterJet, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 420, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "Agent 1: Architecture", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 415, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.fighterJet, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 360, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "Agent 2: Adapters", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 355, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.fighterJet, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 300, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "Agent 3: Tests", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 295, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.fighterJet, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 240, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "Agent 4: Integration", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 235, color: commandWhite, alignment: 0, isIcon: false),
      ]),
    Chapter(
      number: 3, tag: "CH03", slug: "the-mess", title: "Mission Zero: The Mess",
      startSeconds: 33.451, durationSeconds: 21.248,
      heading: "ITERATION ZERO: THE MESS",
      infographicLines: [
        InfographicElement(text: "ITERATION ZERO: THE MESS", font: "HelveticaNeue-CondensedBold", size: 52,
                           x: 600, y: 700, color: missionRed, alignment: 1, isIcon: false),
        // Progress bar: 24/37 sorties = 64.8% complete (Caution Yellow = incomplete mission)
        InfographicElement(percentage: 0.648, barWidth: 700, x: 550, y: 610, color: cautionYellow),
        InfographicElement(text: "24 / 37 SORTIES", font: "HelveticaNeue-Bold", size: 32,
                           x: 550, y: 570, color: cautionYellow, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.exclamationTriangle, font: "FontAwesome5ProSolid", size: 44,
                           x: 200, y: 480, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "30+ COMMITS", font: "HelveticaNeue-Bold", size: 38,
                           x: 280, y: 480, color: missionRed, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.fighterJet, font: "FontAwesome5ProSolid", size: 44,
                           x: 200, y: 390, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "24/37 SORTIES EXECUTED", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 390, color: cautionYellow, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.codeBranch, font: "FontAwesome5ProSolid", size: 44,
                           x: 200, y: 300, color: missionRed, alignment: 0, isIcon: true),
        InfographicElement(text: "OVER-ENGINEERED", font: "HelveticaNeue-Bold", size: 38,
                           x: 280, y: 300, color: missionRed, alignment: 0, isIcon: false),
      ]),
    Chapter(
      number: 4, tag: "CH04", slug: "resource-ids", title: "Discovery: Resource IDs",
      startSeconds: 54.699, durationSeconds: 25.301,
      heading: "DISCOVERY: RESOURCE IDs",
      infographicLines: [
        InfographicElement(text: "DISCOVERY: RESOURCE IDs", font: "HelveticaNeue-CondensedBold", size: 52,
                           x: 600, y: 700, color: intelBlue, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.timesCircle, font: "FontAwesome5ProSolid", size: 44,
                           x: 200, y: 520, color: missionRed, alignment: 0, isIcon: true),
        InfographicElement(text: "UUID: \"abc-123-def-456\"", font: "Courier-Bold", size: 32,
                           x: 280, y: 520, color: missionRed, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 44,
                           x: 200, y: 430, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "DTD Spec: \"r1\", \"r2\", \"r3\"", font: "Courier-Bold", size: 32,
                           x: 280, y: 430, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.book, font: "FontAwesome5ProSolid", size: 44,
                           x: 200, y: 280, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "RTFM: 10 min \u{2192} 4 sorties saved", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 280, color: intelBlue, alignment: 0, isIcon: false),
      ]),
    Chapter(
      number: 5, tag: "CH05", slug: "library-bug", title: "Discovery: Library Bug",
      startSeconds: 80.000, durationSeconds: 27.691,
      heading: "DISCOVERY: LIBRARY NAME BUG",
      infographicLines: [
        InfographicElement(text: "DISCOVERY: LIBRARY NAME BUG", font: "HelveticaNeue-CondensedBold", size: 48,
                           x: 600, y: 700, color: intelBlue, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.bug, font: "FontAwesome5ProSolid", size: 60,
                           x: 600, y: 560, color: missionRed, alignment: 1, isIcon: true),
        InfographicElement(text: "<library name=\"invalid\">", font: "Courier", size: 28,
                           x: 600, y: 460, color: missionRed, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.timesCircle, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 350, color: missionRed, alignment: 0, isIcon: true),
        InfographicElement(text: "Regex on XML", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 350, color: missionRed, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 270, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "XMLDocument (civilized)", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 270, color: operatorGreen, alignment: 0, isIcon: false),
      ]),
    Chapter(
      number: 6, tag: "CH06", slug: "empty-timelines", title: "Discovery: Empty Timelines",
      startSeconds: 107.691, durationSeconds: 18.816,
      heading: "DISCOVERY: EMPTY TIMELINES",
      infographicLines: [
        InfographicElement(text: "DISCOVERY: EMPTY TIMELINES", font: "HelveticaNeue-CondensedBold", size: 48,
                           x: 600, y: 700, color: intelBlue, alignment: 1, isIcon: false),
        InfographicElement(text: "Timeline \u{2192} Clip count == 0?", font: "Courier-Bold", size: 28,
                           x: 600, y: 540, color: commandWhite, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 32,
                           x: 300, y: 450, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Yes \u{2192} Hand-craft FCPXML", font: "Courier", size: 26,
                           x: 370, y: 450, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.timesCircle, font: "FontAwesome5ProSolid", size: 32,
                           x: 300, y: 370, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "No \u{2192} Pipeline Neo export", font: "Courier", size: 26,
                           x: 370, y: 370, color: intelBlue, alignment: 0, isIcon: false),
        InfographicElement(text: "\"Not elegant. But correct.\"", font: "HelveticaNeue-LightItalic", size: 32,
                           x: 600, y: 230, color: neutralGray, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 7, tag: "CH07", slug: "metadata-correction", title: "Discovery: Metadata Correction",
      startSeconds: 126.507, durationSeconds: 24.917,
      heading: "DISCOVERY: METADATA CORRECTION",
      infographicLines: [
        InfographicElement(text: "DISCOVERY: METADATA", font: "HelveticaNeue-CondensedBold", size: 48,
                           x: 600, y: 700, color: intelBlue, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.timesCircle, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 560, color: missionRed, alignment: 0, isIcon: true),
        InfographicElement(text: "ASSUMED: \"No metadata export\"", font: "HelveticaNeue-Bold", size: 32,
                           x: 280, y: 560, color: missionRed, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 470, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "VERIFIED: Lines 143-193", font: "HelveticaNeue-Bold", size: 32,
                           x: 280, y: 470, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: "\u{2022} Markers  \u{2022} Keywords  \u{2022} Ratings", font: "HelveticaNeue-Light", size: 30,
                           x: 600, y: 330, color: commandWhite, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 8, tag: "CH08", slug: "time-format", title: "Discovery: Time Format",
      startSeconds: 151.424, durationSeconds: 25.088,
      heading: "DISCOVERY: TIME FORMAT",
      infographicLines: [
        InfographicElement(text: "DISCOVERY: TIME FORMAT", font: "HelveticaNeue-CondensedBold", size: 52,
                           x: 600, y: 700, color: intelBlue, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.clock, font: "FontAwesome5ProSolid", size: 60,
                           x: 600, y: 560, color: intelBlue, alignment: 1, isIcon: true),
        InfographicElement(text: "Old: 24000/24000s = 1.0s", font: "Courier-Bold", size: 30,
                           x: 600, y: 450, color: neutralGray, alignment: 1, isIcon: false),
        InfographicElement(text: "New: 600/600s = 1.0s", font: "Courier-Bold", size: 30,
                           x: 600, y: 380, color: commandWhite, alignment: 1, isIcon: false),
        InfographicElement(text: "Same value, different representation", font: "HelveticaNeue-LightItalic", size: 28,
                           x: 600, y: 300, color: neutralGray, alignment: 1, isIcon: false),
        InfographicElement(text: "\"Compare seconds, not strings\"", font: "HelveticaNeue-Bold", size: 34,
                           x: 600, y: 210, color: cautionYellow, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 9, tag: "CH09", slug: "type-collisions", title: "Discovery: Type Collisions",
      startSeconds: 176.512, durationSeconds: 26.197,
      heading: "DISCOVERY: TYPE COLLISIONS",
      infographicLines: [
        InfographicElement(text: "DISCOVERY: TYPE COLLISIONS", font: "HelveticaNeue-CondensedBold", size: 48,
                           x: 600, y: 700, color: missionRed, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.exclamationTriangle, font: "FontAwesome5ProSolid", size: 50,
                           x: 600, y: 580, color: cautionYellow, alignment: 1, isIcon: true),
        InfographicElement(text: "Timeline", font: "Courier-Bold", size: 32,
                           x: 200, y: 480, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: "Marker", font: "Courier-Bold", size: 32,
                           x: 200, y: 420, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: "ChapterMarker", font: "Courier-Bold", size: 32,
                           x: 200, y: 360, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: "Keyword", font: "Courier-Bold", size: 32,
                           x: 200, y: 300, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.memory, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 210, color: missionRed, alignment: 0, isIcon: true),
        InfographicElement(text: "Context budget killer", font: "HelveticaNeue-Bold", size: 34,
                           x: 280, y: 210, color: missionRed, alignment: 0, isIcon: false),
      ]),
    Chapter(
      number: 10, tag: "CH10", slug: "process-failures", title: "Process Failures",
      startSeconds: 202.709, durationSeconds: 28.117,
      heading: "PROCESS FAILURES",
      infographicLines: [
        InfographicElement(text: "PROCESS FAILURES", font: "HelveticaNeue-CondensedBold", size: 52,
                           x: 600, y: 700, color: missionRed, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.chartBar, font: "FontAwesome5ProSolid", size: 50,
                           x: 200, y: 560, color: missionRed, alignment: 0, isIcon: true),
        InfographicElement(text: "37 total sorties", font: "HelveticaNeue-Bold", size: 36,
                           x: 300, y: 560, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: "10-12 meaningful (32%)", font: "HelveticaNeue-Light", size: 30,
                           x: 320, y: 490, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: "25-27 overhead (68%)", font: "HelveticaNeue-Light", size: 30,
                           x: 320, y: 430, color: missionRed, alignment: 0, isIcon: false),
        InfographicElement(text: "Context Overruns: S3, S6, S7, S22", font: "HelveticaNeue-Bold", size: 30,
                           x: 600, y: 330, color: cautionYellow, alignment: 1, isIcon: false),
        InfographicElement(text: "S22: 142% OVERRUN", font: "HelveticaNeue-CondensedBold", size: 44,
                           x: 600, y: 240, color: missionRed, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 11, tag: "CH11", slug: "what-worked", title: "What Worked",
      startSeconds: 230.826, durationSeconds: 24.192,
      heading: "WHAT WORKED",
      infographicLines: [
        InfographicElement(text: "WHAT WORKED", font: "HelveticaNeue-CondensedBold", size: 56,
                           x: 600, y: 700, color: operatorGreen, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 540, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Adapter extension pattern", font: "HelveticaNeue-Bold", size: 34,
                           x: 280, y: 540, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 460, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "FileAssetProvider", font: "HelveticaNeue-Bold", size: 34,
                           x: 280, y: 460, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 380, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "3-tier error taxonomy", font: "HelveticaNeue-Bold", size: 34,
                           x: 280, y: 380, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 300, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "iOS compatibility", font: "HelveticaNeue-Bold", size: 34,
                           x: 280, y: 300, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: "Patterns that earned their place", font: "HelveticaNeue-LightItalic", size: 28,
                           x: 600, y: 210, color: neutralGray, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 12, tag: "CH12", slug: "roll-it-flat", title: "Verdict: Roll It Flat",
      startSeconds: 255.018, durationSeconds: 15.232,
      heading: "RODILLO LISO",
      infographicLines: [
        InfographicElement(text: "RODILLO LISO", font: "HelveticaNeue-CondensedBold", size: 56,
                           x: 600, y: 700, color: commandWhite, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.road, font: "FontAwesome5ProSolid", size: 100,
                           x: 600, y: 480, color: intelBlue, alignment: 1, isIcon: true),
        InfographicElement(text: FAIcon.timesCircle, font: "FontAwesome5ProSolid", size: 36,
                           x: 300, y: 350, color: missionRed, alignment: 0, isIcon: true),
        InfographicElement(text: "Code (discard)", font: "HelveticaNeue-Bold", size: 36,
                           x: 380, y: 350, color: missionRed, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5ProSolid", size: 36,
                           x: 300, y: 270, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Knowledge (keep)", font: "HelveticaNeue-Bold", size: 36,
                           x: 380, y: 270, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: "\"The harvest is the product\"", font: "HelveticaNeue-LightItalic", size: 30,
                           x: 600, y: 190, color: neutralGray, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 13, tag: "CH13", slug: "clean-slate", title: "Mission One: Clean Slate",
      startSeconds: 270.250, durationSeconds: 23.381,
      heading: "ITERATION 1: CLEAN SLATE",
      infographicLines: [
        InfographicElement(text: "ITERATION 1: CLEAN SLATE", font: "HelveticaNeue-CondensedBold", size: 52,
                           x: 600, y: 700, color: operatorGreen, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.broom, font: "FontAwesome5ProSolid", size: 60,
                           x: 600, y: 560, color: operatorGreen, alignment: 1, isIcon: true),
        InfographicElement(text: "Iteration 0: 37 sorties", font: "HelveticaNeue-Bold", size: 36,
                           x: 600, y: 440, color: missionRed, alignment: 1, isIcon: false),
        InfographicElement(text: "\u{2192}", font: "HelveticaNeue-Bold", size: 48,
                           x: 600, y: 370, color: commandWhite, alignment: 1, isIcon: false),
        InfographicElement(text: "Iteration 1: 9 sorties", font: "HelveticaNeue-Bold", size: 36,
                           x: 600, y: 300, color: operatorGreen, alignment: 1, isIcon: false),
        InfographicElement(text: "All lessons baked in from day 1", font: "HelveticaNeue-LightItalic", size: 28,
                           x: 600, y: 220, color: neutralGray, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 14, tag: "CH14", slug: "sortie-zero-research", title: "Sortie Zero: Research",
      startSeconds: 293.631, durationSeconds: 27.691,
      heading: "SORTIE ZERO: RESEARCH",
      infographicLines: [
        InfographicElement(text: "SORTIE ZERO: RESEARCH", font: "HelveticaNeue-CondensedBold", size: 52,
                           x: 600, y: 700, color: intelBlue, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.search, font: "FontAwesome5ProSolid", size: 50,
                           x: 600, y: 570, color: intelBlue, alignment: 1, isIcon: true),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 20,
                           x: 200, y: 480, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "Read Pipeline Neo source", font: "HelveticaNeue-Light", size: 30,
                           x: 260, y: 475, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 20,
                           x: 200, y: 420, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "Catalog type collisions", font: "HelveticaNeue-Light", size: 30,
                           x: 260, y: 415, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 20,
                           x: 200, y: 360, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "Export sample timeline", font: "HelveticaNeue-Light", size: 30,
                           x: 260, y: 355, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 20,
                           x: 200, y: 300, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "Validate against DTD", font: "HelveticaNeue-Light", size: 30,
                           x: 260, y: 295, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.lightbulb, font: "FontAwesome5ProSolid", size: 36,
                           x: 200, y: 210, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "30 min \u{2192} 34 failures prevented", font: "HelveticaNeue-Bold", size: 32,
                           x: 280, y: 210, color: operatorGreen, alignment: 0, isIcon: false),
      ]),
    Chapter(
      number: 15, tag: "CH15", slug: "sorties-1-through-8", title: "Sorties One Through Eight",
      startSeconds: 321.322, durationSeconds: 31.147,
      heading: "SORTIES 1-8: EXECUTION PLAN",
      infographicLines: [
        InfographicElement(text: "SORTIES 1-8: EXECUTION PLAN", font: "HelveticaNeue-CondensedBold", size: 48,
                           x: 600, y: 700, color: intelBlue, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 16,
                           x: 180, y: 610, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S0: API Exploration", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 607, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 16,
                           x: 180, y: 560, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S1: Package Setup", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 557, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 16,
                           x: 180, y: 510, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S2: ResourceMap Architecture", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 507, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 16,
                           x: 180, y: 460, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S3: Timeline & Metadata Adapters", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 457, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 16,
                           x: 180, y: 410, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S4: Asset Provider Wrapper", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 407, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 16,
                           x: 180, y: 360, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S5: SwiftSecuenciaExporter", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 357, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 16,
                           x: 180, y: 310, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S6: BundleExporter", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 307, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 16,
                           x: 180, y: 260, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S7: Test Migration & Metadata", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 257, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 16,
                           x: 180, y: 210, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S8: CI & CLI Updates", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 207, color: commandWhite, alignment: 0, isIcon: false),
      ]),
    Chapter(
      number: 16, tag: "CH16", slug: "current-status", title: "Current Status",
      startSeconds: 352.469, durationSeconds: 18.048,
      heading: "CURRENT MISSION STATUS",
      infographicLines: [
        InfographicElement(text: "CURRENT MISSION STATUS", font: "HelveticaNeue-CondensedBold", size: 52,
                           x: 600, y: 700, color: cautionYellow, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5ProSolid", size: 28,
                           x: 200, y: 540, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "MISSION STATUS: PENDING", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 535, color: cautionYellow, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.lock, font: "FontAwesome5ProSolid", size: 28,
                           x: 200, y: 450, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "EXECUTION PLAN: LOCKED", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 445, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.bullseye, font: "FontAwesome5ProSolid", size: 28,
                           x: 200, y: 360, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "EXIT CRITERIA: DEFINED", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 355, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: "\"We know what done looks like\"", font: "HelveticaNeue-LightItalic", size: 30,
                           x: 600, y: 240, color: neutralGray, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 17, tag: "CH17", slug: "closing", title: "Closing",
      startSeconds: 370.517, durationSeconds: 21.803,
      heading: "SUPERVISOR OUT",
      infographicLines: [
        InfographicElement(text: "\"Verification is structural,", font: "HelveticaNeue-Bold", size: 40,
                           x: 600, y: 600, color: commandWhite, alignment: 1, isIcon: false),
        InfographicElement(text: "not optional.\"", font: "HelveticaNeue-Bold", size: 40,
                           x: 600, y: 540, color: commandWhite, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.shieldCheck, font: "FontAwesome5ProSolid", size: 60,
                           x: 600, y: 400, color: operatorGreen, alignment: 1, isIcon: true),
        InfographicElement(text: FAIcon.powerOff, font: "FontAwesome5ProSolid", size: 50,
                           x: 600, y: 260, color: missionRed, alignment: 1, isIcon: true),
        InfographicElement(text: "SUPERVISOR OUT", font: "HelveticaNeue-CondensedBold", size: 56,
                           x: 600, y: 180, color: commandWhite, alignment: 1, isIcon: false),
      ]),
  ]
}

/// Look up a chapter by its tag string (e.g. "CH01", "CH02A", etc.)
/// Also supports numeric lookup: "1" -> "CH01", "2" -> "CH02", etc.
func findChapter(identifier: String) -> Chapter? {
  let chapters = allChapters()
  // Try exact tag match first
  if let ch = chapters.first(where: { $0.tag.lowercased() == identifier.lowercased() }) {
    return ch
  }
  // Try numeric match
  if let num = Int(identifier), let ch = chapters.first(where: { $0.number == num }) {
    return ch
  }
  return nil
}

// MARK: - Parsing

func parseExecutionPlan(at path: String) throws -> ExecutionPlan {
  let content = try String(contentsOfFile: path, encoding: .utf8)
  let lines = content.components(separatedBy: "\n")

  // Parse YAML frontmatter
  guard lines.first == "---" else {
    throw NSError(
      domain: "ParseError", code: 1,
      userInfo: [NSLocalizedDescriptionKey: "Missing YAML frontmatter"])
  }

  var featureName = ""
  var branch = ""
  var iteration = ""
  var inFrontmatter = true
  var frontmatterEnd = 0

  for (i, line) in lines.enumerated() {
    if i == 0 { continue }
    if line == "---" && inFrontmatter {
      inFrontmatter = false
      frontmatterEnd = i
      break
    }
    if let match = line.range(of: "^feature_name:\\s*(.+)$", options: .regularExpression) {
      featureName = String(line[match]).replacingOccurrences(of: "feature_name:", with: "")
        .trimmingCharacters(in: .whitespaces)
    }
    if let match = line.range(of: "^mission_branch:\\s*(.+)$", options: .regularExpression) {
      branch = String(line[match]).replacingOccurrences(of: "mission_branch:", with: "")
        .trimmingCharacters(in: .whitespaces)
    }
    if let match = line.range(of: "^iteration:\\s*(.+)$", options: .regularExpression) {
      iteration = String(line[match]).replacingOccurrences(of: "iteration:", with: "")
        .trimmingCharacters(in: .whitespaces)
    }
  }

  // Split "OPERATION PIPELINE EXODUS" into prefix + name
  let parts = featureName.components(separatedBy: " ")
  let operationWord = parts.first ?? "OPERATION"
  let operationName = parts.dropFirst().joined(separator: " ")

  // Parse sortie summary table
  var sorties: [Sortie] = []
  var inTable = false

  for line in lines[frontmatterEnd...] {
    if line.contains("| Sortie | Task |") {
      inTable = true
      continue
    }
    if inTable && line.starts(with: "|---") { continue }
    if inTable && line.starts(with: "|") {
      let cols = line.components(separatedBy: "|")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
      if cols.count >= 5, let num = Int(cols[0]) {
        // Determine status from exit criteria checkboxes
        let status = determineSortieStatus(sortieNumber: num, content: content)
        sorties.append(
          Sortie(
            number: num,
            task: cols[1],
            model: cols[2],
            context: cols[3],
            deliverables: cols[4],
            status: status
          ))
      }
    } else if inTable && !line.starts(with: "|") {
      inTable = false
    }
  }

  return ExecutionPlan(
    featureName: featureName,
    operationWord: operationWord,
    operationName: operationName,
    branch: branch,
    iteration: iteration,
    sorties: sorties
  )
}

func determineSortieStatus(sortieNumber: Int, content: String) -> SortieStatus {
  // Find the sortie section and check its exit criteria checkboxes
  let pattern = "## Sortie \(sortieNumber):"
  guard let range = content.range(of: pattern) else { return .pending }

  let section = String(content[range.lowerBound...])
  // Find exit criteria within this sortie (up to next "## Sortie" or "## " heading)
  let nextSortie = section.dropFirst(10).range(of: "\n## ")
  let sectionEnd = nextSortie?.lowerBound ?? section.endIndex
  let sortieSection = String(section[section.startIndex..<sectionEnd])

  let checked = sortieSection.components(separatedBy: "- [x]").count - 1
  let unchecked = sortieSection.components(separatedBy: "- [ ]").count - 1
  let total = checked + unchecked

  if total == 0 { return .pending }
  if checked == total { return .complete }
  if checked > 0 { return .inProgress }
  return .pending
}

// MARK: - OZML Generation Helpers

func escapeXML(_ s: String) -> String {
  s.replacingOccurrences(of: "&", with: "&amp;")
    .replacingOccurrences(of: "<", with: "&lt;")
    .replacingOccurrences(of: ">", with: "&gt;")
    .replacingOccurrences(of: "\"", with: "&quot;")
}

func textNode(
  name: String, id: Int, styleID: Int, substanceID: Int, paragraphID: Int,
  text: String, font: String, size: Int, tracking: Int,
  x: Double, y: Double, alignment: Int,
  colorR: Double, colorG: Double, colorB: Double
) -> String {
  let textLength = text.count
  return """
    <scenenode name="\(escapeXML(name))" id="\(id)" factoryID="16" version="5">
    \t\t\t<paragraphMarginsCached cached="0"/>
    \t\t\t<scrollMarginsCached cached="0"/>
    \t\t\t<crawlMarginsCached cached="0"/>
    \t\t\t<host hostID="0"/>
    \t\t\t<textPathModified textPathModifiedVal="0"/>
    \t\t\t<paragraphStyle id="\(paragraphID)"/>
    \t\t\t<style name="Style" id="\(styleID)" factoryID="1">
    \t\t\t\t<copyFlags>65535</copyFlags>
    \t\t\t\t<previewWidth>0</previewWidth>
    \t\t\t\t<previewHeight>0</previewHeight>
    \t\t\t\t<presetName>Normal</presetName>
    \t\t\t\t<timing in="0 1 1 0" out="3833600 153600 1 0" offset="0 1 1 0"/>
    \t\t\t\t<baseFlags>8657043504</baseFlags>
    \t\t\t\t<foldFlags>786432</foldFlags>
    \t\t\t\t<parameter name="Font" id="83" flags="12884906000">
    \t\t\t\t\t<font>\(font)</font>
    \t\t\t\t\t<defaultFont>Helvetica</defaultFont>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Size" id="3" flags="8606711824" default="48" value="\(size)"/>
    \t\t\t\t<parameter name="Tracking" id="340" flags="8606711824" default="0" value="\(tracking)"/>
    \t\t\t\t<parameter name="Face" id="14" flags="8589938704">
    \t\t\t\t\t<foldFlags>131072</foldFlags>
    \t\t\t\t\t<parameter name="Color" id="1" flags="4295004162">
    \t\t\t\t\t\t<foldFlags>15</foldFlags>
    \t\t\t\t\t\t<parameter name="Red" id="1" flags="4295000066" default="1" value="\(colorR)"/>
    \t\t\t\t\t\t<parameter name="Green" id="2" flags="4295000066" default="1" value="\(colorG)"/>
    \t\t\t\t\t\t<parameter name="Blue" id="3" flags="4295000066" default="1" value="\(colorB)"/>
    \t\t\t\t\t\t<parameter name="Alpha" id="4" flags="4295000066" default="1" value="1"/>
    \t\t\t\t\t</parameter>
    \t\t\t\t\t<parameter name="Texture" id="18" flags="77309415440">
    \t\t\t\t\t\t<parameter name="Image" id="1" flags="77326254096" default="0" value="0"/>
    \t\t\t\t\t\t<parameter name="Wrap Mode" id="5" flags="8606777360" default="0" value="1"/>
    \t\t\t\t\t</parameter>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Drop Shadow" id="21" flags="8589971472">
    \t\t\t\t\t<foldFlags>131072</foldFlags>
    \t\t\t\t\t<parameter name="Texture" id="25" flags="77309415440">
    \t\t\t\t\t\t<parameter name="Image" id="1" flags="77326254096" default="0" value="0"/>
    \t\t\t\t\t\t<parameter name="Wrap Mode" id="5" flags="8606777360" default="0" value="1"/>
    \t\t\t\t\t</parameter>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Outline" id="30" flags="8589971472">
    \t\t\t\t\t<foldFlags>131072</foldFlags>
    \t\t\t\t\t<parameter name="Texture" id="34" flags="77309415440">
    \t\t\t\t\t\t<parameter name="Image" id="1" flags="77326254096" default="0" value="0"/>
    \t\t\t\t\t\t<parameter name="Wrap Mode" id="5" flags="8606777360" default="0" value="1"/>
    \t\t\t\t\t</parameter>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Glow" id="38" flags="8589973520">
    \t\t\t\t\t<foldFlags>131072</foldFlags>
    \t\t\t\t\t<parameter name="Texture" id="42" flags="77309415440">
    \t\t\t\t\t\t<parameter name="Image" id="1" flags="77326254096" default="0" value="0"/>
    \t\t\t\t\t\t<parameter name="Wrap Mode" id="5" flags="8606777360" default="0" value="1"/>
    \t\t\t\t\t</parameter>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="3D Text" id="89" flags="8589971472">
    \t\t\t\t\t<foldFlags>131072</foldFlags>
    \t\t\t\t\t<parameter name="Lighting" id="527" flags="8589938704">
    \t\t\t\t\t\t<foldFlags>8388608</foldFlags>
    \t\t\t\t\t\t<parameter name="Environment" id="512" flags="12884906000">
    \t\t\t\t\t\t\t<foldFlags>131076</foldFlags>
    \t\t\t\t\t\t</parameter>
    \t\t\t\t\t</parameter>
    \t\t\t\t</parameter>
    \t\t\t</style>
    \t\t\t<styleRun style="\(styleID)" offset="0" length="\(textLength)"/>
    \t\t\t<aspectRatio>0</aspectRatio>
    \t\t\t<flags>0</flags>
    \t\t\t<timing in="0 1 1 0" out="3833600 153600 1 0" offset="0 1 1 0"/>
    \t\t\t<foldFlags>0</foldFlags>
    \t\t\t<baseFlags>34078736</baseFlags>
    \t\t\t<parameter name="Properties" id="1" flags="8589938704">
    \t\t\t\t<parameter name="Transform" id="100" flags="8589938704">
    \t\t\t\t\t<parameter name="Position" id="101" flags="8589938704">
    \t\t\t\t\t\t<foldFlags>15</foldFlags>
    \t\t\t\t\t\t<parameter name="X" id="1" flags="8606711824" default="0" value="\(x)"/>
    \t\t\t\t\t\t<parameter name="Y" id="2" flags="8606711824" default="0" value="\(y)"/>
    \t\t\t\t\t</parameter>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Lighting" id="230" flags="8589938706">
    \t\t\t\t\t<foldFlags>15</foldFlags>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Shadows" id="234" flags="8589938706">
    \t\t\t\t\t<foldFlags>15</foldFlags>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Reflection" id="223" flags="8589971474">
    \t\t\t\t\t<foldFlags>131087</foldFlags>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Color" id="243" flags="8589938688">
    \t\t\t\t\t<parameter name="Hidden Channel" id="245" flags="8589934610" default="1" value="3"/>
    \t\t\t\t\t<parameter name="Conversion Type" id="247" flags="8606810128" default="3" value="3"/>
    \t\t\t\t\t<parameter name="PQ Peak (nits)" id="248" flags="8606744592" default="1000" value="1000"/>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Drop Shadow" id="208" flags="8589971474">
    \t\t\t\t\t<foldFlags>131087</foldFlags>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Four Corner" id="207" flags="8589971458">
    \t\t\t\t\t<foldFlags>131087</foldFlags>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Crop" id="216" flags="8589971474">
    \t\t\t\t\t<foldFlags>131087</foldFlags>
    \t\t\t\t</parameter>
    \t\t\t</parameter>
    \t\t\t<parameter name="Object" id="2" flags="8589938704">
    \t\t\t\t<parameter name="Text" id="369" flags="8606777344">
    \t\t\t\t\t<text>\(escapeXML(text))</text>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Alignment" id="354" flags="8589934610" default="0" value="\(alignment)"/>
    \t\t\t\t<parameter name="Render Text" id="360" flags="8590000146" default="0" value="0"/>
    \t\t\t\t<parameter name="Face Camera" id="352" flags="8589934610" default="0" value="0"/>
    \t\t\t\t<parameter name="Path Options" id="329" flags="8589938704">
    \t\t\t\t\t<parameter name="Shape Source" id="339" flags="77326254096" default="0" value="0"/>
    \t\t\t\t\t<parameter name="Align to Path" id="333" flags="8589934610" default="1" value="1"/>
    \t\t\t\t</parameter>
    \t\t\t\t<parameter name="Basic" id="2000" flags="12884938770" factoryID="0">
    \t\t\t\t\t<parameter name="Substance" id="\(substanceID)" flags="12884906002" factoryID="0">
    \t\t\t\t\t\t<parameter name="Color" id="1" flags="4295004162">
    \t\t\t\t\t\t\t<foldFlags>15</foldFlags>
    \t\t\t\t\t\t</parameter>
    \t\t\t\t\t\t<parameter name="Opacity" id="2" flags="4295000066" default="1" value="1"/>
    \t\t\t\t\t</parameter>
    \t\t\t\t</parameter>
    \t\t\t</parameter>
    \t\t</scenenode>
    """
}

// MARK: - Infographic Layout Helper Functions (Sortie 2)

/// Returns an OZML text node that renders a single Font Awesome 5 Pro icon.
/// - Parameters:
///   - icon: Unicode character string (e.g. FAIcon.checkCircle)
///   - fontSize: Icon size in points
///   - x: X position in canvas coordinates (centered at 0,0 for 4K canvas)
///   - y: Y position in canvas coordinates
///   - color: RGB color tuple with values in 0.0–1.0 range
///   - id: Base node ID (style/substance IDs derived from this)
/// - Returns: OZML scenenode XML string for a Font Awesome icon text node
func iconTextNode(
  icon: String,
  fontSize: Int,
  x: Double,
  y: Double,
  color: (r: Double, g: Double, b: Double),
  id: Int
) -> String {
  return textNode(
    name: "Icon-\(id)",
    id: id,
    styleID: id + 3,
    substanceID: id + 50,
    paragraphID: id + 10,
    text: icon,
    font: "FontAwesome5Pro-Solid",
    size: fontSize,
    tracking: 0,
    x: x,
    y: y,
    alignment: 1,
    colorR: color.r, colorG: color.g, colorB: color.b
  )
}

/// Returns OZML text nodes for a vertical stack of text lines.
/// - Parameters:
///   - lines: Array of strings to render as separate text nodes
///   - startY: Y position of the first (topmost) line in canvas coordinates
///   - fontSize: Font size in points for all lines
///   - spacing: Vertical gap between line baselines (positive = downward)
///   - alignment: Text alignment (0=left, 1=center, 2=right)
///   - font: Font name (defaults to HelveticaNeue-Light)
///   - x: X position for all lines in canvas coordinates
///   - color: RGB color tuple with values in 0.0–1.0 range
///   - baseID: Starting node ID; each line increments by 100
/// - Returns: Concatenated OZML scenenode XML strings for all lines
func stackedTextNodes(
  lines: [String],
  startY: Double,
  fontSize: Int,
  spacing: Double,
  alignment: Int,
  font: String = "HelveticaNeue-Light",
  x: Double = 0,
  color: (r: Double, g: Double, b: Double) = (1.0, 1.0, 1.0),
  baseID: Int
) -> String {
  var result = ""
  for (i, line) in lines.enumerated() {
    let nodeID = baseID + (i * 100)
    let yPos = startY - (Double(i) * spacing)  // Subtract because Motion Y increases upward
    result += textNode(
      name: escapeXML(String(line.prefix(30))),
      id: nodeID,
      styleID: nodeID + 3,
      substanceID: nodeID + 50,
      paragraphID: nodeID + 10,
      text: line,
      font: font,
      size: fontSize,
      tracking: 2,
      x: x,
      y: yPos,
      alignment: alignment,
      colorR: color.r, colorG: color.g, colorB: color.b
    )
    result += "\n"
  }
  return result
}

/// Returns an OZML shape node representing a filled progress bar rectangle.
/// The bar is split into a filled portion (percentage) and an unfilled track.
/// - Parameters:
///   - width: Total bar width in pixels
///   - percentage: Fill percentage as 0.0–1.0 (e.g. 0.65 for 65%)
///   - x: X center position in canvas coordinates
///   - y: Y center position in canvas coordinates
///   - color: RGB color for the filled portion (unfilled is a dimmed version)
///   - id: Base node ID (track and fill use id and id+1)
/// - Returns: Two OZML scenenode XML strings (track + fill) concatenated
func progressBar(
  width: Double,
  percentage: Double,
  x: Double,
  y: Double,
  color: (r: Double, g: Double, b: Double),
  id: Int
) -> String {
  let barHeight: Double = 24
  let clampedPct = max(0.0, min(1.0, percentage))

  // Use Unicode block characters to approximate a progress bar as text.
  // Full block (U+2588) for filled, light shade (U+2591) for empty.
  // This approach works within Motion's text rendering without requiring shape layers.
  let totalBlocks = 20
  let filledCount = Int(Double(totalBlocks) * clampedPct)
  let emptyCount = totalBlocks - filledCount
  let filledBlocks = String(repeating: "\u{2588}", count: filledCount)
  let emptyBlocks = String(repeating: "\u{2591}", count: emptyCount)
  let barText = filledBlocks + emptyBlocks
  let pctText = String(format: " %.0f%%", clampedPct * 100)

  var result = ""

  // Progress bar fill track (text-based block characters)
  result += textNode(
    name: "ProgressBar-\(id)",
    id: id,
    styleID: id + 3,
    substanceID: id + 50,
    paragraphID: id + 10,
    text: barText,
    font: "Courier-Bold",
    size: Int(barHeight),
    tracking: 0,
    x: x,
    y: y,
    alignment: 1,
    colorR: color.r, colorG: color.g, colorB: color.b
  )
  result += "\n"

  // Percentage label to the right of the bar
  result += textNode(
    name: "ProgressPct-\(id)",
    id: id + 1,
    styleID: id + 4,
    substanceID: id + 51,
    paragraphID: id + 11,
    text: pctText,
    font: "HelveticaNeue-Bold",
    size: Int(barHeight),
    tracking: 0,
    x: x + (width / 2) + 60,
    y: y,
    alignment: 0,
    colorR: color.r, colorG: color.g, colorB: color.b
  )
  result += "\n"

  return result
}

func layerClose(fixedWidth: Int, fixedHeight: Int) -> String {
  return """
    \t\t<aspectRatio>1</aspectRatio>
    \t\t<flags>0</flags>
    \t\t<timing in="0 1 1 0" out="3833600 153600 1 0" offset="0 1 1 0"/>
    \t\t<foldFlags>0</foldFlags>
    \t\t<baseFlags>524304</baseFlags>
    \t\t<parameter name="Properties" id="1" flags="8589938704">
    \t\t\t<parameter name="Lighting" id="230" flags="8589938706">
    \t\t\t\t<foldFlags>15</foldFlags>
    \t\t\t</parameter>
    \t\t\t<parameter name="Shadows" id="234" flags="8589938706">
    \t\t\t\t<foldFlags>15</foldFlags>
    \t\t\t</parameter>
    \t\t\t<parameter name="Reflection" id="223" flags="8589971474">
    \t\t\t\t<foldFlags>131087</foldFlags>
    \t\t\t</parameter>
    \t\t\t<parameter name="Color" id="243" flags="8589938688">
    \t\t\t\t<parameter name="Hidden Channel" id="245" flags="8589934610" default="1" value="3"/>
    \t\t\t\t<parameter name="Conversion Type" id="247" flags="8590032912" default="3" value="3"/>
    \t\t\t\t<parameter name="PQ Peak (nits)" id="248" flags="8589967376" default="1000" value="1000"/>
    \t\t\t</parameter>
    \t\t</parameter>
    \t\t<parameter name="Object" id="2" flags="8589938704">
    \t\t\t<parameter name="Fixed Width" id="302" flags="12884901908" default="\(fixedWidth)" value="\(fixedWidth)"/>
    \t\t\t<parameter name="Fixed Height" id="303" flags="12884901908" default="\(fixedHeight)" value="\(fixedHeight)"/>
    \t\t\t<parameter name="Flatten" id="311" flags="8589934610" default="0" value="0"/>
    \t\t\t<parameter name="Layer Order" id="305" flags="8589934610" default="0" value="0"/>
    \t\t\t<parameter name="Aperture Width" id="312" flags="12884901906" default="\(fixedWidth)" value="\(fixedWidth)"/>
    \t\t\t<parameter name="Aperture Height" id="313" flags="12884901906" default="\(fixedHeight)" value="\(fixedHeight)"/>
    \t\t</parameter>
    \t</layer>
    """
}

// MARK: - Infographic Layer Generation

/// Generates the OZML text nodes for a chapter's infographic layer (left panel).
/// Each InfographicElement becomes a text node; icons use Font Awesome font.
/// Progress bar elements render as block-character bars.
///
/// Coordinate system note: Motion's canvas origin is at center (0,0).
/// The infographic panel occupies x=150 to x=1400 on the 4096×2160 canvas.
/// Panel center x ≈ 775; canvas center x = 2048, so panel offset = 775 - 2048 = -1273.
/// Element x values in InfographicElement are panel-local (0–1200 range, center ~600).
/// Y values follow Motion's convention: higher element.y = higher on screen.
/// The element range (~100–800) centers around y≈450, which maps to canvas center (y=0).
/// Canvas Y: element.y - 450 maps panel-local y to canvas-centered y (preserving direction).
func generateInfographicLayer(chapter: Chapter) -> String {
  var layer = ""
  let layerID = 40000

  layer += "\t<layer name=\"Infographic: \(escapeXML(chapter.title))\" id=\"\(layerID)\">\n"

  for (i, element) in chapter.infographicLines.enumerated() {
    let nodeID = layerID + 100 + (i * 100)

    // Canvas coordinate offsets:
    // X: element.x is panel-local (0=panel left). Convert to canvas coords:
    //    panel left is at canvas x=150, canvas center is x=2048
    //    so canvas x = (150 + element.x) - 2048 = element.x - 1898
    // Y: element.y uses higher-Y-is-higher-on-screen convention (same as Motion).
    //    Element range is ~100–800, centered at ~450. Canvas center = 0.
    //    canvas y = element.y - 450
    let canvasX = element.x - 1898
    let canvasY = element.y - 450

    if element.isProgressBar {
      let pct = Double(element.text) ?? 0.0
      layer += "\t\t"
      layer += progressBar(
        width: element.barWidth,
        percentage: pct,
        x: canvasX,
        y: canvasY,
        color: (r: element.color.r, g: element.color.g, b: element.color.b),
        id: nodeID
      )
    } else {
      let fontName = element.isIcon ? "FontAwesome5Pro-Solid" : element.font
      let nodeName = element.isIcon ? "Icon-\(i)" : escapeXML(String(element.text.prefix(30)))

      layer += "\t\t"
      layer += textNode(
        name: nodeName,
        id: nodeID,
        styleID: nodeID + 3,
        substanceID: nodeID + 50,
        paragraphID: nodeID + 10,
        text: element.text,
        font: fontName,
        size: element.size,
        tracking: element.isIcon ? 0 : 2,
        x: canvasX,
        y: canvasY,
        alignment: element.alignment,
        colorR: element.color.r, colorG: element.color.g, colorB: element.color.b
      )
      layer += "\n"
    }
  }

  layer += layerClose(fixedWidth: 4096, fixedHeight: 2160)
  return layer
}

// MARK: - Chapter Template Generation

/// Generates a complete `.motn` OZML XML file for a single chapter.
/// This is the primary function for Sortie 1: one template per chapter.
func generateChapterTemplate(chapter: Chapter, plan: ExecutionPlan) -> String {
  let titleLayer = generateTitleCardLayer(plan: plan)
  let infographicLayer = generateInfographicLayer(chapter: chapter)

  return """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE ozxmlscene>
    <ozml version="5.13">

    <displayversion>5.7</displayversion>

    <factory id="1" uuid="044beba5ad3211d7ac9b000393833f6a">
    \t<description>Style</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="2" uuid="0a5c0b1d4acd11d8b650000a95a6b5a8">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="3" uuid="0e8d443513b611d89395000a95af9f7e">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="4" uuid="10405f52139811d8b4db000a95af9f7e">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="5" uuid="1595b452229211d78c7f00039389b702">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="6" uuid="1c5986a34e9646e08fa8e92b03ba1aaf">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="7" uuid="27f3ee8b229211d7925a00039389b702">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="8" uuid="46c844a813d311d8a438000a95af9f7e">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="9" uuid="558f10b4a1c011d7998900039389b702">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="10" uuid="65cb4dc9d4504fa281921f5f751fba06">
    \t<description>Widget</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="11" uuid="69f1e0a52e7911d8b19a000a95b0025a">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="12" uuid="7644521e2e7911d891a6000a95b0025a">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="13" uuid="7d468273c013498e9806a0d7bc32fddf">
    \t<description>Project</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="14" uuid="878a64bd193011d8bac3000a95af9f7e">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="15" uuid="aee0a63927494ed19a9667c9f83badfd">
    \t<description>Material</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="16" uuid="babfc7777f4711d7aaa7000393833f6a">
    \t<description>Text</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="17" uuid="fca4a88380df4dab943a0962bdb1ae75">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>

    <factory id="18" uuid="fdc1944b229111d7b1c300039389b702">
    \t<description>Channel</description>
    \t<manufacturer>Apple</manufacturer>
    \t<version>1</version>
    </factory>


    <build></build>

    <description></description>

    <canvas>
    \t<layout>1</layout>
    \t<activeView>0</activeView>
    </canvas>

    <viewer subview="0">
    \t<resolutionMode>0</resolutionMode>
    \t<dynamicResolution>1</dynamicResolution>
    \t<viewmode>0</viewmode>
    \t<overlayOptions>125708</overlayOptions>
    \t<oscOptions>30</oscOptions>
    \t<compensateAspectRatio>1</compensateAspectRatio>
    \t<renderFields>0</renderFields>
    \t<showMotionBlur>0</showMotionBlur>
    \t<showFrameBlending>1</showFrameBlending>
    \t<showLighting>1</showLighting>
    \t<showShadows>1</showShadows>
    \t<showReflection>1</showReflection>
    \t<showDepthOfField>0</showDepthOfField>
    \t<renderFullView>0</renderFullView>
    \t<renderQuality>2</renderQuality>
    \t<textRenderQuality>2</textRenderQuality>
    \t<showHighQualityResampling>0</showHighQualityResampling>
    \t<showShapeAntialiasing>1</showShapeAntialiasing>
    \t<show3DIntersectionAntialiasing>0</show3DIntersectionAntialiasing>
    \t<cameraType>0</cameraType>
    \t<cameraName>Active Camera</cameraName>
    \t<mirrorHMD>0</mirrorHMD>
    \t<panZoom camera="0" zoom="1" panX="0" panY="0" mode="2" centered="1"/>
    </viewer>

    <projectPanel>
    \t<layersPreviewColumn>1</layersPreviewColumn>
    \t<layersOpacityColumn>0</layersOpacityColumn>
    \t<layersBlendColumn>0</layersBlendColumn>
    \t<displayMasks>1</displayMasks>
    \t<displayBehaviors>1</displayBehaviors>
    \t<displayEffects>1</displayEffects>
    \t<layersVerticalZoom>1.7999999523162842</layersVerticalZoom>
    \t<mediaPreviewColumn>1</mediaPreviewColumn>
    \t<mediaTypeColumn>1</mediaTypeColumn>
    \t<mediaDurationColumn>1</mediaDurationColumn>
    \t<mediaInUseColumn>1</mediaInUseColumn>
    \t<mediaFrameSizeColumn>1</mediaFrameSizeColumn>
    \t<mediaCompressorColumn>1</mediaCompressorColumn>
    \t<mediaDepthColumn>1</mediaDepthColumn>
    \t<mediaFrameRateColumn>1</mediaFrameRateColumn>
    \t<mediaDataRateColumn>1</mediaDataRateColumn>
    \t<mediaAudioRateColumn>1</mediaAudioRateColumn>
    \t<mediaAudioFormatColumn>1</mediaAudioFormatColumn>
    \t<mediaFileSizeColumn>1</mediaFileSizeColumn>
    \t<mediaFileCreatedColumn>1</mediaFileCreatedColumn>
    \t<mediaDileModifiedColumn>1</mediaDileModifiedColumn>
    \t<mediaVerticalZoom>1.7999999523162842</mediaVerticalZoom>
    </projectPanel>

    <timeline>
    \t<displayVideo>1</displayVideo>
    \t<displayAudio>0</displayAudio>
    \t<displayKeyframes>1</displayKeyframes>
    \t<displayMasks>1</displayMasks>
    \t<displayBehaviors>1</displayBehaviors>
    \t<displayEffects>1</displayEffects>
    \t<videoVerticalZoom>1.5555555555555556</videoVerticalZoom>
    \t<audioVerticalZoom>1.5555555820465088</audioVerticalZoom>
    \t<displayRange in="-1103385203 1729492187 3 0" out="25637982184 1000000000 3 0"/>
    </timeline>

    <curveeditor>
    \t<autozoom>0</autozoom>
    \t<snapping>0</snapping>
    \t<displayAudioWaveform>0</displayAudioWaveform>
    \t<lockKeyframesInTime>0</lockKeyframesInTime>
    \t<displayRange in="-1103385203 1729492187 3 0" out="25637982184 1000000000 3 0"/>
    \t<currentviewvolume originx="-0.63798218418895924" originy="-62.5" width="26.275964368" height="125"/>
    \t<snapshotChannels>0</snapshotChannels>
    </curveeditor>

    <inspector>
    \t<collapseState id="./1/100" state="1"/>
    \t<collapseState id="./1/200" state="1"/>
    \t<collapseState id="./1/344" state="1"/>
    </inspector>

    <scene>
    \t<sceneSettings>
    \t\t<width>4096</width>
    \t\t<height>2160</height>
    \t\t<duration>600</duration>
    \t\t<shouldOverrideFCDuration>0</shouldOverrideFCDuration>
    \t\t<frameRate>24</frameRate>
    \t\t<NTSC>0</NTSC>
    \t\t<pixelAspectRatio>1</pixelAspectRatio>
    \t\t<workingGamut>0</workingGamut>
    \t\t<viewGamut>-1</viewGamut>
    \t\t<optimizeForDisplay>0</optimizeForDisplay>
    \t\t<backgroundColor red="0" green="0" blue="0" alpha="1"/>
    \t\t<audioChannels>2</audioChannels>
    \t\t<audioBitsPerSample>32</audioBitsPerSample>
    \t\t<fieldRenderingMode>0</fieldRenderingMode>
    \t\t<motionBlurSamples>8</motionBlurSamples>
    \t\t<motionBlurDuration>1</motionBlurDuration>
    \t\t<sharpScaling>0</sharpScaling>
    \t\t<startTimecode>0</startTimecode>
    \t\t<presetPath>/Applications/Motion.app/Contents/Resources/en.lproj/Presets/Project/4K - Digital Cinema.preset</presetPath>
    \t\t<backgroundMode>0</backgroundMode>
    \t\t<reflectionRecursionLimit>2</reflectionRecursionLimit>
    \t\t<glyphOSCMode>0</glyphOSCMode>
    \t\t<animateFlag>0</animateFlag>
    \t\t<parameterColorSpaceID>3</parameterColorSpaceID>
    \t\t<savePreviewMovie>0</savePreviewMovie>
    \t\t<Object3DEnvironments>100</Object3DEnvironments>
    \t\t<DRTSupport>0</DRTSupport>
    \t\t<onHDRDisplay>0</onHDRDisplay>
    \t</sceneSettings>
    \t<publishSettings>
    \t\t<version>2</version>
    \t</publishSettings>
    \t<currentFrame>0 1 1 0</currentFrame>
    \t<currentObject>20001</currentObject>
    \t<activeLayer>20000</activeLayer>
    \t<timeRange offset="0 1 1 0" duration="3840000 153600 1 0"/>
    \t<playRange offset="0 1 1 0" duration="3840000 153600 1 0"/>
    \t<flags>1</flags>
    \t<audioTracks>0</audioTracks>
    \t<timemarkerset/>
    \t<guideset/>
    \t<curvesets selected="1"/>
    \t<scenenode name="Project" id="10000" factoryID="13" version="5">
    \t\t<scenenode name="Widget" id="10002" factoryID="10" version="5">
    \t\t\t<flags>0</flags>
    \t\t\t<timing in="0 1 1 0" out="-6400 153600 1 0" offset="0 1 1 0"/>
    \t\t\t<foldFlags>0</foldFlags>
    \t\t\t<baseFlags>16</baseFlags>
    \t\t\t<parameter name="Properties" id="1" flags="8589938704"/>
    \t\t\t<parameter name="Object" id="2" flags="8589938704">
    \t\t\t\t<parameter name="Options" id="103" flags="8589938688"/>
    \t\t\t\t<parameter name="Hidden" id="102" flags="8589934608" default="0" value="1"/>
    \t\t\t\t<parameter name="Snapshots" id="101" flags="8589938706"/>
    \t\t\t\t<parameter name="Widget" id="100" flags="8589934608" default="1.7777777777777777" value="1.7777777777777777"/>
    \t\t\t</parameter>
    \t\t</scenenode>
    \t\t<flags>0</flags>
    \t\t<timing in="0 1 1 0" out="-6400 153600 1 0" offset="0 1 1 0"/>
    \t\t<foldFlags>0</foldFlags>
    \t\t<baseFlags>16</baseFlags>
    \t\t<parameter name="Properties" id="1" flags="8589938704"/>
    \t\t<parameter name="Object" id="2" flags="8589938704"/>
    \t</scenenode>
    \(titleLayer)
    \(infographicLayer)
    \t<footage name="Media Layer" id="10006">
    \t\t<flags>0</flags>
    \t\t<timing in="0 1 1 0" out="0 153600 1 0" offset="0 1 1 0"/>
    \t\t<foldFlags>0</foldFlags>
    \t\t<baseFlags>524304</baseFlags>
    \t\t<parameter name="Properties" id="1" flags="8589938704"/>
    \t\t<parameter name="Object" id="2" flags="8589938704"/>
    \t</footage>
    </scene>

    </ozml>
    """
}

/// Generates just the title card layer (center panel) for a chapter template.
/// Shows the chapter tag and heading instead of the full operation name.
func generateTitleCardLayer(plan: ExecutionPlan) -> String {
  var layer = ""
  layer += """
    \t<layer name="Title Card" id="20000">
    \t\t\(textNode(
            name: plan.operationWord,
            id: 20001,
            styleID: 20003,
            substanceID: 20050,
            paragraphID: 20010,
            text: plan.operationWord,
            font: "HelveticaNeue-Light",
            size: 72,
            tracking: 20,
            x: 0, y: 120,
            alignment: 1,
            colorR: 0.7, colorG: 0.7, colorB: 0.7
        ))
    \t\t\(textNode(
            name: plan.operationName,
            id: 20100,
            styleID: 20103,
            substanceID: 20150,
            paragraphID: 20110,
            text: plan.operationName,
            font: "HelveticaNeue-CondensedBold",
            size: 200,
            tracking: 5,
            x: 0, y: -30,
            alignment: 1,
            colorR: 1.0, colorG: 1.0, colorB: 1.0
        ))
    \t\t\(textNode(
            name: "Iteration",
            id: 20200,
            styleID: 20203,
            substanceID: 20250,
            paragraphID: 20210,
            text: "ITERATION \(plan.iteration) | \(plan.branch)",
            font: "HelveticaNeue-Light",
            size: 42,
            tracking: 8,
            x: 0, y: -180,
            alignment: 1,
            colorR: 0.5, colorG: 0.5, colorB: 0.5
        ))
    \(layerClose(fixedWidth: 4096, fixedHeight: 2160))
    """
  return layer
}

// MARK: - Thumbnail Generation (Chapter-Specific)

func generateChapterThumbnail(
  width: Int, height: Int, path: String,
  chapter: Chapter, plan: ExecutionPlan
) {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
  )!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

  // Background - dark with slight green tint (matching infographic panel)
  NSColor(calibratedRed: 0.02, green: 0.06, blue: 0.02, alpha: 1).setFill()
  NSRect(x: 0, y: 0, width: width, height: height).fill()

  let isLarge = width > 200
  let scale: CGFloat = isLarge ? 1.0 : 0.35

  let tagFont =
    NSFont(name: "HelveticaNeue-CondensedBold", size: 16 * scale)
    ?? NSFont.boldSystemFont(ofSize: 16 * scale)
  let headingFont =
    NSFont(name: "HelveticaNeue-CondensedBold", size: 12 * scale)
    ?? NSFont.boldSystemFont(ofSize: 12 * scale)
  let subtitleFont =
    NSFont(name: "HelveticaNeue-Light", size: 9 * scale)
    ?? NSFont.systemFont(ofSize: 9 * scale)

  let tagColor = NSColor(calibratedRed: 0.314, green: 0.706, blue: 0.902, alpha: 1)  // Intel Blue
  let headColor = NSColor.white
  let subColor = NSColor(calibratedRed: 0.706, green: 0.706, blue: 0.706, alpha: 1)

  func drawCentered(_ text: String, font: NSFont, color: NSColor, y: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let str = NSAttributedString(string: text, attributes: attrs)
    let size = str.size()
    str.draw(at: NSPoint(x: (CGFloat(width) - size.width) / 2, y: y))
  }

  let centerY = CGFloat(height) / 2

  // Chapter tag (e.g. "CH03")
  drawCentered(chapter.tag, font: tagFont, color: tagColor, y: centerY + 20 * scale)

  // Chapter heading
  drawCentered(chapter.heading, font: headingFont, color: headColor, y: centerY - 8 * scale)

  // Chapter title subtitle
  drawCentered(chapter.title, font: subtitleFont, color: subColor, y: centerY - 28 * scale)

  // Duration indicator at bottom
  if isLarge {
    let durText = String(format: "%.1fs", chapter.durationSeconds)
    drawCentered(durText, font: subtitleFont, color: subColor, y: 10)
  }

  NSGraphicsContext.restoreGraphicsState()
  let data = rep.representation(using: .png, properties: [:])!
  try! data.write(to: URL(fileURLWithPath: path))
}

// MARK: - Main

func printUsage() {
  let name = (CommandLine.arguments.first ?? "generate-motion-titles") as NSString
  print(
    """
    Usage: \(name.lastPathComponent) <execution-plan-path> <podcast-path> <episode-number> <chapter>

    Arguments:
      execution-plan-path  Path to EXECUTION_PLAN.md
      podcast-path         Path to podcast project directory
      episode-number       Episode number (e.g., 1)
      chapter              Chapter identifier (e.g., 1, CH01, CH02A, 17)

    Output:
      Generates a single Motion title template (.motn) in:
        ~/Movies/Motion Templates.localized/Titles.localized/casting-software-spells/EP01-infographics/

    Available chapters:
      CH01  Opening
      CH02  Mission Briefing
      CH03  Mission Zero: The Mess
      CH04  Discovery: Resource IDs
      CH05  Discovery: Library Bug
      CH06  Discovery: Empty Timelines
      CH07  Discovery: Metadata Correction
      CH08  Discovery: Time Format
      CH09  Discovery: Type Collisions
      CH10  Process Failures
      CH11  What Worked
      CH12  Verdict: Roll It Flat
      CH13  Mission One: Clean Slate
      CH14  Sortie Zero: Research
      CH15  Sorties One Through Eight
      CH16  Current Status
      CH17  Closing

    Example:
      swift \(name.lastPathComponent) \\
        ~/Movies/EXECUTION_PLAN.md \\
        ~/Projects/podcast-casting-software-spells \\
        1 \\
        CH03
    """)
}

guard CommandLine.arguments.count == 5 else {
  printUsage()
  exit(1)
}

let executionPlanPath = NSString(string: CommandLine.arguments[1]).expandingTildeInPath
let podcastPath = NSString(string: CommandLine.arguments[2]).expandingTildeInPath
let episodeNumber = Int(CommandLine.arguments[3]) ?? 1
let chapterIdentifier = CommandLine.arguments[4]

print("Parsing execution plan: \(executionPlanPath)")

do {
  let plan = try parseExecutionPlan(at: executionPlanPath)

  print("Operation: \(plan.featureName)")
  print("Branch: \(plan.branch)")
  print("Iteration: \(plan.iteration)")

  // Find the requested chapter
  guard let chapter = findChapter(identifier: chapterIdentifier) else {
    print("Error: Unknown chapter identifier '\(chapterIdentifier)'")
    print("Use --help or run without arguments to see available chapters.")
    exit(1)
  }

  print("Chapter: \(chapter.tag) - \(chapter.title)")
  print("  Start: \(chapter.startSeconds)s")
  print("  Duration: \(chapter.durationSeconds)s")
  print("  Infographic elements: \(chapter.infographicLines.count)")

  // Output directory: EP01-infographics
  let epTag = String(format: "EP%02d", episodeNumber)
  let folderName = "\(epTag)-infographics"
  let titleDir = "\(titlesBase)/\(folderName)"
  let fm = FileManager.default

  // Create output directory (do not remove existing -- other chapters may already be there)
  try fm.createDirectory(atPath: titleDir, withIntermediateDirectories: true)

  // Generate .motn file for this chapter
  let motnContent = generateChapterTemplate(chapter: chapter, plan: plan)
  let motnFilename = "\(chapter.tag)-\(chapter.slug).motn"
  let motnPath = "\(titleDir)/\(motnFilename)"
  try motnContent.write(toFile: motnPath, atomically: true, encoding: .utf8)
  print("Wrote: \(motnPath)")

  // Generate chapter-specific thumbnails
  let largePath = "\(titleDir)/\(chapter.tag)-large.png"
  let smallPath = "\(titleDir)/\(chapter.tag)-small.png"
  generateChapterThumbnail(
    width: 320, height: 180, path: largePath, chapter: chapter, plan: plan)
  generateChapterThumbnail(
    width: 96, height: 96, path: smallPath, chapter: chapter, plan: plan)
  print("Wrote: \(largePath)")
  print("Wrote: \(smallPath)")

  print("\nChapter template generated at:")
  print("  \(titleDir)/\(motnFilename)")
  print("\nReady for FCPX: Titles > casting-software-spells > \(folderName)")

} catch {
  print("Error: \(error.localizedDescription)")
  exit(1)
}
