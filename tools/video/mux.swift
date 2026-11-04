// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Shailesh Vats
import AVFoundation
let a = CommandLine.arguments
let video = AVURLAsset(url: URL(fileURLWithPath: a[1])), audio = AVURLAsset(url: URL(fileURLWithPath: a[2]))
let out = URL(fileURLWithPath: a[3]); try? FileManager.default.removeItem(at: out)
let comp = AVMutableComposition()
let sem = DispatchSemaphore(value: 0)
Task {
  let vt = try await video.loadTracks(withMediaType: .video)[0]; let vd = try await video.load(.duration)
  let at = try await audio.loadTracks(withMediaType: .audio)[0]; let ad = try await audio.load(.duration)
  let cv = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
  try cv.insertTimeRange(CMTimeRange(start: .zero, duration: vd), of: vt, at: .zero)
  let ca = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
  try ca.insertTimeRange(CMTimeRange(start: .zero, duration: min(ad, vd)), of: at, at: .zero)
  let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetPassthrough)!
  ex.outputURL = out; ex.outputFileType = .mp4; ex.shouldOptimizeForNetworkUse = true
  await ex.export()
  print("export status \(ex.status.rawValue) error \(String(describing: ex.error))")
  sem.signal()
}
sem.wait()
