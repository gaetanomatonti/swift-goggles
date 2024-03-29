//
// Goggles
//
// Copyright © 2023 Gaetano Matonti. All rights reserved.
//

import AVFoundation
import OSLog
import SwiftUI
import Vision

/// The object that manages connection to the device camera and outputs a stream of images.
public final class Camera: NSObject {
  
  // MARK: - Stored Properties
  
  /// The stream of video frames.
  lazy var stream: AsyncStream<Image> = {
    AsyncStream { [weak self] continuation in
      self?.addToStream = { image in
        continuation.yield(image)
      }
    }
  }()
  
  /// The list of vision requests to process.
  private var visionRequests: Set<VNRequest>
  
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
  
  // MARK: - Computed Properties

  /// The device used for the capture session.
  private var captureDevice: AVCaptureDevice? {
    AVCaptureDevice.default(for: .video)
  }

  // MARK: - Init

  /// Creates an instance of the `Camera` object
  public init(visionRequests: Set<VNRequest> = []) {
    self.visionRequests = visionRequests
    
    super.init()
  }
  
  // MARK: - Functions
    
  /// Starts the capture session.
  public func startCapture() {
    if captureSession.inputs.isEmpty {
      do {
        try setupCaptureSession()
      } catch {
        logger.error("Failed to configure capture session. \(error.localizedDescription)")
        return
      }
    }
    
    guard !captureSession.isRunning else {
      logger.error("Capture session already running.")
      return
    }

    captureSessionQueue.async { [captureSession] in
      captureSession.startRunning()
    }
  }
  
  /// Stops the capture session.
  public func stopCapture() {
    guard captureSession.isRunning else {
      logger.error("Capture session is not running.")
      return
    }

    captureSessionQueue.async { [captureSession] in
      captureSession.stopRunning()
    }
  }
  
  /// Adds a Vision request to process.
  /// - Parameter request: The request to process.
  public func add(_ request: VNRequest) {
    visionRequests.insert(request)
  }
  
  /// Removes the specified vision from processing.
  /// - Parameter request: The request to stop processing.
  public func remove(_ request: VNRequest) {
    visionRequests.remove(request)
  }

  /// Sets up the capture session.
  private func setupCaptureSession() throws {
    guard let captureDevice else {
      logger.notice("Capture device not found.")
      return
    }
        
    if captureDevice.isFocusModeSupported(.continuousAutoFocus) {
      try captureDevice.lockForConfiguration()
      captureDevice.focusMode = .continuousAutoFocus
      captureDevice.unlockForConfiguration()
    }
    
    captureSession.beginConfiguration()
    
    defer {
      captureSession.commitConfiguration()
    }
    
    let videoInput = try AVCaptureDeviceInput(device: captureDevice)
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
    
    if let connection = videoOutput.connection(with: captureDevice.activeFormat.mediaType) {
      // Force portrait orientation.
      // Use `AVCaptureDevice.RotationCoordinator` to observe changes in orientation.
      let rotationAngle: CGFloat = 90
      if connection.isVideoRotationAngleSupported(rotationAngle) {
        connection.videoRotationAngle = rotationAngle
      }
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
      try? visionRequestHandler.perform(Array(visionRequests))
    }
    
    if let image = CIImage(cvPixelBuffer: pixelBuffer).image {
      addToStream?(image)
    }
  }
}
