//
//  UploadPhotoViewController.swift
//  PicShare
//
//  Created by Logan Chang on 11/29/15.
//  Copyright © 2015 USC. All rights reserved.
//

import UIKit
import Parse

class UploadPhotoViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var descriptionTextField: UITextField!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    var image: UIImage?
    let locationManager = CLLocationManager()
    var didRequestLocation = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        imageView.contentMode = .ScaleAspectFit
        imageView.image = image
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: "resignKeyboard")
        gestureRecognizer.delegate = self
        view.addGestureRecognizer(gestureRecognizer)
    }

    // MARK: - User Actions
    
    @IBAction func backButtonPressed(sender: AnyObject) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    @IBAction func uploadToEvent(sender: AnyObject) {
        // TODO: Upload to Event
    }
    
    @IBAction func uploadToLocation(sender: AnyObject) {
        let status = CLLocationManager.authorizationStatus()
        if status == .Denied || status == .Restricted {
            showAlert("Location Services Disabled", message: "Please go to your device settings to enable location services.")
        } else if status == .NotDetermined {
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
            didRequestLocation = true
        } else {
            PFGeoPoint.geoPointForCurrentLocationInBackground { [weak self](geoPoint, error) -> Void in
                if let geoPoint = geoPoint where error == nil {
                    self?.uploadPhotoWithGeoPoint(geoPoint)
                } else {
                    print("Error getting location")
                }
            }
        }
    }
    
    
    // MARK: - Private
    
    private func uploadPhotoWithGeoPoint(geoPoint: PFGeoPoint) {
        if let image = image,
            fullImage = image.scaleAndRotateImage(960), // Magic number
            thumbImage = image.scaleAndRotateImage(480), // Magic number
            fullImageData = UIImagePNGRepresentation(fullImage),
            thumbImageData = UIImagePNGRepresentation(thumbImage),
            imageFile = PFFile(name: "image.png", data: fullImageData),
            thumbFile = PFFile(name: "thumbnail.png", data: thumbImageData),
            user = PFUser.currentUser()
        {
            var text = ""
            if let descritpiveText = descriptionTextField.text {
                text = descritpiveText
            }
            
            activityIndicatorView.startAnimating()
            imageFile.saveInBackgroundWithBlock({ [weak self](success, error) -> Void in
                if success {
                    thumbFile.saveInBackgroundWithBlock({ [weak self](success, error) -> Void in
                        if success {
                            self?.proceedToUploadPhoto(imageFile, thumbFile: thumbFile, user: user, geoPoint: geoPoint, text: text)
                        } else {
                            // TODO: SHOW ERROR MESSAGE
                        }
                    }, progressBlock: { (progress) -> Void in
                        print("thumbnail progress: \(progress)%")
                    })
                } else {
                    // TODO: SHOW ERROR MESSAGE
                }
            }, progressBlock: { (progress) -> Void in
                print("image progress: \(progress)%")
            })
        } else {
            print("Photo saving error")
        }
    }
    
    // MARK: - Helpers
    
    func proceedToUploadPhoto(imageFile: PFFile, thumbFile: PFFile, user: PFUser, geoPoint: PFGeoPoint, text: String) {
        let photo = Photo(image: imageFile,
            thumbnail: thumbFile,
            owner: user,
            event: nil, location: geoPoint, descriptiveText: text)
        
        photo.saveInBackgroundWithBlock({ [weak self](success, error) -> Void in
            self?.activityIndicatorView.stopAnimating()
            self?.dismissViewControllerAnimated(true, completion: nil)
        })
    }
    
    func resignKeyboard() {
        descriptionTextField.resignFirstResponder()
    }

    func showAlert(title: String, message: String) {
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
        alertView.addAction(okAction)
        presentViewController(alertView, animated: true, completion: nil)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension UploadPhotoViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        return !(touch.view is UIControl)
    }
    
}

extension UploadPhotoViewController: CLLocationManagerDelegate {
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        if status == .AuthorizedWhenInUse || status == .AuthorizedAlways {
            manager.startUpdatingLocation()
            if didRequestLocation {
                uploadToLocation(UIButton())
            }
        }
    }
}