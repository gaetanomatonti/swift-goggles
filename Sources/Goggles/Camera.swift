//
// Goggles
//
// Copyright © 2023 Gaetano Matonti. All rights reserved.
//

#if canImport(SwiftUI)
import AVFoundation
import OSLog
import SwiftUI
import Vision

/// The object that manages connection to the device camera and outputs a stream of images.
public final class Camera: NSObject {
  
  // MARK: - Stored Properties
  
  /// The stream of video frames.
  public lazy var stream: AsyncStream<Image> = {
    AsyncStream { [weak self] continuation in
      self?.addToStream = { image in
        continuation.yield(image)
      }
    }
  }()
  
  /// The list of vision requests to process.
  private let visionRequests: [VNRequest]
  
  /// The session managing the capture of the device.
  private let captureSession = AVCaptureSession()
  
  /// The queue that manages the execution of the capture session.
  private let captureSessionQueue = DispatchQueue(label: "CaptureSessionQueue")
  
  /// The queue that manages the execution of the video output.
  private let videoOutputQueue = DispatchQueue(label: "VideoOutputQueue")
  
  /// The object that logs messages to the unified logging system.
  private let logger = Logger(subsystem: subsystem, category: "Camera")

  /// Adds the specified `Image` to the video stream.
  private var addToStream: ((Image) -> Void)?

  // MARK: - Init

  /// Creates an instance of the `Camera` object
  public init(visionRequests: [VNRequest] = []) {
    self.visionRequests = visionRequests
    
    super.init()
    setup()
  }
  
  // MARK: - Functions
  
  private func setup() {
    #if !targetEnvironment(simulator)
    do {
      try setupCaptureSession()
      startSession()
    } catch {
      logger.critical("Failed to setup camera with error: \(error, privacy: .public)")
    }
    #endif
  }
  
  /// Sets up the capture session.
  private func setupCaptureSession() throws {
    guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
      return
    }
        
    if videoCaptureDevice.isFocusModeSupported(.continuousAutoFocus) {
      try videoCaptureDevice.lockForConfiguration()
      videoCaptureDevice.focusMode = .continuousAutoFocus
      videoCaptureDevice.unlockForConfiguration()
    }
    
    captureSession.beginConfiguration()
    
    defer {
      captureSession.commitConfiguration()
    }
    
    let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
    let videoOutput = AVCaptureVideoDataOutput()
        
    guard
      captureSession.canAddInput(videoInput),
      captureSession.canAddOutput(videoOutput)
    else {
      return
    }
    
    videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
    
    captureSession.addInput(videoInput)
    captureSession.addOutput(videoOutput)
    
    if let connection = videoOutput.connection(with: .video) {
      // Force portrait orientation.
      // Use `AVCaptureDevice.RotationCoordinator` to observe changes in orientation.
      let rotationAngle: CGFloat = 90
      if connection.isVideoRotationAngleSupported(rotationAngle) {
        connection.videoRotationAngle = rotationAngle
      }
    }
  }
  
  /// Starts the capture session.
  private func startSession() {
    captureSessionQueue.async { [captureSession] in
      captureSession.startRunning()
    }
  }
  
  /// Stops the capture session.
  private func stopSession() {
    captureSessionQueue.async { [captureSession] in
      captureSession.stopRunning()
    }
  }
}

extension Camera: AVCaptureVideoDataOutputSampleBufferDelegate {
  public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = sampleBuffer.imageBuffer else {
      return
    }
    
    if !visionRequests.isEmpty {
      let visionRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
      try? visionRequestHandler.perform(visionRequests)
    }
    
    if let image = CIImage(cvPixelBuffer: pixelBuffer).image {
      addToStream?(image)
    }
  }
}
#endif
