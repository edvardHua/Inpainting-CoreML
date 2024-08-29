//
//  PaintController.swift
//  AOT-GAN-for-Inpainting-CoreML
//
//  Created by Edvard on 2024/8/15.
//

import CoreML
import UIKit
import Foundation

class EdgeSam {
    
    let embedInpWidth = 512
    let embedInpHeight = 512
    let maskWidth = 128
    let maskHeight = 128
    
    // 储存原始图片的 size 和 pad的信息，用于还原尺寸用
    var originSize = CGSize(width: 512, height: 512)
    var topLeft = CGPoint(x: 0, y: 0)
    var bottonRight = CGPoint(x: 0, y: 0)
    var scale = CGFloat(1.0)
    var image_embedding:MLMultiArray?
    
    // cache origin input uiimage, for test purpose
//    var oriUIImg: UIImage?
    
    
    lazy var encoder: MLModel? = {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU
            let model = try sam_encoder_512(configuration: config).model
            return model
        } catch let error {
            print(error)
            fatalError("model encoder initialize error")
        }
    }()
    
    lazy var decoder: MLModel? = {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU
            let model = try sam_decoder_512(configuration: config).model
            return model
        } catch let error {
            print(error)
            fatalError("model decoder initialize error")
        }
    }()
    
    
    func setImage(inpImg:UIImage){
        var img: UIImage
//        oriUIImg = inpImg
        
        originSize = inpImg.size
        if originSize.width != CGFloat(embedInpWidth) || originSize.height != CGFloat(embedInpHeight) {
            // 不满足则先按长边进行 resize
            let outRes = resizeImageWithLongSide(image: inpImg, lSide: Int(embedInpWidth))
            img = outRes.resImg
            scale = outRes.scale
            let padRes = padImageToSquare(image: img, padType: 0)
            // 用来对输出的 mask 做 crop
            topLeft.x = CGFloat(padRes.xOffset)
            topLeft.y = CGFloat(padRes.yOffset)
            bottonRight.x = (CGFloat(padRes.xOffset) + img.size.width)
            bottonRight.y = (CGFloat(padRes.yOffset) + img.size.height)
            img = padRes.paddedImage
        }else{
            img = inpImg
        }
        
        // 这里不对像素值做归一化
        let inputMlarr = img.mlMultiArray(scale: 1.0)
        
        // run encoder
        let start = Date()
        let encoderInput = sam_encoder_512Input(image: inputMlarr)
        let out = try! encoder!.prediction(from: encoderInput)
        let timeElapsed = -start.timeIntervalSinceNow
        print("encoder infer cost ", timeElapsed)
        // 1x256x32x32
        image_embedding = out.featureValue(for: "image_embeddings")!.multiArrayValue
    }
    
    
    ///
    /// - Parameters:
    ///   - img: uiimage
    ///   - coordPrompt: [[w1, h1], [w2, h2]]  maximum coord nums is 4
    func inferMask(coordPrompt: [CGPoint]) -> CGImage{
//        let imgWithDot = drawDot(image: oriUIImg!, dots: coordPrompt)
//        saveUIImageToDisk(image: imgWithDot)
        
        // 把 coord 转换成 mlmultiarray
        let coordCount = coordPrompt.count
        let pointArr = try! MLMultiArray(shape: [1, NSNumber(value: coordCount), 2], dataType: .float32)
        for i in 0..<coordPrompt.count {
            // 需要先乘缩放，再加上 padding 时的偏移 offset
            pointArr[[0, i, 0] as [NSNumber]] = NSNumber(value: coordPrompt[i].x * scale + topLeft.x)
            pointArr[[0, i, 1] as [NSNumber]] = NSNumber(value: coordPrompt[i].y * scale + topLeft.y)
        }
        
//        print(pointArr[[0, 0, 0]], pointArr[[0, 0, 1]])
//        print(pointArr[[0, 1, 0]], pointArr[[0, 1, 1]])
//        
//        for i in 0..<10{
//            print(image_embedding![[0, 0, 10, i as NSNumber]])
//        }
        
        // 对应的 coord 都为 positive label
        let label = [Double](repeating: 1, count: coordCount)
        guard let labelArr = try? MLMultiArray(shape: [1, NSNumber(value: coordCount)], dataType: .float32) else {
            fatalError("Could not create MLMultiArray")
        }
        for i in 0..<label.count {
            labelArr[[0, i] as [NSNumber]] = NSNumber(value: label[i])
        }
        
        let start2 = Date()
        // run decoder
        let decoderInput = sam_decoder_512Input(image_embeddings: image_embedding!, point_coords: pointArr, point_labels: labelArr)
        let out2 = try! decoder!.prediction(from: decoderInput)
        let timeElapsed2 = -start2.timeIntervalSinceNow
        print("decoder infer cost ", timeElapsed2)
        
        // scores, masks
        let outScores = out2.featureValue(for: "scores")!.multiArrayValue
        let outMasks = out2.featureValue(for: "masks")!.multiArrayValue
        
        let scoresArr = multiArrayToArray(outScores!)
        
        var maxInd = 0
        var maxVal = Float(0.0)
        for i in 0..<scoresArr.count {
            if scoresArr[i] > maxVal{
                maxInd = i
                maxVal = scoresArr[i]
            }
            print(scoresArr[i])
        }
        // gray cgimage -> crop -> resize ->
        let mask = toGray(arr: outMasks!, ind: maxInd, doPost: false)
        let cropMask = mask.cropping(to: CGRect(x: topLeft.x, y: topLeft.y, width: bottonRight.x - topLeft.x, height: bottonRight.y - topLeft.y))
        let maskRes = cropMask!.resize(size: originSize)
//        let blendRes = blendImages(image1: oriUIImg!, image2: UIImage(cgImage: maskRes!), alpha: 0.8)!
//        saveUIImageToDisk(image: blendRes)
        return maskRes!
    }
    
     
    /// 把图像转换成灰度图
    /// - Parameters:
    ///   - arr: MLMultiArray, 1, channel, height, width
    ///   - ind: index of channel
    func toGray(arr:MLMultiArray, ind:Int, doPost:Bool = true) -> CGImage{
        
        let height = arr.shape[2].intValue
        let width = arr.shape[3].intValue
        let chanStrid = arr.strides[1].intValue
        let heightStrid = arr.strides[2].intValue
        let widthStrid = arr.strides[3].intValue
        
        // 转换为灰度，每个像素值占 1 bytes = 8 bit
        let bytesPerPixel = 1
        let count = height * width * bytesPerPixel
        var pixels = [UInt8](repeating: 255, count: count)
        
        let ptr = UnsafeMutablePointer<Float32>(OpaquePointer(arr.dataPointer))
        //        ptr = ptr.advanced(by: chanStrid * ind)
        
        for y in 0..<height {
            for x in 0..<width {
                let value = ptr[y*heightStrid + x*widthStrid + chanStrid * ind]
                let scaled = Float32(255) * value
                let pixel = clamp(scaled, min: 0, max: 255).toUInt8
                pixels[(y*heightStrid + x * widthStrid) * bytesPerPixel] = pixel
            }
        }
        
        let grayCgImg = pixels.withUnsafeBytes { ptr in
            let context = CGContext(data: UnsafeMutableRawPointer(mutating: ptr.baseAddress!),
                                    width: width,
                                    height: height,
                                    bitsPerComponent: 8,
                                    bytesPerRow: width,
                                    space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: CGImageAlphaInfo.none.rawValue)
            return context?.makeImage()
        }
        
        if doPost{
            return postProc(maskImage: grayCgImg!, targetWidth: embedInpWidth, targetHeight: embedInpHeight)
        }
        
        return grayCgImg!.resize(size: CGSize(width: embedInpWidth, height: embedInpHeight))!
    }
    
    
    
    /// <#Description#>
    /// - Parameters:
    ///   - maskImage: <#maskImage description#>
    ///   - targetWidth: <#targetWidth description#>
    ///   - targetHeight: <#targetHeight description#>
    /// - Returns: <#description#>
    func postProc(maskImage: CGImage, targetWidth: Int, targetHeight: Int) -> CGImage{
        // 2. 获取颜色空间
        guard let colorSpace = maskImage.colorSpace else {
            fatalError("无法获取颜色空间")
        }
        
        // 3. 创建 Core Image 上下文
        let ciContext = CIContext()
        
        // 4. 将 CGImage 转换为 CIImage
        let ciImage = CIImage(cgImage: maskImage)
        
        // 5. 应用膨胀滤镜
        let dilateFilter = CIFilter(name: "CIMorphologyMaximum")!
        dilateFilter.setValue(ciImage, forKey: kCIInputImageKey)
        dilateFilter.setValue(3, forKey: kCIInputRadiusKey) // 调整半径控制膨胀效果
        guard let dilatedImage = dilateFilter.outputImage else {
            fatalError("膨胀滤镜应用失败")
        }
        
        // 6. 应用高斯模糊滤镜
        //        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        //        blurFilter.setValue(dilatedImage, forKey: kCIInputImageKey)
        //        blurFilter.setValue(2, forKey: kCIInputRadiusKey) // 调整模糊半径
        //        guard let blurredImage = blurFilter.outputImage else {
        //            fatalError("高斯模糊滤镜应用失败")
        //        }
        
        // 7. 将处理后的 CIImage 转换回 CGImage
        guard let processedCGImage = ciContext.createCGImage(dilatedImage, from: dilatedImage.extent) else {
            fatalError("无法创建处理后的 CGImage")
        }
        
        
        // 9. 创建 CGContext 以执行 resize
        guard let context = CGContext(data: nil,
                                      width: targetWidth,
                                      height: targetHeight,
                                      bitsPerComponent: processedCGImage.bitsPerComponent,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: processedCGImage.bitmapInfo.rawValue) else {
            fatalError("无法创建 CGContext")
        }
        
        // 10. 设置插值质量
        context.interpolationQuality = .high
        
        // 11. 将处理后的 CGImage 绘制到新的 CGContext 中并进行 resize
        context.draw(processedCGImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        return context.makeImage()!
    }

}
