import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("usage: extract_frames <video> <outdir> <count>")
    exit(1)
}
let videoPath = args[1]
let outDir = args[2]
let count = Int(args[3]) ?? 300

let url = URL(fileURLWithPath: videoPath)
let asset = AVURLAsset(url: url)

let durationTime = asset.duration
let duration = CMTimeGetSeconds(durationTime)
print("duration: \(duration)s")

let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
gen.maximumSize = CGSize(width: 1280, height: 1280)

let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let timescale: CMTimeScale = 600
var ok = 0
for i in 0..<count {
    let frac = count == 1 ? 0.0 : Double(i) / Double(count - 1)
    // keep last frame slightly inside to avoid past-end failures
    let t = min(duration * frac, duration - 0.02)
    let time = CMTime(seconds: t, preferredTimescale: timescale)
    do {
        let cg = try gen.copyCGImage(at: time, actualTime: nil)
        let idx = String(format: "%03d", i + 1)
        let outURL = URL(fileURLWithPath: "\(outDir)/frame-\(idx).jpg")
        guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            print("dest fail \(idx)"); continue
        }
        let opts: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.55]
        CGImageDestinationAddImage(dest, cg, opts as CFDictionary)
        if CGImageDestinationFinalize(dest) {
            ok += 1
            if (i+1) % 50 == 0 { print("wrote \(i+1)/\(count) (\(cg.width)x\(cg.height))") }
        }
    } catch {
        print("frame \(i) failed at \(t)s: \(error.localizedDescription)")
    }
}
print("DONE: \(ok)/\(count) frames")
