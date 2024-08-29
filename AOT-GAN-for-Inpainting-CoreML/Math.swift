//
//  Math.swift
//  AOT-GAN-for-Inpainting-CoreML
//
//  Created by Edvard on 2024/8/9.
//

import Foundation
import Accelerate

/**
  Returns the index and value of the largest element in the array.

  - Parameters:
    - count: If provided, only look at the first `count` elements of the array,
             otherwise look at the entire array.
*/
public func argmax(_ array: [Float], count: Int? = nil) -> (Int, Float) {
  var maxValue: Float = 0
  var maxIndex: vDSP_Length = 0
  vDSP_maxvi(array, 1, &maxValue, &maxIndex, vDSP_Length(count ?? array.count))
  return (Int(maxIndex), maxValue)
}
