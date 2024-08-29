//
//  TestController.swift
//  AOT-GAN-for-Inpainting-CoreML
//
//  Created by Edvard on 2024/8/5.
//

import Foundation
import UIKit
import PhotosUI
import CoreImage
import CoreGraphics
import Drawsana



class TestController: UIViewController,PHPickerViewControllerDelegate, UIPickerViewDelegate{

    let selectPhotoButton = UIButton()
    let runButton = UIButton()
    let imageView = UIImageView()
    var inputImage: UIImage?
    
    let drawsanaView = DrawsanaView()
    let tool = DotTool()
    let sam = EdgeSam()
    
    // 设置 resize 后图片最长的边
    var maxLongSide = 512
    // 显示容器的 size
    var displaySize: CGSize = CGSize(width: 0, height: 0)
    // pad 时对应的坐标位
    var topLeft:CGPoint = CGPoint(x: 0, y: 0)
    var bottomRight:CGPoint = CGPoint(x: 0, y: 0)
    
    override func viewDidLoad() {
        setupView()
        setupDrawView()
    }
    
    func setupView(){
        let buttonWidth = view.bounds.width*0.3
        selectPhotoButton.frame = CGRect(x: view.bounds.width*0.1, y:  view.bounds.maxY - 100, width: buttonWidth, height: 50)
        selectPhotoButton.setTitle("Select Photo x", for: .normal)
        selectPhotoButton.backgroundColor = .gray
        selectPhotoButton.setTitleColor(.white, for: .normal)
        selectPhotoButton.addTarget(self, action: #selector(presentPhPicker), for: .touchUpInside)
        
        
        runButton.frame = CGRect(x: view.bounds.maxX - view.bounds.width*0.1 - buttonWidth, y: view.bounds.maxY - 100, width: buttonWidth, height: 50)
        runButton.setTitle("run", for: .normal)
        runButton.backgroundColor = .gray
        runButton.setTitleColor(.white, for: .normal)
        runButton.addTarget(self, action: #selector(run), for: .touchUpInside)
        
        // 根据父 view 的尺寸大小来调整
        let parentViewHeight = view.bounds.size.height
        maxLongSide = Int(parentViewHeight * 0.7)
        imageView.frame = CGRect(x:50, y:50, width: Int(view.bounds.size.width * 0.9), height: maxLongSide)
        
        displaySize.width = view.bounds.size.width * 0.9
        displaySize.height = CGFloat(maxLongSide)
        
        // 先直接设置为512x512吧
//        maxLongSide = 512
//        imageView.frame = CGRect(x:50, y:50, width: 512, height: maxLongSide)
//        
//        displaySize.width = CGFloat(512)
//        displaySize.height = CGFloat(512)
        
        view.addSubview(imageView)
        view.addSubview(selectPhotoButton)
        view.addSubview(runButton)
    }
    
    func setupDrawView() {
        drawsanaView.set(tool: tool)
        drawsanaView.userSettings.strokeWidth = 5
        drawsanaView.userSettings.strokeColor = .blue
        drawsanaView.userSettings.fillColor = .yellow
        drawsanaView.userSettings.fontSize = 24
        drawsanaView.userSettings.fontName = "Marker Felt"
        drawsanaView.frame = imageView.frame
        view.addSubview(drawsanaView)
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
        
//        let img = testLoadImg()
//        sam.setImage(inpImg: img)
//        sam.inferMask(coordPrompt: [[252.7,72.91], [254.13, 100.74], [254.13, 200], [254.13, 200.74]])
        
//        let jsonEncoder = JSONEncoder()
//        jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
//        let jsonData = try! jsonEncoder.encode(drawsanaView.drawing)
//        print(String(data: jsonData, encoding: .utf8)!)
        
//        let pointPrompt: [[Double]] = [[201.0, 217.5], [237.5, 158.0]]
//        let mask = sam.inferMask(coordPrompt: pointPrompt)
//        loadPaintByMask(maskGray: mask)
        
        
        var pointPrompt = [CGPoint]()
        let penPoints = tool.pointsCache
        // 减去padoffst
        for p in penPoints{
            pointPrompt.append(CGPoint(x: p.x - topLeft.x, y: p.y - topLeft.y))
        }
        
        let mask = sam.inferMask(coordPrompt: pointPrompt)
        loadPaintByMask(maskGray: mask)
    }
    
    func loadPaintByMask(maskGray:CGImage) {
        let width = maskGray.width
        let height = maskGray.height
        
        let bytesPerPixel = maskGray.bitsPerPixel / 8
        let bytesPerRow = maskGray.bytesPerRow
        
        let dataProvider = maskGray.dataProvider
        let pixelData = CFDataGetBytePtr(dataProvider!.data)!
        
        var pointsToPaint = [CGPoint]()
        // 遍历每个像素
        for y in stride(from: 0, to: height, by: 5) {
            for x in stride(from: 0, to: width, by: 5){
                let pixelIndex = y * bytesPerRow + x * bytesPerPixel
                let gray = pixelData[pixelIndex]
                if gray > 0{
                    // 加上 padoffset
                    pointsToPaint.append(CGPoint(x: CGFloat(x) + topLeft.x, y: CGFloat(y) + topLeft.y))
                }
            }
        }
        
        loadMaskToDrawsanaView(points: pointsToPaint)
    }
    
    
    func loadMaskToDrawsanaView(points:[CGPoint]) {
        let penShape = PenShape()
        penShape.start = points[0]
        penShape.strokeColor = .blue
        penShape.strokeWidth = 2.5
        
        for p in points{
            penShape.add(segment: PenLineSegment(
                a: p,
                b: p, width: 2.5))
        }
        drawsanaView.drawing.add(shape: penShape)
    }
    
    
    func testLoadImg() -> UIImage{
        // 获取文档目录路径
        let fileManager = FileManager.default
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]

        // 指定图片的文件名
        let fileName = "8_pad.png"  // 你保存图片时使用的文件名
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        let image = UIImage(contentsOfFile: fileURL.path)
        return image!
    }
    
    
    // MARK: - Pick image
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error  in
                if let image = image as? UIImage,  let safeSelf = self {
                    let correctOrientImage = safeSelf.getCorrectOrientationUIImage(uiImage: image)
                    
                    // pad 和 resize
                    let outRes = resizeImageWithLongSide(image: correctOrientImage, lSide: safeSelf.maxLongSide)
                    safeSelf.inputImage = outRes.resImg
                    
                    DispatchQueue.main.async {
                        let padImg = safeSelf.padImage(image: outRes.resImg)
                        safeSelf.imageView.image = padImg
                        safeSelf.sam.setImage(inpImg: outRes.resImg)
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
    
    func padImage(image:UIImage) -> UIImage{
        let originalWidth = image.size.width
        let originalHeight = image.size.height
        UIGraphicsBeginImageContextWithOptions(displaySize, false, image.scale)
        let xOffset = (displaySize.width - originalWidth) / 2
        let yOffset = (displaySize.height - originalHeight) / 2
        topLeft.x = xOffset
        topLeft.y = yOffset
        bottomRight.x = xOffset + originalWidth
        bottomRight.y = yOffset + originalHeight
        image.draw(in: CGRect(x: xOffset, y: yOffset, width: originalWidth, height: originalHeight))
        let paddedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return paddedImage!
    }
    
    // MARK: - drawing setting
    func resetDrawingView() {
        if drawsanaView.drawing.shapes.count != 0 {
            for _ in 0...drawsanaView.drawing.shapes.count-1 {
                drawsanaView.operationStack.undo()
            }
        }
    }
}


