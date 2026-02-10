import Testing
import Foundation
@testable import SecuenciaCLI

@Suite("TimelineDefinition Tests")
struct TimelineDefinitionTests {

    // Example JSON from execution plan
    let exampleJSON = """
    {
      "timeline": {
        "name": "Tutorial Video",
        "format": {
          "width": 1920,
          "height": 1080,
          "frameRate": "23.98",
          "colorSpace": "rec709"
        },
        "audio": {
          "layout": "stereo",
          "rate": "48kHz"
        }
      },
      "clips": [
        {
          "name": "Title Card",
          "file": "media/title-card.png",
          "offset": "0s",
          "duration": "3s",
          "lane": 0,
          "type": "image"
        },
        {
          "name": "Act 1 Screen Recording",
          "file": "media/act1-screen.mov",
          "offset": "3s",
          "duration": "42s",
          "lane": 0,
          "type": "video"
        },
        {
          "name": "Act 1 Narration",
          "file": "media/act1-narration.m4a",
          "offset": "3s",
          "lane": -1,
          "type": "audio"
        },
        {
          "name": "Chapter 1",
          "offset": "0s",
          "type": "marker",
          "markerType": "chapter"
        }
      ]
    }
    """

    @Test("Decode example JSON from schema")
    func decodeExampleJSON() throws {
        let data = Data(exampleJSON.utf8)
        let decoder = JSONDecoder()

        let definition = try decoder.decode(TimelineDefinition.self, from: data)

        // Verify timeline config
        #expect(definition.timeline.name == "Tutorial Video")
        #expect(definition.timeline.format.width == 1920)
        #expect(definition.timeline.format.height == 1080)
        #expect(definition.timeline.format.frameRate == "23.98")
        #expect(definition.timeline.format.colorSpace == "rec709")
        #expect(definition.timeline.audio.layout == "stereo")
        #expect(definition.timeline.audio.rate == "48kHz")

        // Verify clips
        #expect(definition.clips.count == 4)

        // First clip - image
        let clip1 = definition.clips[0]
        #expect(clip1.name == "Title Card")
        #expect(clip1.file == "media/title-card.png")
        #expect(clip1.offset == "0s")
        #expect(clip1.duration == "3s")
        #expect(clip1.lane == 0)
        #expect(clip1.type == .image)
        #expect(clip1.markerType == nil)

        // Second clip - video
        let clip2 = definition.clips[1]
        #expect(clip2.name == "Act 1 Screen Recording")
        #expect(clip2.file == "media/act1-screen.mov")
        #expect(clip2.offset == "3s")
        #expect(clip2.duration == "42s")
        #expect(clip2.lane == 0)
        #expect(clip2.type == .video)

        // Third clip - audio
        let clip3 = definition.clips[2]
        #expect(clip3.name == "Act 1 Narration")
        #expect(clip3.file == "media/act1-narration.m4a")
        #expect(clip3.offset == "3s")
        #expect(clip3.lane == -1)
        #expect(clip3.type == .audio)

        // Fourth clip - marker
        let clip4 = definition.clips[3]
        #expect(clip4.name == "Chapter 1")
        #expect(clip4.file == nil)
        #expect(clip4.offset == "0s")
        #expect(clip4.type == .marker)
        #expect(clip4.markerType == "chapter")
    }

    @Test("Missing optional fields decode to nil")
    func missingOptionalFields() throws {
        let minimalJSON = """
        {
          "timeline": {
            "name": "Minimal Timeline",
            "format": {
              "width": 1920,
              "height": 1080,
              "frameRate": "24"
            },
            "audio": {
              "layout": "stereo",
              "rate": "48kHz"
            }
          },
          "clips": [
            {
              "name": "Test Clip",
              "file": "test.mov",
              "offset": "0s",
              "type": "video"
            }
          ]
        }
        """

        let data = Data(minimalJSON.utf8)
        let decoder = JSONDecoder()

        let definition = try decoder.decode(TimelineDefinition.self, from: data)

        // Verify optional fields are nil
        #expect(definition.timeline.format.colorSpace == nil)
        #expect(definition.clips[0].duration == nil)
        #expect(definition.clips[0].lane == nil)
        #expect(definition.clips[0].markerType == nil)
        #expect(definition.clips[0].volume == nil)
        #expect(definition.clips[0].opacity == nil)
    }

    @Test("Invalid type value produces DecodingError")
    func invalidTypeValue() throws {
        let invalidJSON = """
        {
          "timeline": {
            "name": "Invalid Timeline",
            "format": {
              "width": 1920,
              "height": 1080,
              "frameRate": "24"
            },
            "audio": {
              "layout": "stereo",
              "rate": "48kHz"
            }
          },
          "clips": [
            {
              "name": "Bad Clip",
              "file": "test.mov",
              "offset": "0s",
              "type": "invalid_type"
            }
          ]
        }
        """

        let data = Data(invalidJSON.utf8)
        let decoder = JSONDecoder()

        #expect(throws: DecodingError.self) {
            try decoder.decode(TimelineDefinition.self, from: data)
        }
    }

    @Test("Encode and decode roundtrip preserves all fields")
    func encodeDecodeRoundtrip() throws {
        let data = Data(exampleJSON.utf8)
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

        // Decode original
        let original = try decoder.decode(TimelineDefinition.self, from: data)

        // Encode to JSON
        let encodedData = try encoder.encode(original)

        // Decode again
        let decoded = try decoder.decode(TimelineDefinition.self, from: encodedData)

        // Verify timeline config matches
        #expect(decoded.timeline.name == original.timeline.name)
        #expect(decoded.timeline.format.width == original.timeline.format.width)
        #expect(decoded.timeline.format.height == original.timeline.format.height)
        #expect(decoded.timeline.format.frameRate == original.timeline.format.frameRate)
        #expect(decoded.timeline.format.colorSpace == original.timeline.format.colorSpace)
        #expect(decoded.timeline.audio.layout == original.timeline.audio.layout)
        #expect(decoded.timeline.audio.rate == original.timeline.audio.rate)

        // Verify all clips match
        #expect(decoded.clips.count == original.clips.count)

        for (index, clip) in original.clips.enumerated() {
            let decodedClip = decoded.clips[index]
            #expect(decodedClip.name == clip.name)
            #expect(decodedClip.file == clip.file)
            #expect(decodedClip.offset == clip.offset)
            #expect(decodedClip.duration == clip.duration)
            #expect(decodedClip.lane == clip.lane)
            #expect(decodedClip.type == clip.type)
            #expect(decodedClip.markerType == clip.markerType)
            #expect(decodedClip.volume == clip.volume)
            #expect(decodedClip.opacity == clip.opacity)
        }
    }
}
