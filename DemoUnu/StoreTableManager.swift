//
//  StoreTableManager.swift
//  DemoUnu
//
//  Created by Yuanhao Li on 05/11/15.
//  Copyright © 2015 Yuanhao Li. All rights reserved.
//

import UIKit
import MapKit

class StoreTableManager: NSObject, UITableViewDelegate, UITableViewDataSource {
    var viewController: ViewController
    var stores: [Store] {
        get {
            if let currentLoc = self.viewController.locationManager.location {
                return self.viewController.storeList.sort({ $0.getDistance(currentLoc) < $1.getDistance(currentLoc) })
            }
            return self.viewController.storeList
        }
    }
    
    init(controller: ViewController) {
        self.viewController = controller
        super.init()
    }
    
    func createStoreTableView(frame: CGRect) -> UIView {
        let view = UIView(frame: frame)
        view.backgroundColor = UIColor(red: 0.16, green: 0.16, blue: 0.16, alpha: 1.0)
        
        let closeButton: UIButton = UIButton(type: UIButtonType.Custom)
        closeButton.setTitle("Close", forState: UIControlState.Normal)
        closeButton.addTarget(self, action: "closeStoreViewTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        let tableView = UITableView(frame: CGRect(x: 0, y: 44, width: frame.width, height: frame.height - 44))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.showsHorizontalScrollIndicator = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        let views = [
            "closeButton": closeButton,
            "table": tableView,
        ]
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:[closeButton(88)]-4-|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-4-[closeButton(44)]", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[table]-0-|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-48-[table]-0-|", options: [], metrics: nil, views: views))
        
        return view
    }
    
    func closeStoreViewTapped(sender: UIButton) {
        let view = sender.superview
        UIView.animateWithDuration(0.3, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.5, options: UIViewAnimationOptions.CurveEaseInOut, animations: {
            view!.frame.origin.y = UIScreen.mainScreen().bounds.height
            }, completion: {(void) in
                view!.hidden = true
                view!.removeFromSuperview()
        })
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.stores.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell? = tableView.dequeueReusableCellWithIdentifier("storeCell") as UITableViewCell?
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "storeCell")
        }
        cell!.textLabel!.text = self.stores[indexPath.row].title
        return cell!
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let view = tableView.superview
        view!.hidden = true
        view!.removeFromSuperview()

        let store = self.stores[indexPath.row]
        let coordinateRegion = MKCoordinateRegion(center: store.coordinate, span: MKCoordinateSpan(
            latitudeDelta: CLLocationDegrees(0.05),
            longitudeDelta: CLLocationDegrees(0.05)))
        self.viewController.mapView.setRegion(coordinateRegion, animated: true)
    }
}

