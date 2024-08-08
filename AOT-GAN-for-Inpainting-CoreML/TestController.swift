//
//  TestController.swift
//  AOT-GAN-for-Inpainting-CoreML
//
//  Created by Edvard on 2024/8/5.
//

import Foundation
import UIKit
import PhotosUI
import Vision
import CoreML
import CoreImage


class TestController: UIViewController,PHPickerViewControllerDelegate, UIPickerViewDelegate{

    let selectPhotoButton = UIButton()
    let runButton = UIButton()
    let imageView = UIImageView()
    var inputImage: UIImage?
    
    lazy var encoder: MLModel? = {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU
            let model = try sam_encoder(configuration: config).model
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
            let model = try sam_decoder(configuration: config).model
            return model
        } catch let error {
            print(error)
            fatalError("model decoder initialize error")
        }
    }()
    
    
    override func viewDidLoad() {
        setupView()
    }
    
    func setupView(){
        let buttonWidth = view.bounds.width*0.3
        selectPhotoButton.frame = CGRect(x: view.bounds.width*0.1, y:  view.bounds.maxY - 100, width: buttonWidth, height: 50)
        selectPhotoButton.setTitle("select Photo", for: .normal)
        selectPhotoButton.backgroundColor = .gray
        selectPhotoButton.setTitleColor(.white, for: .normal)
        selectPhotoButton.addTarget(self, action: #selector(presentPhPicker), for: .touchUpInside)
        
        
        runButton.frame = CGRect(x: view.bounds.maxX - view.bounds.width*0.1 - buttonWidth, y: view.bounds.maxY - 100, width: buttonWidth, height: 50)
        runButton.setTitle("run", for: .normal)
        runButton.backgroundColor = .gray
        runButton.setTitleColor(.white, for: .normal)
        runButton.addTarget(self, action: #selector(run), for: .touchUpInside)
        
        imageView.frame = CGRect(x:50, y:100, width: 224, height: 224)
        
        view.addSubview(imageView)
        view.addSubview(selectPhotoButton)
        view.addSubview(runButton)
        
    }
    
    @objc func presentPhPicker(){
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc func run() {
        let x = inputImage?.mlMultiArray()
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error  in
                if let image = image as? UIImage,  let safeSelf = self {
                    let correctOrientImage = safeSelf.getCorrectOrientationUIImage(uiImage: image)
                    
                    // pad 和 resize
                    let padResImage = safeSelf.padAndResizeImage(image: correctOrientImage, targetSize: CGSize(width: 224, height: 224))
                    
                    safeSelf.inputImage = padResImage
                    DispatchQueue.main.async {
                        safeSelf.imageView.image = padResImage
                    }
                }
            }
        }
        
    }
    
    func getCorrectOrientationUIImage(uiImage:UIImage) -> UIImage {
        var newImage = UIImage()
        let ciContext = CIContext()
        switch uiImage.imageOrientation.rawValue {
        case 1:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.down),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
            
            newImage = UIImage(cgImage: cgImage)
        case 3:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.right),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
            newImage = UIImage(cgImage: cgImage)
        default:
            newImage = uiImage
        }
        return newImage
    }
    
    func padImageToSquare(image: UIImage) -> UIImage? {
        // 获取图像的宽度和高度
        let originalWidth = image.size.width
        let originalHeight = image.size.height
        
        // 计算新的尺寸
        let newDimension = max(originalWidth, originalHeight)
        
        // 创建一个新的正方形大小的上下文
        let squareSize = CGSize(width: newDimension, height: newDimension)
        
        UIGraphicsBeginImageContextWithOptions(squareSize, false, image.scale)
        
        // 计算绘制图像的原点，使图像居中
        let xOffset = (newDimension - originalWidth) / 2
        let yOffset = (newDimension - originalHeight) / 2
        
        // 绘制图像
        image.draw(in: CGRect(x: xOffset, y: yOffset, width: originalWidth, height: originalHeight))
        
        // 获取新的图像
        let paddedImage = UIGraphicsGetImageFromCurrentImageContext()
        
        // 结束图形上下文
        UIGraphicsEndImageContext()
        
        return paddedImage
    }
    
    func padAndResizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
        
        let paddedImage = padImageToSquare(image: image)
        
        // 确保填充后的图像不为 nil
        guard let paddedImage = paddedImage else { return nil }
        
        // 开始新的图形上下文以调整图像大小
        UIGraphicsBeginImageContextWithOptions(targetSize, false, paddedImage.scale)
        
        // 绘制调整大小后的图像
        paddedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        
        // 获取调整大小后的图像
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        
        // 结束图形上下文
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
}


