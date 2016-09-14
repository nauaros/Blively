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
#import "Reachability.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <ChameleonFramework/Chameleon.h>

@import Mapbox;
@import MapboxDirections;

// Do not update polyline.
BOOL drawPath;

@interface BLPathViewController () <MGLCalloutViewDelegate>

@property (weak, nonatomic) IBOutlet MGLMapView *mapView;
@property (strong, nonatomic) MBDirections *directions;
@property (nonatomic, strong) CLLocationManager *locationManager;

// Check for internet connection.
@property (nonatomic) Reachability *internetReachability;

@end

@implementation BLPathViewController

- (void)viewDidLoad {
    drawPath = NO;
    
    // Configure navigation bar style.
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithHexString:@"#1abc9c"];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName : [UIColor colorWithWhite:1.0 alpha:0.85]};
    self.navigationItem.title = self.adventure.name; // Set Adventure name as title of navController.
    
    // Configure tab bat style.
    self.tabBarController.tabBar.tintColor = [UIColor colorWithHexString:@"#1abc9c"];
    
    _directions = [MBDirections sharedDirections];
    
    // Initialize locationManager.
    _locationManager = [[CLLocationManager alloc] init];
    
    // Checking for internet connection
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    
    [self handleConnectionCheck:self.internetReachability];
}

- (void)reachabilityChanged:(NSNotification *)notification {
    
    Reachability *reachability = [notification object];
    [self handleConnectionCheck:reachability];
}

- (void)handleConnectionCheck:(Reachability *)reachability {
    
    switch (reachability.currentReachabilityStatus) {
        case NotReachable:
            NSLog(@">>> No internet connection found.");
            [self alertLostConnection];
            break;
        case ReachableViaWiFi:
        case ReachableViaWWAN:
            NSLog(@">>> Internet connection found.");
            [self drawIfLocationAvailable];
            break;
    }
}

- (void)alertLostConnection {
    // Present UIAlertController to alert user.
    // Create UIAlertController.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cannot Load Data" message:@"No internet connection available." preferredStyle:UIAlertControllerStyleAlert];
    
    // Change background UIAlertController.
    UIView *subview = alert.view.subviews.firstObject;
    UIView *alertContentView = subview.subviews.firstObject;
    alertContentView.backgroundColor = [UIColor whiteColor];
    alertContentView.layer.cornerRadius = 10;
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
    
    // Change tintColor UIAlertController.
    alert.view.tintColor = [UIColor colorWithHexString:@"#1abc9c"];
}

- (void)drawIfLocationAvailable {
    
    switch (CLLocationManager.authorizationStatus) {
        case kCLAuthorizationStatusAuthorizedAlways:
            break;
        case kCLAuthorizationStatusNotDetermined:
            [self.locationManager requestAlwaysAuthorization];
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusDenied: {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Background Location Access Disabled" message:@"We need your location to create a path" preferredStyle:UIAlertControllerStyleAlert];
            
            // Change background UIAlertController.
            UIView *subview = alertController.view.subviews.firstObject;
            UIView *alertContentView = subview.subviews.firstObject;
            alertContentView.backgroundColor = [UIColor whiteColor];
            alertContentView.layer.cornerRadius = 10;
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                
                // Draw path and add pins.
                CLLocation *firstLocation = [[CLLocation alloc] initWithLatitude:self.adventure.pins.firstObject.latitude.floatValue longitude:self.adventure.pins.firstObject.longitude.floatValue];
                [self mapRequestforCurrentLocation:firstLocation];
                
                NSUInteger order = 1;
                for (BLPinMO *pin in _adventure.pins) {
                    [self locatePin:pin withOrderNumber:order++];
                }
            }];
            
            UIAlertAction *openAction = [UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] openURL:url];
                });
                
                
                // Draw path and add pins.
                CLLocation *firstLocation = [[CLLocation alloc] initWithLatitude:self.adventure.pins.firstObject.latitude.floatValue longitude:self.adventure.pins.firstObject.longitude.floatValue];
                [self mapRequestforCurrentLocation:firstLocation];
                
                NSUInteger order = 1;
                for (BLPinMO *pin in _adventure.pins) {
                    [self locatePin:pin withOrderNumber:order++];
                }
            }];
            [alertController addAction:openAction];
            [alertController addAction:cancelAction];
            
            [self presentViewController:alertController animated:YES completion:nil];
            
            // Change tintColor UIAlertController.
            alertController.view.tintColor = [UIColor colorWithHexString:@"#1abc9c"];
            break;
        }
    }
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

- (void)locatePin:(BLPinMO *)pin withOrderNumber:(NSUInteger)number {
    // Instantiate a new CLGeocoder object.
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    CLLocation *location = [[CLLocation alloc] initWithLatitude:pin.latitude.doubleValue longitude:pin.longitude.doubleValue];
    
    // Submit a reverse-geocodin request for the specified location.
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (!error && [placemarks count] > 0) {
            CLPlacemark *placemark = [placemarks firstObject];
            
            NSString *direction = @"";
            if (placemark.subThoroughfare != nil && placemark.thoroughfare != nil) {
                direction = [NSString stringWithFormat:@"%@, %@", placemark.subThoroughfare, placemark.thoroughfare];
            } else {
                if (placemark.subThoroughfare) {
                    direction = [NSString stringWithFormat:@"%@", placemark.thoroughfare];
                } else if (placemark.thoroughfare) {
                    direction = [NSString stringWithFormat:@"%@", placemark.subThoroughfare];
                }
            }
            
            
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
        if (!drawPath) {
            [self mapRequestforCurrentLocation:firstLocation];
            
            NSUInteger order = 1;
            for (BLPinMO *pin in _adventure.pins) {
                [self locatePin:pin withOrderNumber:order++];
            }
            
            drawPath = YES;
        }
    } else {
        if (!drawPath) {
            [self mapRequestforCurrentLocation:userLocation.location];
            
            NSUInteger order = 1;
            for (BLPinMO *pin in _adventure.pins) {
                [self locatePin:pin withOrderNumber:order++];
            }
            drawPath = YES;
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
        annotationView.number.text = [NSString stringWithFormat:@"%lu", (unsigned long)annotation.numberOrder];
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
    // Do not show callout for user position.
    if ([annotation.title isEqualToString:@"You Are Here"]) {
        return nil;
    }
    
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

- (UIColor *)mapView:(MGLMapView *)mapView strokeColorForShapeAnnotation:(MGLShape *)annotation {
    return [UIColor colorWithRed:0.07 green:0.51 blue:0.43 alpha:1.0];
}

- (CGFloat)mapView:(MGLMapView *)mapView lineWidthForPolylineAnnotation:(MGLPolyline *)annotation {
    return 4.0;
}

- (BOOL)mapView:(MGLMapView *)mapView annotationCanShowCallout:(id<MGLAnnotation>)annotation {
    return YES;
}

@end
