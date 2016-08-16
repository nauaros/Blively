//
//  BLPathViewController.m
//  Hele
//
//  Created by Naufal Aros El Morabet on 10/07/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//

#import <MapKit/MapKit.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import "BLPathViewController.h"
#import "BLAnnotation.h"
#import "BLCalloutView.h"
#import "BLPointAnnotation.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <ChameleonFramework/Chameleon.h>

@import Mapbox;
@import MapboxDirections;

@interface BLPathViewController () <MGLCalloutViewDelegate>

@property (weak, nonatomic) IBOutlet MGLMapView *mapView;
@property (strong, nonatomic) MBDirections *directions;

@end

@implementation BLPathViewController

- (void)viewDidLoad {
    
    // Configure navigation bar style.
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithHexString:@"#1abc9c"];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName : [UIColor colorWithWhite:1.0 alpha:0.85]};
    
    // Configure tab bat style.
    self.tabBarController.tabBar.tintColor = [UIColor colorWithHexString:@"#1abc9c"];
    
    _directions = [MBDirections sharedDirections];
    
}


# pragma mark - Supporting methods

- (void)mapRequestforCurrentLocation:(CLLocation *)currentLocation {

    MBRouteOptions *options = [[MBRouteOptions alloc] initWithWaypoints:[self waypointsArrayforCurrentLocation:currentLocation withAdventure:self.adventure] profileIdentifier:@"mapbox/walking"];
    options.includesSteps = NO;
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    NSURLSessionDataTask *task = [self.directions calculateDirectionsWithOptions:options completionHandler:^(NSArray<MBWaypoint *> * _Nullable waypoints, NSArray<MBRoute *> * _Nullable routes, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error calculating directions: %@", error);
            return;
        }
        
        MBRoute *route = routes.firstObject;
        
        if (route.coordinateCount) {
            // Convert the route's coordinates into a polyline.
            CLLocationCoordinate2D *routeCoordinates = malloc(route.coordinateCount * sizeof(CLLocationCoordinate2D));
            [route getCoordinates:routeCoordinates];
            MGLPolyline *routeline = [MGLPolyline polylineWithCoordinates:routeCoordinates count:route.coordinateCount];
            
            // Add the polyline to the map and fit the viewport to the polyline.
            [self.mapView addAnnotation:routeline];
            [self.mapView setVisibleCoordinates:routeCoordinates count:route.coordinateCount edgePadding:UIEdgeInsetsZero animated:YES];
            
            // Make sure to free this array to avoid leaking memory.
            free(routeCoordinates);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        });
    }];
    
    [task resume];
}

// Create an NSArray of MBWaypoints for the directions request.
- (NSArray<MBWaypoint *> *)waypointsArrayforCurrentLocation:(CLLocation *)currentLocation withAdventure:(BLAdventureMO *)adventure {
    NSMutableArray *waypointsArray = [NSMutableArray array];
    [waypointsArray addObject:[[MBWaypoint alloc] initWithCoordinate:currentLocation.coordinate coordinateAccuracy:-1 name:@""]];
    
    for (BLPinMO *pin in adventure.pins) {
        CLLocationDegrees lat = pin.latitude.doubleValue;
        CLLocationDegrees lon = pin.longitude.doubleValue;
        [waypointsArray addObject:[[MBWaypoint alloc] initWithCoordinate:CLLocationCoordinate2DMake(lat, lon) coordinateAccuracy:-1 name:@""]];
    }
    
    return [waypointsArray copy];
}

- (NSURL *)URLFromPin:(BLPinMO *)pin {
    NSMutableString *urlString = [NSMutableString stringWithString:pin.imageURL];
    
    // Change imageURL to imageURL of size: square
    [urlString deleteCharactersInRange:NSMakeRange(urlString.length-4, 4)];
    [urlString appendString:@"_s.jpg"];
    return [NSURL URLWithString:urlString];
}

- (void)locatePin:(BLPinMO *)pin withOrderNumber:(NSUInteger)number {
    // Instantiate a new CLGeocoder object.
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    CLLocation *location = [[CLLocation alloc] initWithLatitude:pin.latitude.doubleValue longitude:pin.longitude.doubleValue];
    
    // Submit a reverse-geocodin request for the specified location.
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (!error && [placemarks count] > 0) {
            CLPlacemark *placemark = [placemarks firstObject];
            
            NSString *direction = [NSString stringWithFormat:@"%@, %@", placemark.subThoroughfare, placemark.thoroughfare];;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                BLPointAnnotation *annotation = [[BLPointAnnotation alloc] init];
                
                // Set location.
                annotation.coordinate = location.coordinate;
                // Set image URL
                annotation.image = [NSURL URLWithString:pin.imageURL];
                // Set number.
                annotation.numberOrder = number;
                // Set title.
                annotation.title = direction;
                
                [self.mapView addAnnotation:annotation];
            });
        }
    }];
}

# pragma mark - MGLMapViewDelegate Methods

- (void)mapView:(MGLMapView *)mapView didUpdateUserLocation:(MGLUserLocation *)userLocation {
    
    CLLocation *firstLocation = [[CLLocation alloc] initWithLatitude:self.adventure.pins.firstObject.latitude.floatValue longitude:self.adventure.pins.firstObject.longitude.floatValue];
    CLLocationDistance distance = [userLocation.location distanceFromLocation:firstLocation];
    
    // If not in current location, don't include current location.
    if (distance >= 3000) {
        [self mapRequestforCurrentLocation:firstLocation];
        
        NSUInteger order = 1;
        for (BLPinMO *pin in _adventure.pins) {
            [self locatePin:pin withOrderNumber:order++];
        }
    } else {
        [self mapRequestforCurrentLocation:userLocation.location];
        
        NSUInteger order = 1;
        for (BLPinMO *pin in _adventure.pins) {
            [self locatePin:pin withOrderNumber:order++];
        }
    }
}

- (MGLAnnotationView *)mapView:(MGLMapView *)mapView viewForAnnotation:(BLPointAnnotation *)annotation {
    if (![annotation isKindOfClass:[MGLPointAnnotation class]]) {
        return nil;
    }
    
    NSString *reuseIdentifier = [NSString stringWithFormat:@"%f", annotation.coordinate.longitude];
    
    BLAnnotation *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:reuseIdentifier];
    
    // If there’s no reusable annotation view available, initialize a new one.
    if (!annotationView) {
        annotationView = [[BLAnnotation alloc] initWithReuseIdentifier:reuseIdentifier];
        annotationView.number.text = [NSString stringWithFormat:@"%lu", annotation.numberOrder];
    }
    
    return annotationView;
}

- (void)mapView:(MGLMapView *)mapView didSelectAnnotationView:(BLAnnotation *)annotationView {
    annotationView.number.textColor = [UIColor blackColor];
    annotationView.number.backgroundColor = [UIColor whiteColor];
    annotationView.image.image = [UIImage imageNamed:@"user_location_white"];
}

- (void)mapView:(MGLMapView *)mapView didDeselectAnnotationView:(BLAnnotation *)annotationView {
    annotationView.number.textColor = [UIColor whiteColor];
    annotationView.number.backgroundColor = [UIColor colorWithRed:0.60 green:0.00 blue:0.12 alpha:1.0];
    annotationView.image.image = [UIImage imageNamed:@"user_location_red"];
}
 
- (UIView<MGLCalloutView> *)mapView:(MGLMapView *)mapView calloutViewForAnnotation:(BLPointAnnotation *)annotation
{
    // Instantiate and return our custom callout view
    BLCalloutView *calloutView = [[BLCalloutView alloc] init];
    calloutView.representedObject = annotation;
    
    // Download image for callout view.
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [calloutView.photo sd_setImageWithURL:annotation.image placeholderImage:[UIImage imageNamed:@"placeholder"] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    }];
    
    return calloutView;
}

- (BOOL)mapView:(MGLMapView *)mapView annotationCanShowCallout:(id<MGLAnnotation>)annotation {
    return YES;
}

@end
