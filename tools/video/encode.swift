// Encode captured frames into an H.264 MP4 with a caption bar and an optional corner badge.
// usage: encode manifest.json out.mp4 [width height]
import AVFoundation
import CoreGraphics
import CoreText
import Foundation
import ImageIO

struct Frame: Decodable { let file: String; let dur: Double; let caption: String; let badge: String; let speed: Double }

let args = CommandLine.arguments
let frames = try JSONDecoder().decode([Frame].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let out = URL(fileURLWithPath: args[2])
let W = args.count > 3 ? Int(args[3])! : 1280
let H = args.count > 4 ? Int(args[4])! : 800
try? FileManager.default.removeItem(at: out)

let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: args.count > 5 ? Int(args[5])! : 2_500_000, AVVideoMaxKeyFrameIntervalKey: 240, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel],
])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

func font(_ size: CGFloat, bold: Bool = false) -> CTFont { CTFontCreateWithName((bold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil) }

// Draw wrapped text in a rect (CoreGraphics origin is bottom-left).
func drawText(_ ctx: CGContext, _ text: String, _ rect: CGRect, _ size: CGFloat, color: CGColor, bold: Bool = false) {
    let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font(size, bold: bold), NSAttributedString.Key(kCTForegroundColorAttributeName as String): color]
    let fs = CTFramesetterCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    let frame = CTFramesetterCreateFrame(fs, CFRange(location: 0, length: 0), CGPath(rect: rect, transform: nil), nil)
    CTFrameDraw(frame, ctx)
}

func textHeight(_ text: String, width: CGFloat, size: CGFloat) -> CGFloat {
    let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font(size)]
    let fs = CTFramesetterCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    return CTFramesetterSuggestFrameSizeWithConstraints(fs, CFRange(location: 0, length: 0), nil, CGSize(width: width, height: 1000), nil).height
}

var imageCache: [String: CGImage] = [:]
func image(_ path: String) -> CGImage? {
    if let i = imageCache[path] { return i }
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    if imageCache.count > 8 { imageCache.removeAll() }
    imageCache[path] = img
    return img
}

var t = CMTime.zero
let timescale: CMTimeScale = 600
var written = 0
for f in frames {
    guard let img = image(f.file) else { continue }
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
    guard let buf = pb else { continue }
    CVPixelBufferLockBaseAddress(buf, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: W, height: H, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.setFillColor(CGColor(red: 0.07, green: 0.08, blue: 0.09, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    // Fit the frame (stills may have another aspect ratio).
    let s = min(CGFloat(W) / CGFloat(img.width), CGFloat(H) / CGFloat(img.height))
    let dw = CGFloat(img.width) * s, dh = CGFloat(img.height) * s
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: (CGFloat(W) - dw) / 2, y: (CGFloat(H) - dh) / 2, width: dw, height: dh))
    if !f.caption.isEmpty {
        let pad: CGFloat = 18, size: CGFloat = 22
        let h = textHeight(f.caption, width: CGFloat(W) - 2 * pad - 20, size: size) + 2 * pad
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.82))
        ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(W), height: h))
        drawText(ctx, f.caption, CGRect(x: pad + 10, y: pad - 4, width: CGFloat(W) - 2 * pad - 20, height: h - pad), size, color: CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    }
    var badge = f.badge
    if f.speed > 1.01 { badge = badge.isEmpty ? "SPED UP \(Int(f.speed.rounded()))×" : "\(badge) · SPED UP \(Int(f.speed.rounded()))×" }
    if !badge.isEmpty {
        let size: CGFloat = 17
        let attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): font(size, bold: true)]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: badge, attributes: attrs))
        let bw = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) + 28
        let rect = CGRect(x: CGFloat(W) - bw - 16, y: CGFloat(H) - 50, width: bw, height: 34)
        ctx.setFillColor(CGColor(red: 0.85, green: 0.45, blue: 0.1, alpha: 0.95))
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)); ctx.fillPath()
        drawText(ctx, badge, rect.insetBy(dx: 14, dy: 6).offsetBy(dx: 0, dy: -2), size, color: CGColor(red: 1, green: 1, blue: 1, alpha: 1), bold: true)
    }
    CVPixelBufferUnlockBaseAddress(buf, [])
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    adaptor.append(buf, withPresentationTime: t)
    t = CMTimeAdd(t, CMTime(seconds: max(f.dur, 0.02), preferredTimescale: timescale))
    written += 1
}
input.markAsFinished()
writer.endSession(atSourceTime: t)
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status != .completed { print("FAILED: \(String(describing: writer.error))"); exit(1) }
print("wrote \(written) frames, \(String(format: "%.1f", t.seconds)) s → \(out.path)")
