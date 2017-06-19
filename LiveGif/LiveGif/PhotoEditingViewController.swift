//
//  PhotoEditingViewController.swift
//  LiveGif
//
//  Created by admin on 2017/5/10.
//  Copyright © 2017年 tom. All rights reserved.
//

import UIKit
import Photos
import PhotosUI

fileprivate let CellIdentifier = "FilterCell"

class PhotoEditingViewController: UIViewController {
    
    @IBOutlet weak var livePhotoView: PHLivePhotoView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var asset: PHAsset?
    var filter:[String] = ["Original","CIPhotoEffectInstant","CIPhotoEffectNoir","CIPhotoEffectTonal","CIPhotoEffectTransfer","CIPhotoEffectMono","CIPhotoEffectFade","CIPhotoEffectProcess","CIPhotoEffectChrome","BeautifulAndRich","CIComicEffect","CIPixellate","CICrystallize","CIHighlightShadowAdjust"]
    var filterLabel:[String] = ["原始","怀旧","黑白","色调","岁月","单色","褪色","冲印","铬黄","美图","漫画","马赛克","水晶","明亮"]
    var cellImage: UIImage?
    fileprivate let photoQueue = DispatchQueue(label: "com.idontknowher.PhotoMe.session-queue")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureView()
    }
    
    fileprivate func configureView_cell() {
        photoQueue.async {
            if let asset = self.asset {
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
            if let asset = self.asset {
                let targetSize = CGSize(width: 160, height: 160)
                PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: nil, resultHandler: { (image: UIImage?, info: [AnyHashable : Any]?) in
                    self.cellImage = image
                })
                self.collectionView.reloadData()
            }
        }
        if let asset = self.asset {
            PHImageManager.default().requestLivePhoto(for: asset, targetSize: self.livePhotoView.bounds.size, contentMode: .aspectFill, options: .none, resultHandler: {
                (livePhoto, info) in
                DispatchQueue.main.async {
                    self.livePhotoView.livePhoto = livePhoto
                }
            })
        }
    }
    
    @IBAction func handleDoneTapped(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    //给live photo添加滤镜
    fileprivate func editImage(_ filter:String) {
        guard let asset = asset else { return }
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
                        else{
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
                withTargetSize: self.livePhotoView.bounds.size,
                options: .none) { (livePhoto, error) in
                    guard let livePhoto = livePhoto else {
                        print("Preparation error: \(error)")
                        return
                    }
                    self.livePhotoView.livePhoto = livePhoto
                    
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
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}

extension PhotoEditingViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
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

