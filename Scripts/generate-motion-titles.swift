#!/usr/bin/env swift

import AppKit
import Foundation

// MARK: - Configuration

let motionTemplatesBase = NSHomeDirectory() + "/Movies/Motion Templates.localized"
let titlesBase = motionTemplatesBase + "/Titles.localized/casting-software-spells"
let generatorsBase = motionTemplatesBase + "/Generators.localized/casting-software-spells"

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

// MARK: - OZML Title Generation

func generateTitleMoti(plan: ExecutionPlan) -> String {
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
    \(generateTextLayers(plan: plan))
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

func generateTextLayers(plan: ExecutionPlan) -> String {
  var layers = ""

  // Main title layer with operation name
  layers += """
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

  // Sortie status grid layer (for right panel overlay)
  if !plan.sorties.isEmpty {
    layers += "\n"
    layers += """
      \t<layer name="Sortie Grid" id="30000">
      """
    for (i, sortie) in plan.sorties.enumerated() {
      let yOffset = 400.0 - (Double(i) * 85.0)  // Stack vertically, top-down
      let statusText = "S\(sortie.number): \(sortie.task)"
      let statusLabel = sortie.status.displayLabel
      let c = sortie.status.color

      // Sortie label
      layers += """

        \t\t\(textNode(
                name: "Sortie \(sortie.number)",
                id: 30100 + (i * 100),
                styleID: 30103 + (i * 100),
                substanceID: 30150 + (i * 100),
                paragraphID: 30110 + (i * 100),
                text: statusText,
                font: "HelveticaNeue-CondensedBold",
                size: 36,
                tracking: 1,
                x: 1350, y: yOffset,
                alignment: 0,
                colorR: 0.85, colorG: 0.85, colorB: 0.85
            ))
        \t\t\(textNode(
                name: "Status \(sortie.number)",
                id: 31100 + (i * 100),
                styleID: 31103 + (i * 100),
                substanceID: 31150 + (i * 100),
                paragraphID: 31110 + (i * 100),
                text: statusLabel,
                font: "HelveticaNeue-Bold",
                size: 28,
                tracking: 3,
                x: 1350, y: yOffset - 35,
                alignment: 0,
                colorR: c.r, colorG: c.g, colorB: c.b
            ))
        """
    }
    layers += """

      \(layerClose(fixedWidth: 4096, fixedHeight: 2160))
      """
  }

  return layers
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

func escapeXML(_ s: String) -> String {
  s.replacingOccurrences(of: "&", with: "&amp;")
    .replacingOccurrences(of: "<", with: "&lt;")
    .replacingOccurrences(of: ">", with: "&gt;")
    .replacingOccurrences(of: "\"", with: "&quot;")
}

// MARK: - Thumbnail Generation

func generateThumbnail(width: Int, height: Int, path: String, plan: ExecutionPlan) {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
  )!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

  // Background
  NSColor.black.setFill()
  NSRect(x: 0, y: 0, width: width, height: height).fill()

  let isLarge = width > 200
  let scale: CGFloat = isLarge ? 1.0 : 0.35

  // Operation word
  let smallFont =
    NSFont(name: "HelveticaNeue-Light", size: 14 * scale)
    ?? NSFont.systemFont(ofSize: 14 * scale)
  let bigFont =
    NSFont(name: "HelveticaNeue-CondensedBold", size: 28 * scale)
    ?? NSFont.boldSystemFont(ofSize: 28 * scale)
  let tinyFont =
    NSFont(name: "HelveticaNeue-Light", size: 10 * scale)
    ?? NSFont.systemFont(ofSize: 10 * scale)

  let gray = NSColor(calibratedRed: 0.7, green: 0.7, blue: 0.7, alpha: 1)
  let midGray = NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)

  func drawCentered(_ text: String, font: NSFont, color: NSColor, y: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let str = NSAttributedString(string: text, attributes: attrs)
    let size = str.size()
    str.draw(at: NSPoint(x: (CGFloat(width) - size.width) / 2, y: y))
  }

  let centerY = CGFloat(height) / 2
  drawCentered(plan.operationWord, font: smallFont, color: gray, y: centerY + 10 * scale)
  drawCentered(plan.operationName, font: bigFont, color: .white, y: centerY - 20 * scale)
  drawCentered(
    "ITERATION \(plan.iteration)", font: tinyFont, color: midGray, y: centerY - 45 * scale)

  // Sortie status dots (if large)
  if isLarge && !plan.sorties.isEmpty {
    let dotSize: CGFloat = 8
    let spacing: CGFloat = 14
    let totalWidth = CGFloat(plan.sorties.count) * spacing
    let startX = (CGFloat(width) - totalWidth) / 2

    for (i, sortie) in plan.sorties.enumerated() {
      let c = sortie.status.color
      NSColor(calibratedRed: c.r, green: c.g, blue: c.b, alpha: 1).setFill()
      let dotRect = NSRect(
        x: startX + CGFloat(i) * spacing,
        y: 20,
        width: dotSize, height: dotSize
      )
      NSBezierPath(ovalIn: dotRect).fill()
    }
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
    Usage: \(name.lastPathComponent) <execution-plan-path> <podcast-path> <episode-number>

    Arguments:
      execution-plan-path  Path to EXECUTION_PLAN.md
      podcast-path         Path to podcast project directory
      episode-number       Episode number (e.g., 1)

    Output:
      Generates Motion title templates (.moti) in:
        ~/Movies/Motion Templates.localized/Titles.localized/casting-software-spells/

    Example:
      swift \(name.lastPathComponent) \\
        ~/Projects/SwiftSecuencia/EXECUTION_PLAN.md \\
        ~/Projects/podcast-casting-software-spells \\
        1
    """)
}

guard CommandLine.arguments.count == 4 else {
  printUsage()
  exit(1)
}

let executionPlanPath = NSString(string: CommandLine.arguments[1]).expandingTildeInPath
let podcastPath = NSString(string: CommandLine.arguments[2]).expandingTildeInPath
let episodeNumber = Int(CommandLine.arguments[3]) ?? 1

print("Parsing execution plan: \(executionPlanPath)")

do {
  let plan = try parseExecutionPlan(at: executionPlanPath)

  print("Operation: \(plan.featureName)")
  print("Branch: \(plan.branch)")
  print("Iteration: \(plan.iteration)")
  print("Sorties: \(plan.sorties.count)")

  for sortie in plan.sorties {
    print("  S\(sortie.number): \(sortie.task) [\(sortie.status.displayLabel)]")
  }

  // Build folder name: EP01-M00-Operation-Pipeline-Exodus
  let epTag = String(format: "EP%02d", episodeNumber)
  let mTag = String(format: "M%02d", Int(plan.iteration) ?? 0)
  let nameParts = plan.featureName.components(separatedBy: " ")
    .map { $0.capitalized }
    .joined(separator: "-")
  let folderName = "\(epTag)-\(mTag)-\(nameParts)"
  let templateName = "\(epTag) \(plan.featureName)"

  // Create output directories
  let titleDir = "\(titlesBase)/\(folderName)"
  let fm = FileManager.default

  if fm.fileExists(atPath: titleDir) {
    try fm.removeItem(atPath: titleDir)
    print("Replaced existing: \(folderName)")
  }

  try fm.createDirectory(atPath: titleDir, withIntermediateDirectories: true)
  try fm.createDirectory(atPath: "\(titleDir)/Media", withIntermediateDirectories: true)

  // Generate .moti
  let motiContent = generateTitleMoti(plan: plan)
  let motiPath = "\(titleDir)/\(templateName).moti"
  try motiContent.write(toFile: motiPath, atomically: true, encoding: .utf8)
  print("Wrote: \(motiPath)")

  // Generate thumbnails
  let largePath = "\(titleDir)/large.png"
  let smallPath = "\(titleDir)/small.png"
  generateThumbnail(width: 320, height: 180, path: largePath, plan: plan)
  generateThumbnail(width: 96, height: 96, path: smallPath, plan: plan)
  print("Wrote: \(largePath)")
  print("Wrote: \(smallPath)")

  print("\nTitle template generated at:")
  print("  \(titleDir)/")
  print("\nReady for FCPX: Titles > casting-software-spells > \(folderName)")

} catch {
  print("Error: \(error.localizedDescription)")
  exit(1)
}
