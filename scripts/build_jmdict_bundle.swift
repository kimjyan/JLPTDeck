#!/usr/bin/env swift
//
// build_jmdict_bundle.swift
//
// Build-time tool that produces JLPTDeck's bundled `jmdict_n4_n1.json`
// by joining a JMdict XML export against the Tanos JLPT vocabulary lists.
//
// Usage:
//   swift scripts/build_jmdict_bundle.swift \
//       --jmdict   /path/to/JMdict_e.xml \
//       --tanos-dir /path/to/tanos-lists/ \
//       --out      JLPTDeck/Resources/jmdict_n4_n1.json
//
// Expected files in --tanos-dir:
//   n4-vocab-kanji.utf
//   n3-vocab-kanji.utf
//   n2-vocab-kanji.utf
//   n1-vocab-kanji.utf
// Each file is UTF-8, one entry per line. Lines may be whitespace / tab
// separated — only the first token is used as the headword key.
//
// Level tie-break: when a Tanos headword appears in multiple level files, the
// LOWER (easier) level wins. n4 beats n3 beats n2 beats n1.
//
// Sources / attribution (both required in the shipping app):
//   JMdict — Electronic Dictionary Research and Development Group
//            https://www.edrdg.org/jmdict/edict_doc.html
//            Licensed CC BY-SA 3.0.
//   Tanos JLPT lists — Jonathan Waller, https://www.tanos.co.uk/jlpt/
//

import Foundation

// MARK: - Arg parsing

struct Args {
    var jmdictPath: String
    var tanosDir: String
    var outPath: String
}

func parseArgs() -> Args {
    var jmdict: String?
    var tanos: String?
    var out: String?
    let argv = CommandLine.arguments
    var i = 1
    while i < argv.count {
        let flag = argv[i]
        let next: String? = (i + 1 < argv.count) ? argv[i + 1] : nil
        switch flag {
        case "--jmdict":    jmdict = next; i += 2
        case "--tanos-dir": tanos  = next; i += 2
        case "--out":       out    = next; i += 2
        default:
            FileHandle.standardError.write(Data("unknown arg: \(flag)\n".utf8))
            exit(2)
        }
    }
    guard let j = jmdict, let t = tanos, let o = out else {
        FileHandle.standardError.write(Data("""
            usage: build_jmdict_bundle.swift \
                --jmdict PATH --tanos-dir DIR --out PATH

            """.utf8))
        exit(2)
    }
    return Args(jmdictPath: j, tanosDir: t, outPath: o)
}

// MARK: - Level model

enum JLPTLevel: String, CaseIterable {
    case n4, n3, n2, n1
    var rank: Int {
        switch self {
        case .n4: return 0
        case .n3: return 1
        case .n2: return 2
        case .n1: return 3
        }
    }
}

// MARK: - Tanos list loader

func loadTanosMap(dir: String) throws -> [String: JLPTLevel] {
    var map: [String: JLPTLevel] = [:]
    let fm = FileManager.default
    for level in JLPTLevel.allCases {
        let path = (dir as NSString).appendingPathComponent("\(level.rawValue)-vocab-kanji.utf")
        guard fm.fileExists(atPath: path) else {
            FileHandle.standardError.write(Data("warning: missing \(path)\n".utf8))
            continue
        }
        let raw = try String(contentsOfFile: path, encoding: .utf8)
        for rawLine in raw.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            // Accept tab or space-separated; first token is headword.
            let first = line.split(whereSeparator: { $0 == "\t" || $0 == " " }).first.map(String.init) ?? line
            if first.isEmpty { continue }
            if let existing = map[first] {
                if level.rank < existing.rank { map[first] = level } // lower level wins
            } else {
                map[first] = level
            }
        }
    }
    return map
}

// MARK: - JMdict SAX parser

final class JMdictParser: NSObject, XMLParserDelegate {
    struct Entry {
        var keb: String?       // first <k_ele>/<keb>
        var reb: String?       // first <r_ele>/<reb>
        var gloss: String?     // first <sense>/<gloss>
    }

    var tanos: [String: JLPTLevel] = [:]
    var results: [(headword: String, reading: String, gloss: String, level: JLPTLevel)] = []

    private var current = Entry()
    private var buffer = ""
    private var elementStack: [String] = []
    private var seenKeb = false
    private var seenReb = false
    private var seenGloss = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        elementStack.append(elementName)
        buffer = ""
        if elementName == "entry" {
            current = Entry()
            seenKeb = false
            seenReb = false
            seenGloss = false
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        defer { if !elementStack.isEmpty { elementStack.removeLast() } }
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "keb":
            if !seenKeb { current.keb = text; seenKeb = true }
        case "reb":
            if !seenReb { current.reb = text; seenReb = true }
        case "gloss":
            if !seenGloss { current.gloss = text; seenGloss = true }
        case "entry":
            if let keb = current.keb, let reb = current.reb, let gloss = current.gloss,
               let level = tanos[keb] {
                results.append((keb, reb, gloss, level))
            }
        default:
            break
        }
        buffer = ""
    }
}

// MARK: - Main

let args = parseArgs()

let tanos: [String: JLPTLevel]
do {
    tanos = try loadTanosMap(dir: args.tanosDir)
} catch {
    FileHandle.standardError.write(Data("failed to load Tanos lists: \(error)\n".utf8))
    exit(1)
}
print("Loaded Tanos headwords: \(tanos.count)")

guard let xmlData = FileManager.default.contents(atPath: args.jmdictPath) else {
    FileHandle.standardError.write(Data("cannot read JMdict file: \(args.jmdictPath)\n".utf8))
    exit(1)
}

let parser = XMLParser(data: xmlData)
parser.shouldResolveExternalEntities = false
let delegate = JMdictParser()
delegate.tanos = tanos
parser.delegate = delegate

guard parser.parse() else {
    let err = parser.parserError.map { "\($0)" } ?? "unknown"
    FileHandle.standardError.write(Data("JMdict parse failed: \(err)\n".utf8))
    exit(1)
}

// Emit JSON
struct OutEntry: Encodable {
    let headword: String
    let reading: String
    let gloss: String
    let jlptLevel: String
}

let outEntries = delegate.results.map {
    OutEntry(headword: $0.headword, reading: $0.reading, gloss: $0.gloss, jlptLevel: $0.level.rawValue)
}

var countsByLevel: [String: Int] = [:]
for e in outEntries { countsByLevel[e.jlptLevel, default: 0] += 1 }

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let outData: Data
do {
    outData = try encoder.encode(outEntries)
} catch {
    FileHandle.standardError.write(Data("encode failed: \(error)\n".utf8))
    exit(1)
}

do {
    let outURL = URL(fileURLWithPath: args.outPath)
    try FileManager.default.createDirectory(
        at: outURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try outData.write(to: outURL)
} catch {
    FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
    exit(1)
}

print("Wrote \(outEntries.count) entries to \(args.outPath)")
for level in ["n4", "n3", "n2", "n1"] {
    print("  \(level): \(countsByLevel[level] ?? 0)")
}
