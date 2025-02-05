//
//  FreedrawExtensions.swift
//  pdfView Freedraw
//
//  Created by Ron Regev on 11/10/2020.
//

import UIKit
import PDFKit

extension UIBezierPath {
    
    /// Extracts all of the path elements, their points and their control points. Returned expect types are the strings `"move"`, `"addLine"`, `"addQuadCurve"` and `"addCurve"`.
    func getPathElements() -> [(type: String?, point: CGPoint?, controlPoint: CGPoint?, controlPoint1: CGPoint?, controlPoint2: CGPoint?)] {
        
        let initialPath = UIBezierPath(cgPath: self.cgPath)
        var bezierPoints = NSMutableArray()
        initialPath.cgPath.apply(info: &bezierPoints, function: { info, element in

                guard let resultingPoints = info?.assumingMemoryBound(to: NSMutableArray.self) else {
                    return
                }

                let points = element.pointee.points
                let type = element.pointee.type

                switch type {
                case .moveToPoint:
                    resultingPoints.pointee.add([NSNumber(value: Float(points[0].x)), NSNumber(value: Float(points[0].y))])
                    resultingPoints.pointee.add(NSString("move"))

                case .addLineToPoint:
                    resultingPoints.pointee.add([NSNumber(value: Float(points[0].x)), NSNumber(value: Float(points[0].y))])
                    resultingPoints.pointee.add(NSString("addLine"))

                case .addQuadCurveToPoint:
                    resultingPoints.pointee.add([NSNumber(value: Float(points[0].x)), NSNumber(value: Float(points[0].y))])
                    resultingPoints.pointee.add([NSNumber(value: Float(points[1].x)), NSNumber(value: Float(points[1].y))])
                    resultingPoints.pointee.add(NSString("addQuadCurve"))

                case .addCurveToPoint:
                    resultingPoints.pointee.add([NSNumber(value: Float(points[0].x)), NSNumber(value: Float(points[0].y))])
                    resultingPoints.pointee.add([NSNumber(value: Float(points[1].x)), NSNumber(value: Float(points[1].y))])
                    resultingPoints.pointee.add([NSNumber(value: Float(points[2].x)), NSNumber(value: Float(points[2].y))])
                    resultingPoints.pointee.add(NSString("addCurve"))

                case .closeSubpath:
                    break
                @unknown default:
                    break
                }
            })
        let elementsTypes : [String] = bezierPoints.compactMap { $0 as? String }
        let elementsCGFloats : [[CGFloat]] = bezierPoints.compactMap { $0 as? [CGFloat] }
        var elementsCGPoints : [CGPoint] = elementsCGFloats.map { CGPoint(x: $0[0], y: $0[1]) }
        
        var returnValue : [(type: String?, point: CGPoint?, controlPoint: CGPoint?, controlPoint1: CGPoint?, controlPoint2: CGPoint?)] = []
        for i in 0..<elementsTypes.count {
            switch elementsTypes[i] {
            case "move":
                returnValue.append((type: "move", point: elementsCGPoints.removeFirst(), controlPoint: nil, controlPoint1: nil, controlPoint2: nil))
            case "addLine":
                returnValue.append((type: "addLine", point: elementsCGPoints.removeFirst(), controlPoint: nil, controlPoint1: nil, controlPoint2: nil))
            case "addQuadCurve":
                let controlPoint = elementsCGPoints.removeFirst()
                returnValue.append((type: "addQuadCurve", point: elementsCGPoints.removeFirst(), controlPoint: controlPoint, controlPoint1: nil, controlPoint2: nil))
            case "addCurve":
                let controlPoint1 = elementsCGPoints.removeFirst()
                let controlPoint2 = elementsCGPoints.removeFirst()
                returnValue.append((type: "addCurve", point: elementsCGPoints.removeFirst(), controlPoint: nil, controlPoint1: controlPoint1, controlPoint2: controlPoint2))
            default:
                returnValue.append((type: nil, point: nil, controlPoint: nil, controlPoint1: nil, controlPoint2: nil))
            }
        }
        return returnValue
    }
    
    /// Creates and returns a new Bézier path object with an inscribed oval path in the specified rectangle, without closing the path.
    convenience init (openOvalIn rect: CGRect) {
        self.init()
        let initialOval = UIBezierPath(ovalIn: rect)
        let points = initialOval.getPathElements()
        var success = true
        for i in 0..<points.count {
            switch points[i].type {
            case "move":
                if points[i].point != nil {
                    self.move(to: points[i].point!)
                } else {
                    success = false
                    break
                }
            case "addCurve":
                if let controlPoint1 = points[i].controlPoint1,
                   let controlPoint2 = points[i].controlPoint2,
                   let point = points[i].point {
                    self.addCurve(to: point, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
                } else {
                    success = false
                    break
                }
            default:
                success = false
                break
            }
        }
        if !success {
            cgPath = initialOval.cgPath
        }
    }
    
    /// Indicates whether a manually drawn Bézier path resembles an oval. Dependent on the Clipping Bézier library.
    func resemblesOval() -> Bool {
        
        // Get the distance between the path's start and end point
        let vector = self.firstPoint().vector(to: self.lastPoint())
        let distance = sqrt(pow(vector.dx, 2) + pow(vector.dy, 2))
        if distance > 10 {
            return false
        }
        
        // Get the distances between each pair of adjacent points on the path. Return false if any of them is bigger than 20.
        let pathPoints = self.getPathPoints()
        for i in 0..<pathPoints.count-1 {
            let pathPointsVector = pathPoints[i].vector(to: pathPoints[i+1])
            let pathPointsDistance = sqrt(pow(pathPointsVector.dx, 2) + pow(pathPointsVector.dy, 2))
            if pathPointsDistance > 20 {
                return false
            }
        }
        return true
    }
    
    /// Extracts all points from a Bézier path, using the Clipping Bézier library. Does not extract control points.
    func getPathPoints() -> [CGPoint] {
        var pathPoints : [CGPoint] = []
        var counter = self.elementCount
        if self.isClosed() {
            counter -= 1 // In a closed path, the last element does not have a point
        }
        for i in 0..<counter {
            pathPoints.append(self.element(at: i).points.pointee)
        }
        return pathPoints
    }
    
    /// Creates and returns a new Bézier path object translated from an original Bézier path by a given point.
    convenience init?(originalPath path: UIBezierPath?, translatedByPoint point: CGPoint) {
        self.init()
        if let unwrappedPath = path {
            self.cgPath = unwrappedPath.cgPath
        } else {
            return nil
        }
        self.apply(CGAffineTransform(translationX: point.x, y: point.y))
    }
}

extension PDFAnnotation {
    /// Determines whether a point in the PDF page coordinate system is contained in an ink annotation's path.
    func hitTest(pdfView: PDFView, pointInPage: CGPoint) -> Bool? {
        guard self.type == "Ink" else { return nil }
        if let boundingRectOrigin = pdfView.superview?.convert(self.bounds.origin, from: pdfView) {
            if let annotationPaths = self.paths {
                if let translatedPath = UIBezierPath(originalPath: annotationPaths.first, translatedByPoint: boundingRectOrigin)?.cgPath.copy(strokingWithWidth: 10.0, lineCap: .round, lineJoin: .round, miterLimit: 0) {
                    if translatedPath.contains(pointInPage) {
                        return true
                    } else {
                        return false
                    }
                } else {
                    print ("PDFAnnotation hit test: could not get the annotation's path")
                    return nil
                }
            } else {
                print ("PDFAnnotation hit test: could not get the annotation's path")
                return nil
            }
        } else {
            print ("PDFAnnotation hit test: could not get the annotation's bounding rect on the PDF view")
            return nil
        }
    }
}
