#!/usr/bin/env swift

import AppKit
import Foundation

// MARK: - Configuration

let motionTemplatesBase = NSHomeDirectory() + "/Movies/Motion Templates.localized"
let titlesBase = motionTemplatesBase + "/Titles.localized/casting-software-spells"
let generatorsBase = motionTemplatesBase + "/Generators.localized/casting-software-spells"

// MARK: - Layout Constants
//
// Canvas: 3840×2160 (UHD). Origin at center = (0, 0).
// Background from background.motn defines the visual layout:
//
// Right dark panel (infographic target):
//   Motion coords: center X=1320, Y=90, size 1120×1900
//   Top edge Y=1040, Bottom edge Y=-860, Left edge X=760, Right edge X=1880
//
// Element coordinates in chapter definitions use a local design space:
//   x: 100–1100 range (maps to panel width, 600 = panel center)
//   y: 0–800 range (0 = bottom of panel, 800 = top of panel)
//
// Conversion to Motion canvas coords:
//   canvasX = panelLeft + padding + (element.x - 100) / 1000 * usableWidth
//   canvasY = panelBottom + (element.y / 800) * panelHeight

let canvasWidth: Double = 3840         // Canvas width (UHD)
let canvasHeight: Double = 2160        // Canvas height (UHD)
let halfWidth: Double = 1920           // Half canvas width (origin offset)
let halfHeight: Double = 1080          // Half canvas height (origin offset)

// Right dark panel dimensions (from background.motn)
let panelCenterX: Double = 1320        // Panel center X in Motion coords
let panelCenterY: Double = 90          // Panel center Y in Motion coords
let panelWidth: Double = 1120          // Panel width in pixels
let panelHeight: Double = 1900         // Panel height in pixels
let panelLeft: Double = 760            // Panel left edge (1320 - 560)
let panelRight: Double = 1880          // Panel right edge (1320 + 560)
let panelTop: Double = 1040            // Panel top edge (90 + 950)
let panelBottom: Double = -860         // Panel bottom edge (90 - 950)

// Teal accent bar position (from background.motn)
let tealBarX: Double = -308            // Teal bar center X
let tealBarY: Double = 640             // Teal bar center Y

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
/// Each chapter corresponds to one audio clip and one .moti template.
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
        InfographicElement(text: FAIcon.userShield, font: "FontAwesome5Pro-Solid", size: 120,
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
        InfographicElement(text: FAIcon.exchangeAlt, font: "FontAwesome5Pro-Solid", size: 80,
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
        InfographicElement(text: FAIcon.fileAlt, font: "FontAwesome5Pro-Solid", size: 60,
                           x: 600, y: 560, color: intelBlue, alignment: 1, isIcon: true),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 32,
                           x: 200, y: 450, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Port SwiftSecuencia to Pipeline Neo", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 445, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 32,
                           x: 200, y: 385, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Preserve all existing tests", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 380, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 32,
                           x: 200, y: 320, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Maintain iOS compatibility", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 315, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 32,
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
        InfographicElement(text: FAIcon.sitemap, font: "FontAwesome5Pro-Solid", size: 60,
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
        InfographicElement(text: FAIcon.syncAlt, font: "FontAwesome5Pro-Solid", size: 80,
                           x: 600, y: 550, color: missionRed, alignment: 1, isIcon: true),
        InfographicElement(text: FAIcon.fighterJet, font: "FontAwesome5Pro-Solid", size: 36,
                           x: 200, y: 420, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "Agent 1: Architecture", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 415, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.fighterJet, font: "FontAwesome5Pro-Solid", size: 36,
                           x: 200, y: 360, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "Agent 2: Adapters", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 355, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.fighterJet, font: "FontAwesome5Pro-Solid", size: 36,
                           x: 200, y: 300, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "Agent 3: Tests", font: "HelveticaNeue-Light", size: 30,
                           x: 280, y: 295, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.fighterJet, font: "FontAwesome5Pro-Solid", size: 36,
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
        InfographicElement(text: FAIcon.exclamationTriangle, font: "FontAwesome5Pro-Solid", size: 44,
                           x: 200, y: 480, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "30+ COMMITS", font: "HelveticaNeue-Bold", size: 38,
                           x: 280, y: 480, color: missionRed, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.fighterJet, font: "FontAwesome5Pro-Solid", size: 44,
                           x: 200, y: 390, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "24/37 SORTIES EXECUTED", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 390, color: cautionYellow, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.codeBranch, font: "FontAwesome5Pro-Solid", size: 44,
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
        InfographicElement(text: FAIcon.timesCircle, font: "FontAwesome5Pro-Solid", size: 44,
                           x: 200, y: 520, color: missionRed, alignment: 0, isIcon: true),
        InfographicElement(text: "UUID: \"abc-123-def-456\"", font: "Courier-Bold", size: 32,
                           x: 280, y: 520, color: missionRed, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 44,
                           x: 200, y: 430, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "DTD Spec: \"r1\", \"r2\", \"r3\"", font: "Courier-Bold", size: 32,
                           x: 280, y: 430, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.book, font: "FontAwesome5Pro-Solid", size: 44,
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
        InfographicElement(text: FAIcon.bug, font: "FontAwesome5Pro-Solid", size: 60,
                           x: 600, y: 560, color: missionRed, alignment: 1, isIcon: true),
        InfographicElement(text: "<library name=\"invalid\">", font: "Courier", size: 28,
                           x: 600, y: 460, color: missionRed, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.timesCircle, font: "FontAwesome5Pro-Solid", size: 36,
                           x: 200, y: 350, color: missionRed, alignment: 0, isIcon: true),
        InfographicElement(text: "Regex on XML", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 350, color: missionRed, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 36,
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
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 32,
                           x: 300, y: 450, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Yes \u{2192} Hand-craft FCPXML", font: "Courier", size: 26,
                           x: 370, y: 450, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.timesCircle, font: "FontAwesome5Pro-Solid", size: 32,
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
        InfographicElement(text: FAIcon.timesCircle, font: "FontAwesome5Pro-Solid", size: 36,
                           x: 200, y: 560, color: missionRed, alignment: 0, isIcon: true),
        InfographicElement(text: "ASSUMED: \"No metadata export\"", font: "HelveticaNeue-Bold", size: 32,
                           x: 280, y: 560, color: missionRed, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 36,
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
        InfographicElement(text: FAIcon.clock, font: "FontAwesome5Pro-Solid", size: 60,
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
        InfographicElement(text: FAIcon.exclamationTriangle, font: "FontAwesome5Pro-Solid", size: 50,
                           x: 600, y: 580, color: cautionYellow, alignment: 1, isIcon: true),
        InfographicElement(text: "Timeline", font: "Courier-Bold", size: 32,
                           x: 200, y: 480, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: "Marker", font: "Courier-Bold", size: 32,
                           x: 200, y: 420, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: "ChapterMarker", font: "Courier-Bold", size: 32,
                           x: 200, y: 360, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: "Keyword", font: "Courier-Bold", size: 32,
                           x: 200, y: 300, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.memory, font: "FontAwesome5Pro-Solid", size: 36,
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
        InfographicElement(text: FAIcon.chartBar, font: "FontAwesome5Pro-Solid", size: 50,
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
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 36,
                           x: 200, y: 540, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Adapter extension pattern", font: "HelveticaNeue-Bold", size: 34,
                           x: 280, y: 540, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 36,
                           x: 200, y: 460, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "FileAssetProvider", font: "HelveticaNeue-Bold", size: 34,
                           x: 280, y: 460, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 36,
                           x: 200, y: 380, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "3-tier error taxonomy", font: "HelveticaNeue-Bold", size: 34,
                           x: 280, y: 380, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 36,
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
        InfographicElement(text: FAIcon.road, font: "FontAwesome5Pro-Solid", size: 100,
                           x: 600, y: 480, color: intelBlue, alignment: 1, isIcon: true),
        InfographicElement(text: FAIcon.timesCircle, font: "FontAwesome5Pro-Solid", size: 36,
                           x: 300, y: 350, color: missionRed, alignment: 0, isIcon: true),
        InfographicElement(text: "Code (discard)", font: "HelveticaNeue-Bold", size: 36,
                           x: 380, y: 350, color: missionRed, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 36,
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
        InfographicElement(text: FAIcon.broom, font: "FontAwesome5Pro-Solid", size: 60,
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
        InfographicElement(text: FAIcon.search, font: "FontAwesome5Pro-Solid", size: 50,
                           x: 600, y: 570, color: intelBlue, alignment: 1, isIcon: true),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 20,
                           x: 200, y: 480, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "Read Pipeline Neo source", font: "HelveticaNeue-Light", size: 30,
                           x: 260, y: 475, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 20,
                           x: 200, y: 420, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "Catalog type collisions", font: "HelveticaNeue-Light", size: 30,
                           x: 260, y: 415, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 20,
                           x: 200, y: 360, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "Export sample timeline", font: "HelveticaNeue-Light", size: 30,
                           x: 260, y: 355, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 20,
                           x: 200, y: 300, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "Validate against DTD", font: "HelveticaNeue-Light", size: 30,
                           x: 260, y: 295, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.lightbulb, font: "FontAwesome5Pro-Solid", size: 36,
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
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 16,
                           x: 180, y: 610, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S0: API Exploration", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 607, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 16,
                           x: 180, y: 560, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S1: Package Setup", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 557, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 16,
                           x: 180, y: 510, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S2: ResourceMap Architecture", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 507, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 16,
                           x: 180, y: 460, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S3: Timeline & Metadata Adapters", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 457, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 16,
                           x: 180, y: 410, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S4: Asset Provider Wrapper", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 407, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 16,
                           x: 180, y: 360, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S5: SwiftSecuenciaExporter", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 357, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 16,
                           x: 180, y: 310, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S6: BundleExporter", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 307, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 16,
                           x: 180, y: 260, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "S7: Test Migration & Metadata", font: "HelveticaNeue-Light", size: 26,
                           x: 230, y: 257, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 16,
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
        InfographicElement(text: FAIcon.circle, font: "FontAwesome5Pro-Solid", size: 28,
                           x: 200, y: 540, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "MISSION STATUS: PENDING", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 535, color: cautionYellow, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.lock, font: "FontAwesome5Pro-Solid", size: 28,
                           x: 200, y: 450, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "EXECUTION PLAN: LOCKED", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 445, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.bullseye, font: "FontAwesome5Pro-Solid", size: 28,
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
        InfographicElement(text: FAIcon.shieldCheck, font: "FontAwesome5Pro-Solid", size: 60,
                           x: 600, y: 400, color: operatorGreen, alignment: 1, isIcon: true),
        InfographicElement(text: FAIcon.powerOff, font: "FontAwesome5Pro-Solid", size: 50,
                           x: 600, y: 260, color: missionRed, alignment: 1, isIcon: true),
        InfographicElement(text: "SUPERVISOR OUT", font: "HelveticaNeue-CondensedBold", size: 56,
                           x: 600, y: 180, color: commandWhite, alignment: 1, isIcon: false),
      ]),
  ]
}

// MARK: - EP02 Chapter Definitions (OPERATION MARKUP JAILBREAK)

func allChaptersEP02() -> [Chapter] {
  return [
    Chapter(
      number: 1, tag: "CH01", slug: "opening", title: "Opening",
      startSeconds: 0.000, durationSeconds: 37.600,
      heading: "THE GENERAL",
      infographicLines: [
        InfographicElement(text: FAIcon.userShield, font: "FontAwesome5Pro-Solid", size: 120,
                           x: 600, y: 500, color: commandWhite, alignment: 1, isIcon: true),
        InfographicElement(text: "THE GENERAL", font: "HelveticaNeue-CondensedBold", size: 72,
                           x: 600, y: 350, color: commandWhite, alignment: 1, isIcon: false),
        InfographicElement(text: "FIELD DEBRIEF COMMENCING", font: "HelveticaNeue-Light", size: 36,
                           x: 600, y: 270, color: neutralGray, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 2, tag: "CH02", slug: "mission-briefing", title: "Mission Briefing",
      startSeconds: 37.600, durationSeconds: 70.880,
      heading: "OBJECTIVE: iOS XML ABSTRACTION",
      infographicLines: [
        InfographicElement(text: "OBJECTIVE: iOS XML ABSTRACTION", font: "HelveticaNeue-CondensedBold", size: 44,
                           x: 600, y: 700, color: commandWhite, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.lock, font: "FontAwesome5Pro-Solid", size: 50,
                           x: 350, y: 560, color: missionRed, alignment: 1, isIcon: true),
        InfographicElement(text: FAIcon.exchangeAlt, font: "FontAwesome5Pro-Solid", size: 50,
                           x: 600, y: 560, color: cautionYellow, alignment: 1, isIcon: true),
        InfographicElement(text: FAIcon.shieldCheck, font: "FontAwesome5Pro-Solid", size: 50,
                           x: 850, y: 560, color: operatorGreen, alignment: 1, isIcon: true),
        InfographicElement(text: "macOS Only", font: "HelveticaNeue-Light", size: 28,
                           x: 350, y: 490, color: missionRed, alignment: 1, isIcon: false),
        InfographicElement(text: "\u{2192}", font: "HelveticaNeue-Bold", size: 40,
                           x: 600, y: 490, color: cautionYellow, alignment: 1, isIcon: false),
        InfographicElement(text: "Cross-Platform", font: "HelveticaNeue-Light", size: 28,
                           x: 850, y: 490, color: operatorGreen, alignment: 1, isIcon: false),
        InfographicElement(text: "7 WORK UNITS", font: "HelveticaNeue-Bold", size: 36,
                           x: 350, y: 380, color: intelBlue, alignment: 1, isIcon: false),
        InfographicElement(text: "25 SORTIES", font: "HelveticaNeue-Bold", size: 36,
                           x: 850, y: 380, color: intelBlue, alignment: 1, isIcon: false),
        InfographicElement(text: "655 EXISTING TESTS", font: "HelveticaNeue-Bold", size: 32,
                           x: 600, y: 300, color: cautionYellow, alignment: 1, isIcon: false),
        InfographicElement(text: "\"Agents don't take a dump without a plan\"", font: "HelveticaNeue-LightItalic", size: 26,
                           x: 600, y: 220, color: neutralGray, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 3, tag: "CH03", slug: "the-architecture", title: "The Architecture",
      startSeconds: 108.480, durationSeconds: 95.600,
      heading: "PROTOCOL CONTRACTS + DUAL BACKENDS",
      infographicLines: [
        InfographicElement(text: "PROTOCOL CONTRACTS", font: "HelveticaNeue-CondensedBold", size: 48,
                           x: 600, y: 700, color: intelBlue, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.sitemap, font: "FontAwesome5Pro-Solid", size: 50,
                           x: 600, y: 580, color: intelBlue, alignment: 1, isIcon: true),
        InfographicElement(text: "PNXMLNode", font: "Courier-Bold", size: 30,
                           x: 200, y: 500, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: "PNXMLElement", font: "Courier-Bold", size: 30,
                           x: 200, y: 440, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: "PNXMLDocument", font: "Courier-Bold", size: 30,
                           x: 200, y: 380, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: "PNXMLFactory", font: "Courier-Bold", size: 30,
                           x: 200, y: 320, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.codeBranch, font: "FontAwesome5Pro-Solid", size: 36,
                           x: 200, y: 230, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "Foundation (macOS)", font: "HelveticaNeue-Bold", size: 30,
                           x: 280, y: 230, color: intelBlue, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.codeBranch, font: "FontAwesome5Pro-Solid", size: 36,
                           x: 200, y: 170, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "AEXML (iOS / cross-platform)", font: "HelveticaNeue-Bold", size: 30,
                           x: 280, y: 170, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: "\"This is the way.\"", font: "HelveticaNeue-LightItalic", size: 28,
                           x: 600, y: 80, color: neutralGray, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 4, tag: "CH04", slug: "the-migration", title: "The Migration",
      startSeconds: 204.080, durationSeconds: 82.240,
      heading: "THE BIG PUSH: 13 SORTIES",
      infographicLines: [
        InfographicElement(text: "THE BIG PUSH", font: "HelveticaNeue-CondensedBold", size: 56,
                           x: 600, y: 700, color: missionRed, alignment: 1, isIcon: false),
        // Progress bar: 25/25 sorties = 100% (Operator Green = complete)
        InfographicElement(percentage: 1.0, barWidth: 700, x: 550, y: 610, color: operatorGreen),
        InfographicElement(text: "25 / 25 SORTIES", font: "HelveticaNeue-Bold", size: 32,
                           x: 550, y: 570, color: operatorGreen, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.fileCode, font: "FontAwesome5Pro-Solid", size: 40,
                           x: 200, y: 480, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "145 SOURCE FILES", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 480, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.exchangeAlt, font: "FontAwesome5Pro-Solid", size: 40,
                           x: 200, y: 400, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "1,600+ CALL SITES", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 400, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.fighterJet, font: "FontAwesome5Pro-Solid", size: 40,
                           x: 200, y: 320, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "13 SORTIES, 0 RETRIES", font: "HelveticaNeue-Bold", size: 36,
                           x: 280, y: 320, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: "Directory by directory, like dominoes", font: "HelveticaNeue-LightItalic", size: 26,
                           x: 600, y: 220, color: neutralGray, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 5, tag: "CH05", slug: "the-bug", title: "The Bug",
      startSeconds: 286.320, durationSeconds: 106.160,
      heading: "THE INDEX MISMATCH BUG",
      infographicLines: [
        InfographicElement(text: "THE INDEX MISMATCH", font: "HelveticaNeue-CondensedBold", size: 52,
                           x: 600, y: 700, color: missionRed, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.bug, font: "FontAwesome5Pro-Solid", size: 80,
                           x: 600, y: 560, color: missionRed, alignment: 1, isIcon: true),
        InfographicElement(text: "removeChildren(where:)", font: "Courier-Bold", size: 28,
                           x: 600, y: 450, color: cautionYellow, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.timesCircle, font: "FontAwesome5Pro-Solid", size: 32,
                           x: 200, y: 370, color: missionRed, alignment: 0, isIcon: true),
        InfographicElement(text: "childElements[0] != children[0]", font: "Courier", size: 26,
                           x: 280, y: 370, color: missionRed, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 32,
                           x: 200, y: 300, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Iterate full children array", font: "HelveticaNeue-Bold", size: 30,
                           x: 280, y: 300, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: "662 TESTS: 4 \u{2192} 0 FAILURES", font: "HelveticaNeue-Bold", size: 36,
                           x: 600, y: 210, color: operatorGreen, alignment: 1, isIcon: false),
        InfographicElement(text: "\"This is why we verify.\"", font: "HelveticaNeue-LightItalic", size: 28,
                           x: 600, y: 130, color: neutralGray, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 6, tag: "CH06", slug: "validation-and-platform", title: "Validation and Platform",
      startSeconds: 392.480, durationSeconds: 96.720,
      heading: "iOS PLATFORM EXPANSION",
      infographicLines: [
        InfographicElement(text: "iOS PLATFORM EXPANSION", font: "HelveticaNeue-CondensedBold", size: 48,
                           x: 600, y: 700, color: operatorGreen, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.shieldAlt, font: "FontAwesome5Pro-Solid", size: 40,
                           x: 200, y: 580, color: intelBlue, alignment: 0, isIcon: true),
        InfographicElement(text: "Structural Validator", font: "HelveticaNeue-Bold", size: 32,
                           x: 280, y: 580, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: "100+ element allowlist", font: "HelveticaNeue-Light", size: 26,
                           x: 300, y: 530, color: neutralGray, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.codeBranch, font: "FontAwesome5Pro-Solid", size: 40,
                           x: 200, y: 440, color: cautionYellow, alignment: 0, isIcon: true),
        InfographicElement(text: "PNXMLDefaultFactory()", font: "Courier-Bold", size: 28,
                           x: 280, y: 440, color: cautionYellow, alignment: 0, isIcon: false),
        InfographicElement(text: "64 call sites replaced", font: "HelveticaNeue-Light", size: 26,
                           x: 300, y: 390, color: neutralGray, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 40,
                           x: 200, y: 300, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: ".iOS(.v15)", font: "Courier-Bold", size: 32,
                           x: 280, y: 300, color: operatorGreen, alignment: 0, isIcon: false),
        InfographicElement(text: "686 TESTS | 0 FAILURES", font: "HelveticaNeue-Bold", size: 36,
                           x: 600, y: 200, color: operatorGreen, alignment: 1, isIcon: false),
        InfographicElement(text: "MISSION COMPLETE", font: "HelveticaNeue-CondensedBold", size: 44,
                           x: 600, y: 120, color: operatorGreen, alignment: 1, isIcon: false),
      ]),
    Chapter(
      number: 7, tag: "CH07", slug: "closing", title: "Closing",
      startSeconds: 489.200, durationSeconds: 82.880,
      heading: "GENERAL OUT",
      infographicLines: [
        InfographicElement(text: "25 SORTIES | 0 RETRIES", font: "HelveticaNeue-CondensedBold", size: 44,
                           x: 600, y: 700, color: operatorGreen, alignment: 1, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 32,
                           x: 200, y: 580, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Machine-verifiable exit criteria", font: "HelveticaNeue-Bold", size: 30,
                           x: 280, y: 580, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 32,
                           x: 200, y: 510, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Model selection by complexity", font: "HelveticaNeue-Bold", size: 30,
                           x: 280, y: 510, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 32,
                           x: 200, y: 440, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Protocol + factory + conditionals", font: "HelveticaNeue-Bold", size: 30,
                           x: 280, y: 440, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.checkCircle, font: "FontAwesome5Pro-Solid", size: 32,
                           x: 200, y: 370, color: operatorGreen, alignment: 0, isIcon: true),
        InfographicElement(text: "Identity != equality (test both)", font: "HelveticaNeue-Bold", size: 30,
                           x: 280, y: 370, color: commandWhite, alignment: 0, isIcon: false),
        InfographicElement(text: FAIcon.shieldCheck, font: "FontAwesome5Pro-Solid", size: 60,
                           x: 600, y: 230, color: operatorGreen, alignment: 1, isIcon: true),
        InfographicElement(text: "\"This is the way.\"", font: "HelveticaNeue-CondensedBold", size: 48,
                           x: 600, y: 140, color: commandWhite, alignment: 1, isIcon: false),
      ]),
  ]
}

/// Look up a chapter by its tag string (e.g. "CH01", "CH02A", etc.)
/// Also supports numeric lookup: "1" -> "CH01", "2" -> "CH02", etc.
/// Routes to the correct episode's chapter list based on episode number.
func findChapter(identifier: String, episode: Int = 1) -> Chapter? {
  let chapters = episode == 2 ? allChaptersEP02() : allChapters()
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
    <scenenode name="\(escapeXML(name))" id="\(id)" factoryID="\(textFactoryID)" version="5">
    \t\t\t<paragraphMarginsCached cached="0"/>
    \t\t\t<scrollMarginsCached cached="0"/>
    \t\t\t<crawlMarginsCached cached="0"/>
    \t\t\t<host hostID="0"/>
    \t\t\t<textPathModified textPathModifiedVal="0"/>
    \t\t\t<paragraphStyle id="\(paragraphID)"/>
    \t\t\t<style name="Style" id="\(styleID)" factoryID="\(styleFactoryID)">
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

// MARK: - Background-Based Template Generation

/// Path to the background OZML template with vector shapes (no text)
let backgroundMotnPath = "/Volumes/brick/media/background/background.motn"

/// Text factory ID used by textNode() — must match factory declaration added to background
let textFactoryID = 17
/// Style factory ID used by textNode() — must match factory declaration added to background
let styleFactoryID = 16

/// Two additional factory declarations needed for infographic text nodes.
/// These are appended to the background's existing factories.
let additionalFactories = """

<factory id="\(styleFactoryID)" uuid="044beba5ad3211d7ac9b000393833f6a">
\t<description>Style</description>
\t<manufacturer>Apple</manufacturer>
\t<version>1</version>
</factory>

<factory id="\(textFactoryID)" uuid="babfc7777f4711d7aaa7000393833f6a">
\t<description>Text</description>
\t<manufacturer>Apple</manufacturer>
\t<version>1</version>
</factory>

"""

/// Reads background.motn as the complete base template,
/// adds Text/Style factories, and inserts the infographic layer before </scene>.
/// No factory remapping needed — we use the background's own factory numbering
/// and add our text factories at IDs that don't conflict.
func generateFromBackground(chapter: Chapter) -> String {
  guard var content = try? String(contentsOfFile: backgroundMotnPath, encoding: .utf8) else {
    print("Error: Could not read background.motn at \(backgroundMotnPath)")
    return ""
  }

  // 1. Add Text and Style factory declarations after the last existing factory
  //    Find the last </factory> tag and insert after it
  guard let lastFactory = content.range(of: "</factory>", options: .backwards,
                                         range: content.startIndex..<content.range(of: "<build>")!.lowerBound) else {
    print("Error: Could not find factory declarations in background.motn")
    return ""
  }
  content.insert(contentsOf: additionalFactories, at: lastFactory.upperBound)

  // 2. Generate the infographic layer
  let infographicLayer = generateInfographicLayer(chapter: chapter)

  // 3. Insert infographic layer before </scene>
  guard let sceneEnd = content.range(of: "</scene>") else {
    print("Error: Could not find </scene> in background.motn")
    return ""
  }
  content.insert(contentsOf: infographicLayer + "\n", at: sceneEnd.lowerBound)

  return content
}

// MARK: - Infographic Layer Generation

/// Generates the OZML text nodes for a chapter's infographic layer (right dark panel).
/// Each InfographicElement becomes a text node; icons use Font Awesome font.
/// Progress bar elements render as block-character bars.
///
/// Coordinate system: Motion's canvas origin is at center (0,0) of a 3840×2160 canvas.
/// The right dark panel spans:
///   Motion coords: X=760→1880, Y=-860→1040 (center at X=1320, Y=90)
///
/// Element x/y values in InfographicElement are in panel-local design space:
///   x: 100–1100 (600 = panel center)
///   y: 0–800 (0 = bottom, 800 = top; higher y = higher visual position)
///
/// Conversion to Motion canvas coords:
///   canvasX = panelLeft + (element.x - 100) / 1000 * panelWidth
///   canvasY = panelBottom + (element.y / 800) * panelHeight
func generateInfographicLayer(chapter: Chapter) -> String {
  var layer = ""
  let layerID = 40000

  layer += "\t<layer name=\"Infographic: \(escapeXML(chapter.title))\" id=\"\(layerID)\">\n"

  for (i, element) in chapter.infographicLines.enumerated() {
    let nodeID = layerID + 100 + (i * 100)

    // Convert element coords (panel-local design space) to Motion canvas coords
    // Element x: 100→1100 maps to panel left→right (600 = center = X=1320)
    // Element y: 0→800 maps to panel bottom→top (0 = Y=-860, 800 = Y=1040)
    let canvasX = panelLeft + ((element.x - 100.0) / 1000.0) * panelWidth
    let canvasY = panelBottom + (element.y / 800.0) * panelHeight

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

  layer += layerClose(fixedWidth: 3840, fixedHeight: 2160)
  return layer
}

// MARK: - Chapter Template Generation

/// Generates a complete `.moti` OZML XML file for a single chapter.
/// Uses background.motn as the complete base (vector shapes only, no text),
/// then inserts only the infographic text layer for this chapter.
func generateChapterTemplate(chapter: Chapter, plan: ExecutionPlan) -> String {
  return generateFromBackground(chapter: chapter)
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
    \(layerClose(fixedWidth: 3840, fixedHeight: 2160))
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
      Generates a single Motion title template (.moti) in:
        ~/Movies/Motion Templates.localized/Titles.localized/casting-software-spells/EP01-infographics/

    Available chapters (EP01 - OPERATION PIPELINE EXODUS):
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

    Available chapters (EP02 - OPERATION MARKUP JAILBREAK):
      CH01  Opening
      CH02  Mission Briefing
      CH03  The Architecture
      CH04  The Migration
      CH05  The Bug
      CH06  Validation and Platform
      CH07  Closing

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
  guard let chapter = findChapter(identifier: chapterIdentifier, episode: episodeNumber) else {
    print("Error: Unknown chapter identifier '\(chapterIdentifier)'")
    print("Use --help or run without arguments to see available chapters.")
    exit(1)
  }

  print("Chapter: \(chapter.tag) - \(chapter.title)")
  print("  Start: \(chapter.startSeconds)s")
  print("  Duration: \(chapter.durationSeconds)s")
  print("  Infographic elements: \(chapter.infographicLines.count)")

  // Output: per-directory structure under Titles.localized/casting-software-spells/
  // Each chapter gets its own directory: CH01-opening/CH01-opening.moti, large.png, small.png
  // No Media/ subdirectory needed — background is embedded as vector shapes
  let templateName = "\(chapter.tag)-\(chapter.slug)"
  let templateDir = "\(titlesBase)/\(templateName)"
  let fm = FileManager.default

  // Create template directory
  try fm.createDirectory(atPath: templateDir, withIntermediateDirectories: true)

  // Generate .moti file for this chapter
  let motnContent = generateChapterTemplate(chapter: chapter, plan: plan)
  let motnFilename = "\(templateName).moti"
  let motnPath = "\(templateDir)/\(motnFilename)"
  try motnContent.write(toFile: motnPath, atomically: true, encoding: .utf8)
  print("Wrote: \(motnPath)")

  // Generate chapter-specific thumbnails (large.png and small.png, not prefixed)
  let largePath = "\(templateDir)/large.png"
  let smallPath = "\(templateDir)/small.png"
  generateChapterThumbnail(
    width: 320, height: 180, path: largePath, chapter: chapter, plan: plan)
  generateChapterThumbnail(
    width: 96, height: 96, path: smallPath, chapter: chapter, plan: plan)
  print("Wrote: \(largePath)")
  print("Wrote: \(smallPath)")

  print("\nChapter template generated at:")
  print("  \(templateDir)/\(motnFilename)")
  print("\nDirectory structure:")
  print("  \(templateDir)/")
  print("    \(motnFilename)")
  print("    large.png")
  print("    small.png")
  print("\nReady for FCPX: Titles > casting-software-spells > \(templateName)")

} catch {
  print("Error: \(error.localizedDescription)")
  exit(1)
}
