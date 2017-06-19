//
//  CameraViewController.swift
//  LiveGif
//
//  Created by admin on 2017/5/10.
//  Copyright © 2017年 tom. All rights reserved.
//

import UIKit
import Photos
import AVFoundation

class CameraViewController: UIViewController {
    
    @IBOutlet weak var cameraPreviewView: CameraPreviewView!
    @IBOutlet weak var shutterButton: UIButton!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var livePhotoSwitch: UISwitch!
    @IBOutlet weak var capturingLabel: UILabel!
    @IBOutlet weak var editButton: UIButton!
    
    fileprivate let session = AVCaptureSession()
    fileprivate let sessionQueue = DispatchQueue(label: "com.idontknowher.PhotoMe.session-queue")
    fileprivate let photoOutput = AVCapturePhotoOutput()
    var videoDeviceInput: AVCaptureDeviceInput!
    fileprivate var photoCaptureDelegates = [Int64 : PhotoCaptureDelegate]()
    fileprivate var lastAsset: PHAsset?
    
    //记录拍摄状态：1表示拍摄中，0表示未拍摄
    fileprivate var currentLivePhotoCaptures: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        previewImageView.layer.masksToBounds = true
        previewImageView.layer.cornerRadius = 10
        
        //将 session 传递给 view
        cameraPreviewView.session = session
        //暂停 session 队列
        sessionQueue.suspend()
        //请求麦克风和摄像头的权限
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) { success in
            if !success {
                print("Come on, it's a camera app!")
                return
            }
            //请求通过，重新开启 queue
            self.sessionQueue.resume()
        }
        
        sessionQueue.async {
            [unowned self] in
            self.prepareCaptureSession()
        }
        
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async {
            self.session.startRunning()
        }
        //self.navigationController?.isNavigationBarHidden = false;
        configureView()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func configureView() {
            if let asset = self.lastAsset {
                let targetSize = CGSize(width: 160, height: 160)
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: nil, resultHandler: { (image: UIImage?, info: [AnyHashable : Any]?) in
                    self.previewImageView.image = image
                })
            }
    }
    
    private func prepareCaptureSession() {
        // 告诉 session 将要添加的一系列配置操作
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSessionPresetPhoto
        do {
            // 创建一个前置摄像头设备
            let videoDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back)
            //创建一个设备输入表示设备能捕获的数据
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            //添加输入到 session 中，并作为属性（先前定义的）存储起来
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                //返回主线程，只处理垂直方向的情形
                DispatchQueue.main.async {
                    self.cameraPreviewView.cameraPreviewLayer.connection.videoOrientation = .portrait
                }
            } else {
                print("Couldn't add device to the session")
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            return
        }
        
        //音频设备及输入
        do {
            let audioDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                print("Couldn't add audio device to the session")
                return
            }
        } catch {
            print("Unable to create audio device input: \(error)")
            return
        }
        
        //输出属性配置
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
            DispatchQueue.main.async {
                self.livePhotoSwitch.isEnabled = self.photoOutput.isLivePhotoCaptureSupported
            }
        } else {
            print("Unable to add photo output")
            return
        }
        //一切顺利，确认所以更改
        session.commitConfiguration()
    }
    
    @IBAction func handleShutterButtonTap(_ sender: Any) {
        capturePhoto()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let editor = segue.destination as? PhotoEditingViewController {
            editor.asset = lastAsset
        }
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}

extension CameraViewController {
    fileprivate func capturePhoto() {
        //output 对象需要知道相机的方向
        let cameraPreviewLayerOrientation = cameraPreviewView.cameraPreviewLayer.connection.videoOrientation
        //所有的工作都在特定的队列中异步完成， connection 表示一条媒体流
        // 这条媒体流来自于 inputs 通过 session 直到 output
        sessionQueue.async {
            if let connection = self.photoOutput.connection(withMediaType: AVMediaTypeVideo) {
                connection.videoOrientation = cameraPreviewLayerOrientation
            }
            //JPEG 拍摄
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.flashMode = .off
            photoSettings.isHighResolutionPhotoEnabled = true
            
            if photoSettings.availablePreviewPhotoPixelFormatTypes.count > 0 {
                photoSettings.previewPhotoFormat = [
                    kCVPixelBufferPixelFormatTypeKey as String : photoSettings.availablePreviewPhotoPixelFormatTypes.first!,
                    kCVPixelBufferWidthKey as String : 160,
                    kCVPixelBufferHeightKey as String : 160
                ]
            }
            
            if self.livePhotoSwitch.isOn {
                let movieFileName = UUID().uuidString
                let moviePath = (NSTemporaryDirectory() as NSString)
                    .appendingPathComponent("\(movieFileName).mov")
                photoSettings.livePhotoMovieFileURL = URL(
                    fileURLWithPath: moviePath)
            }
            
            //每个 AVCapturePhotoSettings 实例创建时都会被自动分配一个 ID 标识
            let uniqueID = photoSettings.uniqueID
            //初始化一个 PhotoCaptureDelegate 对象，传入一个 completion 闭包
            let photoCaptureDelegate = PhotoCaptureDelegate() { [unowned self] (photoCaptureDelegate, asset) in
                self.sessionQueue.async { [unowned self] in
                    self.photoCaptureDelegates[uniqueID] = .none
                    self.lastAsset = asset
                }
            }
            //将 delegate 存入字典中
            self.photoCaptureDelegates[uniqueID] = photoCaptureDelegate
            //开始拍照，并把 setting 和 delegate 传进去
            self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureDelegate)
            
            photoCaptureDelegate.photoCaptureBegins = { [unowned self] in
                DispatchQueue.main.async {
                    self.shutterButton.isEnabled = false
                    self.editButton.isHidden = true
                    self.cameraPreviewView.cameraPreviewLayer.opacity = 0
                    UIView.animate(withDuration: 0.2) {
                        self.cameraPreviewView.cameraPreviewLayer.opacity = 1
                    }
                }
            }
            
            photoCaptureDelegate.photoCaptured = { [unowned self] in
                DispatchQueue.main.async {
                    self.shutterButton.isEnabled = true
                }
            }
            
            photoCaptureDelegate.thumbnailCaptured = { [unowned self] image in
                DispatchQueue.main.async {
                    self.previewImageView.image = image
                }
            }
            
            // Live photo UI updates
            photoCaptureDelegate.capturingLivePhoto = { (currentlyCapturing) in
                DispatchQueue.main.async { [unowned self] in
                    self.currentLivePhotoCaptures += currentlyCapturing ? 1 : -1
                    UIView.animate(withDuration: 0.2) {
                        self.capturingLabel.isHidden = self.currentLivePhotoCaptures == 0
                        self.editButton.isHidden = self.currentLivePhotoCaptures == 1
                    }
                }
            }
        }
    }
}

