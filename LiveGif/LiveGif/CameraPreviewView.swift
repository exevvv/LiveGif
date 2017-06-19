//
//  CameraPreviewView.swift
//  LiveGif
//
//  Created by admin on 2017/5/10.
//  Copyright © 2017年 tom. All rights reserved.
//

import UIKit
import AVFoundation

class CameraPreviewView: UIView {
    
    //指定CALayer 的子类(AVCaptureVideoPreviewLayer)作为 main layer
    override static var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self;
    }
    
    //计算属性
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    //需要一个 AVCaptureSession 来显示来自摄像头的输入
    var session: AVCaptureSession? {
        get {
            return cameraPreviewLayer.session
        }
        set {
            cameraPreviewLayer.session = newValue
        }
    }
    
}
