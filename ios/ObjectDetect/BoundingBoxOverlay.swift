//
//  BoundingBoxOverlay.swift
//  ObjectDetectAI
//
//  Created by Jack Serrino on 3/21/18.
//

import UIKit

class BoundingBoxOverlay: UIView {
    var boxes:[Any] = [];
    
    override var clearsContextBeforeDrawing: Bool {
        get {
            return true
        }
        set {
            
        }
    };
    override var isOpaque: Bool {
        get {
            return false
        }
        set {
            // you can leave this empty...
        }
    }
    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
        let context = UIGraphicsGetCurrentContext()
        for box in (self.boxes as! [NSDictionary]) {
            let top: Int = (box.object(forKey: "top") as! Int)*3/4 + 170 // Translate so overlay is better - optimized for iphone X
            let left: Int = (box.object(forKey: "left") as! Int)*3/4 - 30
            let bottom: Int = (box.object(forKey: "bottom") as! Int)*3/4 + 170
            let right: Int = (box.object(forKey: "right") as! Int)*3/4 - 30
            let class_name: String = box.object(forKey: "class_name") as! String
            let score: Float32 = box.object(forKey: "score") as! Float32
            
            var color: UIColor = UIColor.blue
            if score > 0.95 {
                color = UIColor.green
            } else if score > 0.85 {
                color = UIColor.cyan
            }
            
            let textFont = UIFont(name: "Helvetica", size: 36)!
            let textFontAttributes = [
                NSFontAttributeName: textFont,
                NSForegroundColorAttributeName: color,
            ] as [String : Any]
            
            context?.setLineWidth(3.0)
            context?.setStrokeColor(color.cgColor)
            let rectangle = CGRect(x: left, y: top, width: (right-left), height: (bottom-top))
            context?.addRect(rectangle)
            context?.strokePath()
            
            class_name.draw(in: rectangle, withAttributes: textFontAttributes)
        }
    }
    
    func assignBoxes(_ newBoxes:[Any]) {
        self.boxes = newBoxes;
    }

}
