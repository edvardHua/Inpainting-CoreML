//
//  Utils.swift
//  AOT-GAN-for-Inpainting-CoreML
//
//  Created by 間嶋大輔 on 2023/02/07.
//

import CoreML
import Foundation


func multiArrayToArray(_ multiArray: MLMultiArray) -> [Float32] {
    let count = multiArray.count
    var array = [Float32](repeating: 0.0, count: count)
    let pointer = multiArray.dataPointer.bindMemory(to: Float32.self, capacity: count)
    for i in 0..<count {
        array[i] = pointer[i]
    }
    return array
}


