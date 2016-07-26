//
//  LocationSearchTable.h
//  Hele
//
//  Created by Naufal Aros El Morabet on 18/07/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BLExploreViewController.h"

@import Mapbox;

@interface BLLocationSearchTable : UITableViewController <UISearchResultsUpdating>

@property (nonatomic, strong) MGLMapView *mapView;
@property (weak) id<HandleMapSearch> handleMapSearchDelegate;

@end
