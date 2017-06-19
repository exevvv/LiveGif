//
//  PhotoCollectionVC.swift
//  LiveGif
//
//  Created by admin on 2017/5/10.
//  Copyright © 2017年 tom. All rights reserved.
//

import UIKit
import Photos

private let reuseIdentifier = "Cell"

class PhotoCollectionVC: UIViewController {
    //UIImagePickerControllerDelegate,UINavigationControllerDelegate
    
    var livePhotoAssets: PHFetchResult<PHAsset>?
    //let imagePickerController: UIImagePickerController = UIImagePickerController()
    var is_launch = false
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var imageView: UIImageView!
    fileprivate let photoQueue = DispatchQueue(label: "com.idontknowher.PhotoMe.session-queue")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.subviews[0].alpha = 0
        self.collectionView.contentInset=UIEdgeInsetsMake(-64, 0, 0, 0);//上移64
        guard let path = Bundle.main.path(forResource: "live.gif", ofType: nil),
            let data = NSData(contentsOfFile: path),
            let imageSource = CGImageSourceCreateWithData(data, nil) else { return }
        
        var images = [UIImage]()
        var totalDuration : TimeInterval = 0
        for i in 0..<CGImageSourceGetCount(imageSource) {
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, i, nil) else { continue }
            let image = UIImage(cgImage: cgImage)
            i == 0 ? imageView.image = image : ()
            images.append(image)
            
            guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil) as? NSDictionary,
                let gifDict = properties[kCGImagePropertyGIFDictionary] as? NSDictionary,
                let frameDuration = gifDict[kCGImagePropertyGIFDelayTime] as? NSNumber else { continue }
            totalDuration += frameDuration.doubleValue
        }
        
        imageView.animationImages = images
        imageView.animationDuration = totalDuration
        imageView.animationRepeatCount = 0
        
        photoQueue.async {
            self.imageView.startAnimating()
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        PHPhotoLibrary.requestAuthorization { (status:PHAuthorizationStatus) in
            switch status {
            case .authorized:
                self.fetchPhotos()
            default:
                self.showNoPhotoAccessAlert()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if(!is_launch) {
            self.launchAnimation()
            is_launch = true
        }
    }
    
    
    func fetchPhotos() {
        let sortDesciptor = NSSortDescriptor(key: "creationDate", ascending:false)
        let options = PHFetchOptions()
        options.sortDescriptors = [sortDesciptor]
        
        var identifierArray = [String]()
        var num = 0
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let assets: PHFetchResult<PHAsset> = PHAsset.fetchAssets(with: PHAssetMediaType.image, options: nil)
            let sum = assets.count
            while num < sum {
                let asset = assets[num]
                if asset.mediaSubtypes == PHAssetMediaSubtype.photoLive {
                    identifierArray.append(asset.localIdentifier)
                }
                num += 1
            }
            self.livePhotoAssets = PHAsset.fetchAssets(withLocalIdentifiers: identifierArray, options: options)
            
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    
    
    func showNoPhotoAccessAlert() {
        let alert = UIAlertController(title: "No Photo Access Permission", message: "Please grant this App access your photos in Settings -- > Privacy", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler:{ (action: UIAlertAction) in
            let url = URL(string: UIApplicationOpenSettingsURLString)
            UIApplication.shared.open(url!, options: ["" : ""], completionHandler: nil)
            return
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    
    // MARK: UICollectionViewDataSource
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let indexPath = collectionView?.indexPathsForSelectedItems?.first {
            let photoVC = segue.destination as! LivePhotoVC
            photoVC.livePhotoAsset = livePhotoAssets?[indexPath.item]
        }
    }
    
    
    func launchAnimation() {
        let viewController = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()
        let launchView = viewController?.view
        let mainWindow = UIApplication.shared.keyWindow
        launchView?.frame = (mainWindow?.frame)!
        mainWindow?.addSubview(launchView!)
        UIView.animate(withDuration: 1.0, delay: 0.5, options: UIViewAnimationOptions.beginFromCurrentState, animations: {
            launchView?.alpha = 0.0
            launchView?.layer.transform = CATransform3DScale(CATransform3DIdentity, 2.0, 2.0, 1.0)
        }, completion: { finished in
            launchView?.removeFromSuperview()
        })
    }
}

extension PhotoCollectionVC: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let numberOfItems = livePhotoAssets?.count {
            return numberOfItems
        } else {
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PhotoCollectionViewCell
    
        if let asset = livePhotoAssets?[indexPath.row]{
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
        
            let targetSize = CGSize(width: 100, height: 100)
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options, resultHandler: { (image: UIImage?, info: [AnyHashable : Any]?) in
                cell.photoImageView.image = image
            })
        }
    
        return cell
    }
}

