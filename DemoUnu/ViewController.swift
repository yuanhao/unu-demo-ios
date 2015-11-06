//
//  ViewController.swift
//  DemoUnu
//
//  Created by Yuanhao Li on 05/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//

import UIKit
import MapKit
import Contacts

class ViewController: UIViewController, MKMapViewDelegate, UITextFieldDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var chatButton: UIButton!
    @IBOutlet weak var chatTextField: UITextField!
    @IBOutlet weak var messageView: UITextView!
    let serverUrl = "46.101.187.63:3000"
    
    let locationManager: CLLocationManager = CLLocationManager()
    let locationManagerDelegate: LocationManagerDelegate = LocationManagerDelegate()
    var routeDetails: MKRoute?
    var storeList: [Store] = [Store]()
    var storeTableManager: StoreTableManager!
    var socket: SocketIOClient!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.setupUI()
        self.mapView.delegate = self
        self.mapView.showsTraffic = true
        self.mapView.showsUserLocation = true
        self.mapView.showsPointsOfInterest = true
        self.setupLocationManager()
        self.loadStores()
        self.storeTableManager = StoreTableManager(controller: self)
        
        self.setupSocketIo()
        self.setTextViewKeyboardNotifications()
    }
    
    func setupUI() {
        self.chatButton.layer.cornerRadius = 5.0
        self.messageView.backgroundColor = UIColor.clearColor()
        self.messageView.text = ""
        self.messageView.attributedText = NSAttributedString(string: "")
        self.messageView.editable = false
        self.chatTextField.delegate = self
    }
    
    func setupSocketIo() {
        self.socket = SocketIOClient(socketURL: self.serverUrl, options: [.Log(true), .ForcePolling(true)])

        self.socket.on("connect") { data, ack in
            self.messageView.text = "Connected."
            self.messageView.textColor = UIColor.darkGrayColor()
        }

        self.socket.on("chat message") { data, ack in
            let message = data[0] as! String
            let oldAttributedString = self.messageView.attributedText.mutableCopy() as! NSMutableAttributedString
            let msgAttributedString = NSAttributedString(string: message, attributes: [
                NSForegroundColorAttributeName: UIColor.whiteColor(),
                NSBackgroundColorAttributeName: UIColor.blackColor().colorWithAlphaComponent(0.5),
                NSFontAttributeName: self.messageView.font!.fontWithSize(17.0),
                ])
            
            oldAttributedString.appendAttributedString(NSAttributedString(string: "\n\n"))
            oldAttributedString.appendAttributedString(msgAttributedString)
            
            self.messageView.editable = true
            self.messageView.attributedText = oldAttributedString
            self.messageView.editable = false

            // scroll to bottom
            self.messageView.scrollRangeToVisible(NSRange(location: self.messageView.text.utf16.count, length: 0))
        }

        socket.connect()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func setupLocationManager() {
        self.locationManagerDelegate.viewController = self
        self.locationManager.delegate = self.locationManagerDelegate
        
        let authorizationStatus: CLAuthorizationStatus = CLLocationManager.authorizationStatus()
        if authorizationStatus == CLAuthorizationStatus.NotDetermined && CLLocationManager.locationServicesEnabled() {
            self.locationManager.requestWhenInUseAuthorization()
        }
        
        self.locationManager.startUpdatingLocation()
        if let location = self.locationManager.location {
            let coordinateRegion = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(
                    latitudeDelta: CLLocationDegrees(0.025),
                    longitudeDelta: CLLocationDegrees(0.025)))
            self.mapView.setRegion(coordinateRegion, animated: true)
        }
        
        // Debug
        /*
        let regionRadius: CLLocationDistance = 1000
        let coordinateRegionx = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2D(latitude: 52.5167, longitude: 13.3833),
            regionRadius * 2.0, regionRadius * 2.0)
        self.mapView.setRegion(coordinateRegionx, animated: true)
        */
    }
    
    func loadStores() {
        
        let storesUrl = "http://\(self.serverUrl)/stores"
        guard let url = NSURL(string: storesUrl) else {
            print("Error")
            return
        }
        let urlRequest = NSURLRequest(URL: url)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(urlRequest, completionHandler: { (data, response, error) in

            guard let responseData = data else {
                print("Error: did not receive data")
                return
            }
            guard error == nil else {
                print("error calling")
                print(error)
                return
            }
            
            let storeList: NSDictionary
            do {
                storeList = try NSJSONSerialization.JSONObjectWithData(responseData, options: []) as! NSDictionary
            } catch  {
                print("error trying to convert data to JSON")
                return
            }
            
            self.storeList = [Store]()

            for (k, v) in storeList["storeList"] as! NSDictionary {
                let storeName = k as! String
                let storeLocation = v as! NSDictionary
                guard let storeLatDouble = Double(storeLocation["lat"] as! String) else {
                    print("\(storeLocation["lat"]) is not a number")
                    continue
                }
                guard let storeLonDouble = Double(storeLocation["lon"] as! String) else {
                    print("\(storeLocation["lat"]) is not a number")
                    continue
                }
                let store = Store(title: storeName, coordinate: CLLocationCoordinate2D(latitude: storeLatDouble, longitude: storeLonDouble))
                self.mapView.addAnnotation(store)

                self.storeList.append(store)
            }
            
        })
        task.resume()
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? Store {
            var view: MKPinAnnotationView
            if let storeView = mapView.dequeueReusableAnnotationViewWithIdentifier("store") as? MKPinAnnotationView {
                storeView.annotation = annotation
                view = storeView
            } else {
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "store")
                view.canShowCallout = true
                view.calloutOffset = CGPoint(x: -5, y: -5)
                view.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure) as UIView
            }
            return view
        }
        return nil
    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {

        let storeLocation = view.annotation as! Store
        let request = MKDirectionsRequest()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: self.locationManager.location!.coordinate, addressDictionary: nil))
        request.destination = storeLocation.mapItem()
        request.transportType = MKDirectionsTransportType.Automobile
        let directions = MKDirections(request: request)
        directions.calculateETAWithCompletionHandler { response, error -> Void in
            if let err = error {
                let errorAlert = UIAlertController(title: "Direction ETA Failed", message: err.userInfo["NSLocalizedFailureReason"] as? String, preferredStyle: UIAlertControllerStyle.Alert)
                let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: {
                    (alert: UIAlertAction) in
                })
                errorAlert.addAction(okAction)
                self.presentViewController(errorAlert, animated: true, completion: nil)
                return
            }

            let routeAlert: UIAlertController = UIAlertController(
                title: "Tavel Information",
                message: "Travel Time: \(response!.expectedTravelTime/60) minutes\nDeparture Time: \(response!.expectedDepartureDate)\nArrival Time: \(response!.expectedArrivalDate)\nDistance: \(response!.distance) meters", preferredStyle: UIAlertControllerStyle.Alert)
            let directionAction = UIAlertAction(title: "Route", style: UIAlertActionStyle.Default, handler: {
                (alert: UIAlertAction) in
                self.startRouting(request)
            })
            let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: {
                (alert: UIAlertAction) in
            })
            routeAlert.addAction(cancelAction)
            routeAlert.addAction(directionAction)
            self.presentViewController(routeAlert, animated: true, completion: nil)
        }
    }
    
    func startRouting(request: MKDirectionsRequest) {
        self.cleanRoute()

        let directions = MKDirections(request: request)
        directions.calculateDirectionsWithCompletionHandler({ (response, error) in
            if let err = error {
                let errorAlert = UIAlertController(title: "Direction Failed", message: err.userInfo["NSLocalizedFailureReason"] as? String, preferredStyle: UIAlertControllerStyle.Alert)
                let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: {
                    (alert: UIAlertAction) in
                })
                errorAlert.addAction(okAction)
                self.presentViewController(errorAlert, animated: true, completion: nil)
            }
            
            self.routeDetails = response!.routes.last
            self.mapView.addOverlay(self.routeDetails!.polyline)
            for step in self.routeDetails!.steps {
                print(step.instructions)
            }
            
        })
    }
    
    func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
        if self.routeDetails != nil {
            let routeLineRenderer = MKPolylineRenderer(polyline: self.routeDetails!.polyline)
            routeLineRenderer.strokeColor = UIColor.greenColor()
            routeLineRenderer.lineWidth = 5.0
            return routeLineRenderer
        }
        return MKOverlayRenderer()
    }
    
    func cleanRoute() {
        if self.routeDetails != nil {
            self.mapView.removeOverlay(self.routeDetails!.polyline)
        }
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if let message = self.chatTextField.text {
            socket.emit("chat message", message)
            self.chatTextField.text = ""
        }
        return false
    }
    
    func setTextViewKeyboardNotifications() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
    }
    
    func keyboardWillShow(sender: AnyObject) {
        let userInfo: [NSObject: AnyObject] = (sender as! NSNotification).userInfo!
        let keyboardSize = (userInfo[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue().size
        let screenHeight = UIScreen.mainScreen().bounds.height
    
        UIView.animateWithDuration(0.15, delay: 0, options: UIViewAnimationOptions.CurveEaseOut, animations: {

            self.messageView.translatesAutoresizingMaskIntoConstraints = true
            self.chatTextField.translatesAutoresizingMaskIntoConstraints = true
            self.chatButton.translatesAutoresizingMaskIntoConstraints = true
            
            self.messageView.frame.origin.y = screenHeight - self.chatTextField.bounds.height - keyboardSize.height - self.messageView.bounds.height - 10
            self.chatButton.frame.origin.y = screenHeight - keyboardSize.height - self.chatTextField.bounds.height - 5
            self.chatTextField.frame.origin.y = screenHeight - keyboardSize.height - self.chatTextField.bounds.height - 5

        }, completion: nil)
    }
    
    func keyboardWillHide(sender: AnyObject) {
        let screenHeight = UIScreen.mainScreen().bounds.height

        UIView.animateWithDuration(0.15, delay: 0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
            
            self.messageView.frame.origin.y = screenHeight - self.chatTextField.bounds.height - self.messageView.bounds.height - 10
            self.chatButton.frame.origin.y = screenHeight - self.chatTextField.bounds.height - 5
            self.chatTextField.frame.origin.y = screenHeight - self.chatTextField.bounds.height - 5
            
            }, completion: { void in
                self.messageView.translatesAutoresizingMaskIntoConstraints = false
                self.chatTextField.translatesAutoresizingMaskIntoConstraints = false
                self.chatButton.translatesAutoresizingMaskIntoConstraints = false
        });

    }
    
    @IBAction func closeTapped(sender: AnyObject) {
        self.chatTextField.resignFirstResponder()
    }
    
    @IBAction func storesButtonTapped(sender: AnyObject) {
        self.chatTextField.resignFirstResponder()

        let storeView = self.storeTableManager.createStoreTableView(CGRectZero)
        storeView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(storeView)
        let views = [
            "stores": storeView,
        ]
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[stores]-0-|", options: [], metrics: nil, views: views))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-0-[stores]-0-|", options: [], metrics: nil, views: views))
    }
}


class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
    var location: CLLocation!
    var viewController: ViewController!
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.location = locations.last as CLLocation?
    }
    
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case CLAuthorizationStatus.Denied:
            // locate to Berlin
            let regionRadius: CLLocationDistance = 1000
            let coordinateRegionx = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2D(latitude: 52.5167, longitude: 13.3833),
                regionRadius * 2.0, regionRadius * 2.0)
            self.viewController.mapView.setRegion(coordinateRegionx, animated: true)

        case CLAuthorizationStatus.AuthorizedWhenInUse:
            fallthrough
        case CLAuthorizationStatus.AuthorizedAlways:
            self.viewController.locationManager.startUpdatingLocation()
            if let location = self.viewController.locationManager.location {
                let coordinateRegion = MKCoordinateRegion(center: location.coordinate, span: MKCoordinateSpan(
                    latitudeDelta: CLLocationDegrees(0.025),
                    longitudeDelta: CLLocationDegrees(0.025)))
                self.viewController.mapView.setRegion(coordinateRegion, animated: true)
            }
            
        default:
            break
        }
    }
}


class Store: NSObject, MKAnnotation {
    var title: String?
    var coordinate: CLLocationCoordinate2D
    var street: String = ""
    var postal: String = ""
    var city: String = ""
    var country: String = ""
    
    init(title: String, coordinate: CLLocationCoordinate2D) {
        self.title = title
        self.coordinate = coordinate
        super.init()
        self.getAddress()
    }
    
    func getAddress() {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
        geocoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) in
            if let placemark: CLPlacemark = placemarks?.first {

                if let thoroughfare = placemark.thoroughfare {
                    self.street = thoroughfare
                }
                
                if let postalCode = placemark.postalCode {
                    self.postal = postalCode
                }

                if let locality = placemark.locality {
                    self.city = locality
                }
                
                if let placemarkCountry = placemark.country {
                    self.country = placemarkCountry
                }
            }
        });
    }
    
    func mapItem() -> MKMapItem {
        let addressDictionary: [String: AnyObject] = [
            CNPostalAddressStreetKey: self.street,
            CNPostalAddressPostalCodeKey: self.postal,
            CNPostalAddressCityKey: self.city,
            CNPostalAddressCountryKey: self.country,
        ]
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: addressDictionary)
        let mapItem = MKMapItem(placemark: placemark)
        return mapItem
    }
    
    func getDistance(current: CLLocation) -> Double {
        let storeLoc = CLLocation(latitude: self.coordinate.latitude, longitude: self.coordinate.longitude)
        return storeLoc.distanceFromLocation(current)
    }
    
}