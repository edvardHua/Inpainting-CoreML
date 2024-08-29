//
//  DotTool.swift
//  AOT-GAN-for-Inpainting-CoreML
//
//  Created by Edvard on 2024/8/16.
//

import Foundation
import Drawsana
import CoreGraphics


public class DotTool: DrawingToolForShapeWithOnePoint {
    public override var name: String { return "Ellipse" }
    public override func makeShape() -> ShapeType { return EllipseShape() }
}

/**
 class for one dot
 */
public class DrawingToolForShapeWithOnePoint: DrawingTool {
    public typealias ShapeType = Shape & ShapeWithTwoPoints
    
    open var name: String { fatalError("Override me") }
    
    public var pointsCache = [CGPoint]()
    
    public var shapeInProgress: ShapeType?
    
    public var isProgressive: Bool { return false }
    
    public init() { }
    
    /// Override this method to return a shape ready to be drawn to the screen.
    open func makeShape() -> ShapeType {
        fatalError("Override me")
    }
    
    public func handleTap(context: ToolOperationContext, point: CGPoint) {
    }
    
    public func handleDragStart(context: ToolOperationContext, point: CGPoint) {
        shapeInProgress = makeShape()
        shapeInProgress?.a = point
        shapeInProgress?.b = point
        shapeInProgress?.apply(userSettings: context.userSettings)
    }
    
    public func handleDragContinue(context: ToolOperationContext, point: CGPoint, velocity: CGPoint) {
        //    shapeInProgress?.b = point
    }
    
    public func handleDragEnd(context: ToolOperationContext, point: CGPoint) {
        guard var shape = shapeInProgress else { return }
        pointsCache.append(point)
        print(point)
        //    shape.b = point
        context.operationStack.apply(operation: AddShapeOperation(shape: shape))
        shapeInProgress = nil
    }
    
    public func handleDragCancel(context: ToolOperationContext, point: CGPoint) {
        // No such thing as a cancel for this tool. If this was recognized as a tap,
        // just end the shape normally.
        handleDragEnd(context: context, point: point)
    }
    
    public func renderShapeInProgress(transientContext: CGContext) {
        shapeInProgress?.render(in: transientContext)
    }
    
    public func apply(context: ToolOperationContext, userSettings: UserSettings) {
        shapeInProgress?.apply(userSettings: userSettings)
        context.toolSettings.isPersistentBufferDirty = true
    }
}


