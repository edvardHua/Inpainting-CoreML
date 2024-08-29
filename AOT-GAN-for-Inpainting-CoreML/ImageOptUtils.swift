//
//  ImageOptUtils.swift
//  AOT-GAN-for-Inpainting-CoreML
//
//  Created by Edvard on 2024/8/19.
//

import Foundation
import UIKit
import CoreImage

// MARK: - pad and resize


///
/// - Parameters:
///   - image: UIImage
///   - lSide: Set long size of resize image
/// - Returns: UIImage
func resizeImageWithLongSide(image:UIImage, lSide:Int=512) -> (resImg: UIImage, scale: CGFloat){
    let oriWidth = image.size.width
    let oriHeight = image.size.height
    
    let longSide = max(oriWidth, oriHeight)
    let scale = CGFloat(lSide) / longSide
    
    let newWidth = oriWidth * scale
    let newHeight = oriHeight * scale
    
    let dstSize = CGSize(width: newWidth, height: newHeight)
    
    // 开始新的图形上下文以调整图像大小
    UIGraphicsBeginImageContextWithOptions(dstSize, false, image.scale)
    
    // 绘制调整大小后的图像
    image.draw(in: CGRect(origin: .zero, size: dstSize))
    
    // 获取调整大小后的图像
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
    
    // 结束图形上下文
    UIGraphicsEndImageContext()
    
    return (resImg: resizedImage!, scale: scale)
}


/// make image square
/// - Parameters:
///   - image: input uiimage
///   - padType: 0 - left top padding, 1 - center padding
/// - Returns: padded image
func padImageToSquare(image: UIImage, padType: Int = 0) -> (paddedImage: UIImage, xOffset: Int, yOffset: Int) {
    // 获取图像的宽度和高度
    let originalWidth = image.size.width
    let originalHeight = image.size.height
    
    // 计算新的尺寸
    let newDimension = max(originalWidth, originalHeight)
    
    // 创建一个新的正方形大小的上下文
    let squareSize = CGSize(width: newDimension, height: newDimension)
    
    UIGraphicsBeginImageContextWithOptions(squareSize, false, image.scale)
    
    // default top left pad
    var xOffset = 0.0
    var yOffset = 0.0
    // 计算绘制图像的原点，使图像居中
    if (padType == 1){
        xOffset = (newDimension - originalWidth) / 2
        yOffset = (newDimension - originalHeight) / 2
    }
    
    // 绘制图像
    image.draw(in: CGRect(x: xOffset, y: yOffset, width: originalWidth, height: originalHeight))
    
    // 获取新的图像
    let paddedImage = UIGraphicsGetImageFromCurrentImageContext()
    
    // 结束图形上下文
    UIGraphicsEndImageContext()
    
    return (paddedImage!, Int(xOffset), Int(yOffset))
}


func saveUIImageToDisk(image: UIImage) {
    let imageData = image.jpegData(compressionQuality: 1.0)!
    let fileManager = FileManager.default
    let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    print(documentsDirectory)
    let fileURL = documentsDirectory.appendingPathComponent("savedImage.jpg") // 可以更改文件名和扩展名
    do {
        try imageData.write(to: fileURL)
        print("图片保存成功: \(fileURL)")
    } catch {
        print("图片保存失败: \(error)")
    }
}


func blendImages(image1: UIImage, image2: UIImage, alpha: CGFloat) -> UIImage? {
    let size = image1.size
    
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    
    // 绘制第一张图片
    image1.draw(in: CGRect(origin: .zero, size: size))
    
    // 设置第二张图片的透明度
    image2.draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: alpha)
    
    // 从上下文获取最终的图像
    let blendedImage = UIGraphicsGetImageFromCurrentImageContext()
    
    UIGraphicsEndImageContext()
    
    return blendedImage
}


func drawDot(image: UIImage, dots: [[Double]]) -> UIImage{
    // 创建一个 CGSize，定义图像的尺寸
    let imageSize = image.size
    
    // 使用 UIGraphicsImageRenderer 创建一个图形上下文
    let renderer = UIGraphicsImageRenderer(size: imageSize)
    
    // 绘制新图像，添加点
    let renderedImage = renderer.image { context in
        // 将原始图像绘制到上下文
        image.draw(at: CGPoint.zero)
        
        // 设置点的颜色
        UIColor.red.setFill()
        
        // 定义要绘制的点位置和半径
        var points = [CGPoint]()
        
        for p in dots {
            points.append(CGPoint(x: p[0], y: p[1]))
        }
        
        let pointRadius: CGFloat = 5.0
        
        // 绘制每个点
        for point in points {
            let rect = CGRect(x: point.x - pointRadius, y: point.y - pointRadius, width: pointRadius * 2, height: pointRadius * 2)
            context.cgContext.fillEllipse(in: rect)
        }
    }
    return renderedImage
}
