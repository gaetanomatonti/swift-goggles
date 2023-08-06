//
//  CIImage+Extensions.swift
//  
//
//  Created by Gaetano Matonti on 06/08/23.
//

import CoreImage
import SwiftUI

extension CIImage {
  var image: Image? {
    let ciContext = CIContext()
    
    guard let cgImage = ciContext.createCGImage(self, from: self.extent) else {
      return nil
    }
    
    return Image(decorative: cgImage, scale: 1, orientation: .up)
  }
}
