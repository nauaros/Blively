//
//  BLExploreViewController.h
//  Hele
//
//  Created by Naufal Aros El Morabet on 10/07/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@protocol HandleMapSearch;

@interface BLExploreViewController : UIViewController

@end

@protocol HandleMapSearch
- (void)dropPinZoomIn:(MKPlacemark *)placemark;
@end
