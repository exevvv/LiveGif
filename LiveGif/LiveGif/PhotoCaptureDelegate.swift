//
//  PhotoCaptureDelegate.swift
//  LiveGif
//
//  Created by admin on 2017/5/10.
//  Copyright © 2017年 tom. All rights reserved.
//

import AVFoundation
import Photos


class PhotoCaptureDelegate: NSObject {
    //提供闭包在照相过程中的关键节点执行
    var photoCaptureBegins: (() -> ())? = .none
    var photoCaptured: (() -> ())? = .none
    fileprivate let completionHandler: (PhotoCaptureDelegate, PHAsset?) -> ()
    var thumbnailCaptured: ((UIImage?) -> ())? = .none
    var capturingLivePhoto: ((Bool) -> ())? = .none
    
    //用于存储来自输出的数据
    fileprivate var photoData: Data? = .none
    fileprivate var livePhotoMovieURL: URL? = .none
    
    //确保完成 completion 被设置，其他闭包都是可选的
    init(completionHandler: @escaping (PhotoCaptureDelegate, PHAsset?) -> ()) {
        self.completionHandler = completionHandler
    }
    
    //一旦所有都完成，调用 completion 闭包
    fileprivate func cleanup(asset: PHAsset? = .none) {
        completionHandler(self, asset)
    }
}

extension PhotoCaptureDelegate: AVCapturePhotoCaptureDelegate {
    //Process data completed
    func capture(_ captureOutput: AVCapturePhotoOutput,didFinishProcessingPhotoSampleBuffer
        photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?,resolvedSettings: AVCaptureResolvedPhotoSettings,
                                            bracketSettings: AVCaptureBracketedStillImageSettings?,error: Error?) {
        
        guard let photoSampleBuffer = photoSampleBuffer else {
            print("Error capturing photo \(error)")
            return
        }
        photoData = AVCapturePhotoOutput
            .jpegPhotoDataRepresentation(
                forJPEGSampleBuffer: photoSampleBuffer,
                previewPhotoSampleBuffer: previewPhotoSampleBuffer)
        
        //制作缩略图
        if let thumbnailCaptured = thumbnailCaptured,
            let previewPhotoSampleBuffer = previewPhotoSampleBuffer,
            let cvImageBuffer =
            CMSampleBufferGetImageBuffer(previewPhotoSampleBuffer) {
            let ciThumbnail = CIImage(cvImageBuffer: cvImageBuffer)
            let context = CIContext(options: [kCIContextUseSoftwareRenderer:
                false])
            let thumbnail = UIImage(cgImage: context.createCGImage(ciThumbnail,
                                                                   from: ciThumbnail.extent)!, scale: 2.0, orientation: .right)
            thumbnailCaptured(thumbnail)
        }
    }
    
    // Entire process completed
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishCaptureForResolvedSettings
        resolvedSettings: AVCaptureResolvedPhotoSettings,
                 error: Error?) {
        //检查以确保一切都如预期
        guard error == nil, let photoData = photoData else {
            print("Error \(error) or no data")
            cleanup()
            return
        }
        //申请访问相册的权限，PHAsset用来表示相册中的相片和影片
        PHPhotoLibrary.requestAuthorization {
            [unowned self]
            (status) in
            //鉴权失败的话，执行 completion 闭包
            guard status == .authorized  else {
                print("Need authorisation to write to the photo library")
                self.cleanup()
                return
            }
            //保存照片到相册，并获取 PHAsset
            var assetIdentifier: String?
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                let placeholder = creationRequest
                    .placeholderForCreatedAsset
                creationRequest.addResource(with: .photo,
                                            data: photoData, options: .none)
                //向相册里添加 live photo，shouldMoveFile 设为 true 表示将会自动移除临时存放视频目录。
                if let livePhotoMovieURL = self.livePhotoMovieURL {
                    let movieResourceOptions = PHAssetResourceCreationOptions()
                    movieResourceOptions.shouldMoveFile = true
                    creationRequest.addResource(with: .pairedVideo,
                                                fileURL: livePhotoMovieURL,
                                                options: movieResourceOptions)
                }
                assetIdentifier = placeholder?.localIdentifier
            }, completionHandler: { (success, error) in
                if let error = error {
                    print("Error saving to the photo library: \(error)")
                }
                var asset: PHAsset? = .none
                if let assetIdentifier = assetIdentifier {
                    asset = PHAsset.fetchAssets(
                        withLocalIdentifiers: [assetIdentifier],
                        options: .none).firstObject
                }
                self.cleanup(asset: asset)
            })
        }
    }
    
    //prepare to capture
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 willCapturePhotoForResolvedSettings
        resolvedSettings: AVCaptureResolvedPhotoSettings) {
        photoCaptureBegins?()
        //开始拍摄时开启live photo功能
        if resolvedSettings.livePhotoMovieDimensions.width > 0
            && resolvedSettings.livePhotoMovieDimensions.height > 0 {
            capturingLivePhoto?(true)
        }
    }
    //finish capturing
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didCapturePhotoForResolvedSettings
        resolvedSettings: AVCaptureResolvedPhotoSettings) {
        photoCaptured?()
    }
    
    //拍摄结束时关闭live photo功能
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishRecordingLivePhotoMovieForEventualFileAt
        outputFileURL: URL,
                 resolvedSettings: AVCaptureResolvedPhotoSettings) {
        capturingLivePhoto?(false)
    }
    
    //处理视频结束
    func capture(_ captureOutput: AVCapturePhotoOutput,
                 didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
                 duration: CMTime,
                 photoDisplay photoDisplayTime: CMTime,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 error: Error?) {
        if let error = error {
            print("Error creating live photo video: \(error)")
            return
        }
        livePhotoMovieURL = outputFileURL
    }
}

