//
//  LivePhotoVC.swift
//  LiveGif
//
//  Created by admin on 2017/5/10.
//  Copyright © 2017年 tom. All rights reserved.
//

import UIKit
import Photos
import PhotosUI
import MobileCoreServices

fileprivate let CellIdentifier = "FilterCell"

class LivePhotoVC: UIViewController {
    
    var livePhotoAsset: PHAsset?
    var photoView: PHLivePhotoView!
    var gifView: UIImageView!
    var gifURL: URL?
    @IBOutlet weak var exportShareButton: UIButton!
    @IBOutlet weak var gifSizeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var collectionView: UICollectionView!
    var filter:[String] = ["Original","CIPhotoEffectInstant","CIPhotoEffectNoir","CIPhotoEffectTonal","CIPhotoEffectTransfer","CIPhotoEffectMono","CIPhotoEffectFade","CIPhotoEffectProcess","CIPhotoEffectChrome","BeautifulAndRich","CIComicEffect","CIPixellate","CICrystallize","CIHighlightShadowAdjust"]
    var filterLabel:[String] = ["原始","怀旧","黑白","色调","岁月","单色","褪色","冲印","铬黄","美图","漫画","马赛克","水晶","明亮"]
    var cellImage: UIImage?
    fileprivate let photoQueue = DispatchQueue(label: "com.idontknowher.PhotoMe.session-queue")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        gifSizeSegmentedControl.selectedSegmentIndex = 1
        
        photoView = PHLivePhotoView(frame: CGRect.init(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.width))
        photoView.contentMode = .scaleAspectFit
        //photoView.layer.masksToBounds = true
        //photoView.layer.cornerRadius = 10
        
        self.view.addSubview(photoView)
        
        gifView = UIImageView(frame: CGRect.init(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.width))
        gifView.contentMode = .scaleAspectFit
    }
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.photoView.center = self.view.center
        self.gifView.center = self.view.center
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureView()
    }
    
    fileprivate func configureView_cell() {
        photoQueue.async {
            if let asset = self.livePhotoAsset {
                let targetSize = CGSize(width: 160, height: 160)
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: nil, resultHandler: { (image: UIImage?, info: [AnyHashable : Any]?) in
                    self.cellImage = image
                })
                self.collectionView.reloadData()
            }
        }
    }
    
    fileprivate func configureView() {
        photoQueue.async {
            if let asset = self.livePhotoAsset {
                let targetSize = CGSize(width: 160, height: 160)
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: nil, resultHandler: { (image: UIImage?, info: [AnyHashable : Any]?) in
                    self.cellImage = image
                })
                self.collectionView.reloadData()
            }
        }
        if let photoAsset = self.livePhotoAsset {
            PHImageManager.default().requestLivePhoto(for: photoAsset, targetSize: self.photoView.frame.size, contentMode: .aspectFit, options: nil, resultHandler: { (photo: PHLivePhoto?, info: [AnyHashable : Any]?) in
            
                if let livePhoto = photo{
                    self.photoView.livePhoto = livePhoto
                    self.photoView.startPlayback(with: .full)
                    
                    let geoCoder = CLGeocoder()
                    if let location = photoAsset.location {
                        geoCoder.reverseGeocodeLocation(location, completionHandler: { (placemark: [CLPlacemark]?, error: Error?) in
                            if error == nil {
                                self.navigationItem.title = placemark?.first?.locality
                            }
                        })
                    }
                }
            })
        }
    }
    
    
    @IBAction func segmentedControlClicked(_ sender: UISegmentedControl) {
        exportShareButton.setTitle("Export GIF", for: .normal)
    }
    
    
    
    @IBAction func exportShareButton(_ sender: UIButton) {
        if exportShareButton.titleLabel?.text == "Export GIF" {
            
            let resources = PHAssetResource.assetResources(for: livePhotoAsset!)
            var find_resource = false
            for resource in resources {
                if resource.type == .fullSizePairedVideo {
                    self.getMovieData(resource)
                    find_resource = true
                    break
                }
            }
            if !find_resource {
                for resource in resources {
                    if resource.type == .pairedVideo {
                        self.getMovieData(resource)
                        break
                    }
                }
            }
        }
        else {
            let activityVC = UIActivityViewController(activityItems: [gifURL!], applicationActivities: nil)
            activityVC.popoverPresentationController?.sourceView = self.view
            self.present(activityVC, animated: true, completion: nil)
        }
    }
    
    
    func getMovieData(_ resource: PHAssetResource){
        
        let movieURL = URL(fileURLWithPath: (NSTemporaryDirectory()).appending("video.mov"))
        removeFileIfExists(fileURL: movieURL)
        
        
        PHAssetResourceManager.default().writeData(for: resource, toFile: movieURL as URL, options: nil) { (error) in
            if error != nil{
                print("Could not write video file")
            } else {
                self.convertToGIF(movieURL)
            }
        }
    }
    
    
    func convertToGIF(_ movieURL: URL){
        
        let movieAsset = AVURLAsset(url: movieURL as URL)
        
        // collect the needed parameters
        let duration = CMTimeGetSeconds(movieAsset.duration)
        let track = movieAsset.tracks(withMediaType: AVMediaTypeVideo).first!
        let frameRate = track.nominalFrameRate
        
        gifURL = URL(fileURLWithPath: (NSTemporaryDirectory()).appending("file.gif"))
        removeFileIfExists(fileURL: gifURL!)
        
        var width  = 0
        
        switch gifSizeSegmentedControl.selectedSegmentIndex {
        case 0:
            width =  240
        case 1:
            width =  480
        case 2:
            width =  640
        default:
            width = 0
        }
        
        
        Regift.createGIFFromSource(movieURL as URL, destinationFileURL: gifURL, startTime: 0.0, duration: Float(duration), frameRate: Int(frameRate), loopCount: 0, width: width, height: width) {_ in
            
            exportShareButton.setTitle("Share", for: .normal)
            self.gifView.loadGif(url: gifURL!)
            self.photoView.removeFromSuperview()
            self.view.addSubview(gifView)
        }
        
    }
    
    
    
    func removeFileIfExists(fileURL : URL) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                try fileManager.removeItem(at: fileURL)
            }
            catch {
                print("Could not delete exist file so cannot write to it")
            }
        }
    }
    
    //给live photo添加滤镜
    fileprivate func editImage(_ filter:String) {
        guard let asset = livePhotoAsset else { return }
        let options = PHContentEditingInputRequestOptions.init()
        options.canHandleAdjustmentData = { _ in return true }
        //从相册载入 asset 数据准备编辑
        asset.requestContentEditingInput(with: options) {
            [unowned self] (input, info) in
            guard let input = input else {
                print("error: \(info)")
                return
            }
            //检查 photo 是否为 live photo
            guard input.mediaType == .image,
                input.mediaSubtypes.contains(.photoLive) else {
                    print("This isn't a live photo")
                    return
            }
            //创建一个编辑用的 context，然后设置一个逐帧处理的闭包
            let editingContext = PHLivePhotoEditingContext(livePhotoEditingInput: input)
            editingContext?.frameProcessor = {
                (frame, error) in
                //为每一帧都应用相同的 CIFilter
                var image = frame.image
                if let format = input.adjustmentData?.formatIdentifier {
                    let filters = (format.components(separatedBy: "+"))
                    for filter in filters {
                        if filter == "BeautifulAndRich" {
                            let filters = image.autoAdjustmentFilters(options: [kCIImageAutoAdjustRedEye : false])
                            for filter in filters {
                                filter.setValue(image, forKey: kCIInputImageKey)
                                image = filter.outputImage!
                            }
                        }
                        else {
                            image = image.applyingFilter(filter, withInputParameters: .none)
                        }
                    }
                }
                if filter == "BeautifulAndRich" {
                    let filters = image.autoAdjustmentFilters(options: [kCIImageAutoAdjustRedEye : false])
                    for filter in filters {
                        filter.setValue(image, forKey: kCIInputImageKey)
                        image = filter.outputImage!
                    }
                }
                else {
                    image = image.applyingFilter(filter, withInputParameters: .none)
                }
                return image
            }
            
            //处理生成最终的 live photo
            editingContext?.prepareLivePhotoForPlayback(
                withTargetSize: self.photoView.bounds.size,
                options: .none) { (livePhoto, error) in
                    guard let livePhoto = livePhoto else {
                        print("Preparation error: \(error)")
                        return
                    }
                    self.photoView.livePhoto = livePhoto
                    
                    //等待预览渲染出来后,编辑原始的 live photo 并存储
                    //PHContentEditingOutput 作为容器存放了要编辑的内容
                    let output = PHContentEditingOutput(contentEditingInput: input)
                    //你必须设置它，否则照片无法保存，这步能让你稍后撤销编辑
                    var format = input.adjustmentData?.formatIdentifier
                    if format == nil {
                        format = ""
                    }
                    else {
                        format?.append("+")
                    }
                    output.adjustmentData = PHAdjustmentData(
                        formatIdentifier: format! + filter,
                        formatVersion: "1.0",
                        data: filter.data(using: .utf8)!)
                    //重新运行 context 的帧处理器，不过这次是全尺寸，无损质量的的转变
                    editingContext?.saveLivePhoto(to: output, options: nil) {
                        success, error in
                        if !success {
                            print("Rendering error \(error)")
                            return
                        }
                        //一旦渲染完成，采用在相册库的 changes block 中创建 requests 的方式存储
                        PHPhotoLibrary.shared().performChanges({
                            let request = PHAssetChangeRequest(for: asset)
                            request.contentEditingOutput = output
                        }, completionHandler: { (success, error) in
                            print("Saved \(success), error \(error)")
                            self.configureView_cell()
                        })
                    }
            }
        }
    }
}

extension LivePhotoVC: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1;
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filter.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CellIdentifier, for: indexPath) as! FilterCollectionViewCell
        
        cell.type = filter[indexPath.row]
        cell.label.text = filterLabel[indexPath.row]
        cell.label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        
        if let cellImage = cellImage {
            if self.filter[indexPath.row] == "Original" {
                cell.imageView.image = cellImage
            }
            else if self.filter[indexPath.row] == "BeautifulAndRich" {
                var ciImage = CIImage(image: cellImage)
                let filters = ciImage?.autoAdjustmentFilters(options: [kCIImageAutoAdjustRedEye : false])
                for filter in filters! {
                    filter.setValue(ciImage, forKey: kCIInputImageKey)
                    ciImage = filter.outputImage
                }
                cell.imageView.image = UIImage(ciImage: ciImage!)
            }
            else{
                let ciImage = CIImage(image: cellImage)
                let editedImage = ciImage?.applyingFilter(self.filter[indexPath.row],
                                                          withInputParameters: .none)
                cell.imageView.image = UIImage(ciImage: editedImage!)
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if filter[indexPath.row] == "Original" {
            return
        }
        editImage((collectionView.cellForItem(at: indexPath) as! FilterCollectionViewCell).type!)
    }
}
