//
//  BLExploreViewController.m
//  Hele
//
//  Created by Naufal Aros El Morabet on 10/07/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//

#import "BLExploreViewController.h"
#import "BLPhotoCell.h"
#import "BLPinMO.h"
#import "BLAdventureMO.h"
#import "BLLocationSearchTable.h"
#import "BLPathViewController.h"
#import "Reachability.h"
#import <SDWebImage/UIImageView+WebCache.h>
#import <ChameleonFramework/Chameleon.h>

#define INCR 30     // Increment of photos in UICollectionView

@import Mapbox;

enum flickrPhotoSize {
    flickrPhotoSizeSquare,
    flickrPhotoSizeLargeSquare,
    flickrPhotoSizeThumbnail,
    flickrPhotoSizeSmall,
    flickrPhotoSizeSmall320,
    flickrPhotoSizeMedium,
    flickrPhotoSizeMedium640,
    flickrPhotoSizeMedium800,
    flickrPhotoSizeLarge,
    flickrPhotoSizeLarge1600
};


// pragma mark - Constants
static NSString *const apiKey = @"5cb909f40a9a88ecc2c97b0dfe7e09e5";
NSString *kCellID = @"photoCell";       // UICollecionViewCell storyboard id
BOOL firstTimeRequest = YES;

@interface BLExploreViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UISearchBarDelegate, MGLMapViewDelegate, CLLocationManagerDelegate, HandleMapSearch, CLLocationManagerDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *photoIDs;
@property (nonatomic, strong) NSMutableArray<NSURL *> *photoURLs;
@property (nonatomic, strong) NSMutableArray<CLLocation *> *photoLocations;
@property (nonatomic, strong) NSCache *cache;
@property (nonatomic, assign) int numberOfPhotos;

// pragma mark - IBOutlets
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (strong, nonatomic) IBOutlet MGLMapView *mapView;

//
@property (nonatomic, strong) NSMutableOrderedSet<CLLocation *> *photoLocationsForAdv;
@property (nonatomic, strong) NSMutableOrderedSet<NSURL *> *photoURLsForAdv;
@property (nonatomic, strong) NSMutableDictionary *pinPoints;
@property (nonatomic, strong) NSMutableArray<NSIndexPath *> *selectedItems;

@property (nonatomic, strong) UISearchController *resultSearchController;
@property (nonatomic, strong) MKPlacemark *selectedPin;
@property (nonatomic, strong) CLLocation *currentCity;

@property (nonatomic, strong) UIAlertAction *okAction;

// Check for internet connection.
@property (nonatomic) Reachability *internetReachability;

@property (nonatomic, strong) CLLocationManager *locationManager;

@end

@implementation BLExploreViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _session = [NSURLSession sharedSession];
    _photoIDs = [NSMutableArray array];
    _photoURLs = [NSMutableArray array];
    _photoLocations = [NSMutableArray array];
    _cache = [[NSCache alloc] init];
    _numberOfPhotos = INCR;
    
    // Initialize currentCity with New York coordintates.
    _currentCity = [[CLLocation alloc] initWithLatitude:40.7142700 longitude:-74.0059700];
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:_currentCity completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        if (!error && [placemarks count] > 0) {
            CLPlacemark *placemark = [placemarks firstObject];
            self.selectedPin = [[MKPlacemark alloc] initWithPlacemark:placemark];
        }
    }];
    
    
    // Initial position.
    switch (CLLocationManager.authorizationStatus) {
        case kCLAuthorizationStatusDenied: {
            // Removing all photos of previous location
            [self.photoIDs removeAllObjects];
            [self.photoURLs removeAllObjects];
            [self.photoLocations removeAllObjects];
            [self.photoLocationsForAdv removeAllObjects];
            [self.selectedItems removeAllObjects];
            [self.photoURLsForAdv removeAllObjects];
            [self.pinPoints removeAllObjects];
            [self.cache removeAllObjects];
            self.numberOfPhotos = INCR;
            
            [self photosAroundLocation:self.currentCity number:_numberOfPhotos forSize:flickrPhotoSizeMedium completionHandler:^{
                [_collectionView reloadData];
            }];
            
            [_mapView setCenterCoordinate:self.currentCity.coordinate zoomLevel:10 animated:NO];
        }
        default:
            ;
    }
    
    // Initialize locationManager.
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    
    // Configure navigation bar style.
    self.navigationController.navigationBar.barTintColor = [UIColor colorWithHexString:@"#1abc9c"];
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName : [UIColor colorWithWhite:1.0 alpha:0.85]};
    
    // Configure tab bat style.
    self.tabBarController.tabBar.tintColor = [UIColor colorWithHexString:@"#1abc9c"];
    
    // Configuring UINavigationItem.
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Explore" style:UIBarButtonItemStylePlain target:self action:@selector(exploreButtonClicked)];
    self.navigationItem.rightBarButtonItem.enabled = NO;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchButtonClicked)];
    self.navigationItem.title = @"Discover";
    
    
    
    // Checking for internet connection
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    
    // Listen for active state && check current connection.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(noConnectionAlert:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self noConnectionAlert:nil];
}

- (void)reachabilityChanged:(NSNotification *)notification {
    
    Reachability *reachability = [notification object];
    [self handleConnectionCheck:reachability];
}

- (void)handleConnectionCheck:(Reachability *)reachability {
    
    if (reachability.currentReachabilityStatus == NotReachable) {
        NSLog(@">>> No internet connection found.");
        self.collectionView.allowsSelection = NO;
        
        // Show alert: No Connection.
        [self noNetworkConnectionAlert];
    } else if (reachability.currentReachabilityStatus == ReachableViaWiFi || reachability.currentReachabilityStatus == ReachableViaWWAN) {
        
        NSLog(@">>> Internet connection found.");
        self.collectionView.allowsSelection = YES;
        [self.mapView setCenterCoordinate:self.currentCity.coordinate zoomLevel:10 animated:YES];
        
        if (self.photoURLs.count == 0) {
            // Removing all photos of previous location
            [self.photoIDs removeAllObjects];
            [self.photoURLs removeAllObjects];
            [self.photoLocations removeAllObjects];
            [self.photoLocationsForAdv removeAllObjects];
            [self.selectedItems removeAllObjects];
            [self.photoURLsForAdv removeAllObjects];
            [self.pinPoints removeAllObjects];
            [self.cache removeAllObjects];
            self.numberOfPhotos = INCR;
            
            [self loadMorePhotos];
        }
        
        // Move collectionView to beginning.
        // [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] atScrollPosition:UICollectionViewScrollPositionRight animated:NO];
    }
}

- (void)errorWithRequest {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:@"There was an error with the connection" preferredStyle:UIAlertControllerStyleAlert];
    
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

- (void)noNetworkConnectionAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Network" message:@"Please check your network connection" preferredStyle:UIAlertControllerStyleAlert];
    
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

- (void)noConnectionAlert:(NSNotification *)notification {
    // Present UIAlertController to alert user.
    // Create UIAlertController.
    if (self.internetReachability.currentReachabilityStatus != ReachableViaWiFi && self.internetReachability.currentReachabilityStatus != ReachableViaWWAN) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Turn Off Airplane Mode or Use Wi-Fi to Access Data" message:nil preferredStyle:UIAlertControllerStyleAlert];
        
        // Change background UIAlertController.
        UIView *subview = alert.view.subviews.firstObject;
        UIView *alertContentView = subview.subviews.firstObject;
        alertContentView.backgroundColor = [UIColor whiteColor];
        alertContentView.layer.cornerRadius = 10;
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        
        UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] openURL:url];
            });
        }];
        
        [alert addAction:settingsAction];
        [alert addAction:okAction];
        
        [self presentViewController:alert animated:YES completion:nil];
        
        // Change tintColor UIAlertController.
        alert.view.tintColor = [UIColor colorWithHexString:@"#1abc9c"];
    }
}

#pragma mark - Networking Methods

/*!
 @brief Search photos around a specific location.
 
 @discussion This method searches photos around a specific location. You can specify the size of photos you want to return.
 This method is already sincronized
 
 @see (void)photosAroundLocation:(CLLocation *)location completionHandler:(void (^)(void))completionHandler
 
 @param location location around which to search photos
 @param size size of photos
 @param completionHandler block to execute after the search
 
 @return list of photo URLs
 */
- (void)photosAroundLocation:(CLLocation *)location number:(int)number forSize:(enum flickrPhotoSize)size completionHandler:(void (^)(void))completionHandler
{
    dispatch_group_t group = dispatch_group_create();
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    
    dispatch_group_enter(group);
    [self photosAroundLocation:location number:number completionHandler:^{
        
        if (firstTimeRequest) {
            firstTimeRequest = NO;
            for (NSDictionary *photo in self.photoIDs) {
                
                dispatch_group_enter(group);
                [self locationForPhoto:photo completionHandler:^{
                    dispatch_group_leave(group);
                }];
                
                dispatch_group_enter(group);
                [self URLPhoto:photo forSize:size completionHandler:^{
                    dispatch_group_leave(group);
                }];
            }
            
        } else {
            for (int i = self.numberOfPhotos - INCR; i < self.photoIDs.count; i++) {
                
                dispatch_group_enter(group);
                [self locationForPhoto:(NSDictionary *)self.photoIDs[i] completionHandler:^{
                    dispatch_group_leave(group);
                }];
                
                dispatch_group_enter(group);
                [self URLPhoto:(NSDictionary *)self.photoIDs[i] forSize:size completionHandler:^{
                    dispatch_group_leave(group);
                }];
            }
        }
        
        dispatch_group_leave(group);
    }];
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completionHandler) {
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            completionHandler();
        }
    });
}

/*!
 @brief Search photos around a specific location.
 
 @param location location around which to search photos
 @param number number of photos
 @param completionHandler block to execute after the search
 
 @return list of photo URLs
 */
- (void)photosAroundLocation:(CLLocation *)location number:(int)number completionHandler:(void (^)(void))completionHandler
{
    // Arguments for the API Request
    NSString *tags = @"architecture,buildings,travel,tourism,monuments,art,outdoors";
    int accuracy = 11;
    int content_type = 1;
    NSString *media = @"photos";
    int has_geo = 1;
    CLLocationDegrees lat = location.coordinate.latitude;
    CLLocationDegrees lon = location.coordinate.longitude;
    int radius = 6;
    int per_page = number;
    NSString *format = @"json";
    
    NSString *urlString = [NSString stringWithFormat:@"https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=%@&tags=%@&accuracy=%d&content_type=%d&media=%@&has_geo=%d&lat=%f&lon=%f&radius=%d&per_page=%d&format=%@&nojsoncallback=1", apiKey, tags, accuracy, content_type, media, has_geo,lat, lon, radius, per_page, format];
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    _task = [self.session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            if (httpResp.statusCode == 200) {
                NSData *data = [NSData dataWithContentsOfURL:location];
                NSError *jsonError;
                NSDictionary *photosJSON = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
                
                if (!jsonError) {
                    NSArray *photoArray = [[photosJSON objectForKey:@"photos"] objectForKey:@"photo"];
                    
                    if (firstTimeRequest) {
                        for (NSDictionary *photo in photoArray) {
                            [self.photoIDs addObject:photo];
                        }
                    } else {
                        for (int i = self.numberOfPhotos - INCR; i < photoArray.count; i++) {
                            [self.photoIDs addObject:photoArray[i]];
                        }
                    }
                    
                    if (completionHandler) {
                        completionHandler();
                    }
                    
                } else {
                    NSLog(@"ERROR There was an error with the Serialization.");
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self errorWithRequest];
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self errorWithRequest];
            });        }
    }];
    
    [_task resume];
}

/*!
 @brief This method returns the url of a photo for a specific size.
 
 @discussion It makes a call to the API method <b>flickr.photos.getSizes</b>
 
 @param photo url of the photo
 @param size photo's size
 @param completionHandler
 
 @return url of the photo for a specific size
 */
- (void)URLPhoto:(NSDictionary *)photo forSize:(enum flickrPhotoSize)size completionHandler:(void (^)(void))completionHandler
{
    NSString *idPhoto = photo[@"id"];
    NSString *URLSizes = [NSString stringWithFormat:@"https://api.flickr.com/services/rest/?method=flickr.photos.getSizes&api_key=%@&photo_id=%@&format=json&nojsoncallback=1", apiKey, idPhoto];
    NSURL *url = [NSURL URLWithString:URLSizes];
    
    _task = [self.session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            if (httpResp.statusCode == 200) {
                NSError *jsonError;
                NSData *data = [NSData dataWithContentsOfURL:location];
                NSDictionary *sizesJSON = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
                
                
                if (!jsonError) {
                    NSArray *PhotoSizes = [[sizesJSON objectForKey:@"sizes"] objectForKey:@"size"];
                    NSString *URLPhotoString = nil;
                    
                    switch (size) {
                        case flickrPhotoSizeSquare:
                            URLPhotoString = [[PhotoSizes objectAtIndex:0] objectForKey:@"source"];
                            break;
                        case flickrPhotoSizeLargeSquare:
                            URLPhotoString = [[PhotoSizes objectAtIndex:1] objectForKey:@"source"];
                            break;
                        case flickrPhotoSizeThumbnail:
                            URLPhotoString = [[PhotoSizes objectAtIndex:2] objectForKey:@"source"];
                            break;
                        case flickrPhotoSizeSmall:
                            URLPhotoString = [[PhotoSizes objectAtIndex:3] objectForKey:@"source"];
                            break;
                        case flickrPhotoSizeSmall320:
                            URLPhotoString = [[PhotoSizes objectAtIndex:4] objectForKey:@"source"];
                            break;
                        case flickrPhotoSizeMedium:
                            URLPhotoString = [[PhotoSizes objectAtIndex:5] objectForKey:@"source"];
                            break;
                        case flickrPhotoSizeMedium640:
                            URLPhotoString = [[PhotoSizes objectAtIndex:6] objectForKey:@"source"];
                            break;
                        case flickrPhotoSizeMedium800:
                            URLPhotoString = [[PhotoSizes objectAtIndex:7] objectForKey:@"source"];
                            break;
                        case flickrPhotoSizeLarge:
                            URLPhotoString = [[PhotoSizes objectAtIndex:8] objectForKey:@"source"];
                            break;
                        case flickrPhotoSizeLarge1600:
                            URLPhotoString = [[PhotoSizes objectAtIndex:9] objectForKey:@"source"];
                            break;
                        default:
                            URLPhotoString = [[PhotoSizes objectAtIndex:0] objectForKey:@"source"];
                    }
                    
                    NSURL *url = [NSURL URLWithString:[URLPhotoString stringByReplacingOccurrencesOfString:@"\\" withString:@""]];
                    [self.photoURLs addObject:url];
                    
                    if (completionHandler) {
                        completionHandler();
                    }
                    
                } else {
                    NSLog(@"ERROR There was an error in the JSONSerialization");
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self errorWithRequest];
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self errorWithRequest];
            });
        }
    }];
    
    [_task resume];
}

/*!
 @brief This method return the location of a photo
 
 @discussion It makes a call to the API method <b>flickr.photos.geo.getLocation</b>
 
 @param photo dictionary that represents photo info
 @param completionHandler
 
 @return location of photo
 */
- (void)locationForPhoto:photo completionHandler:(void (^)(void))completionHandler
{
    NSString *idPhoto = photo[@"id"];
    NSString *photoLocURL = [NSString stringWithFormat:@"https://api.flickr.com/services/rest/?method=flickr.photos.geo.getLocation&api_key=%@&photo_id=%@&format=json&nojsoncallback=1", apiKey, idPhoto];
    NSURL *url = [NSURL URLWithString:photoLocURL];
    
    _task = [self.session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            if (httpResp.statusCode == 200) {
                NSError *jsonError;
                NSData *data = [NSData dataWithContentsOfURL:location];
                NSDictionary *locationJSON = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&jsonError];
                
                if (!jsonError) {
                    NSDictionary *location = [[locationJSON objectForKey:@"photo"] objectForKey:@"location"];
                    CLLocationDegrees latitude = [location[@"latitude"] doubleValue];
                    CLLocationDegrees longitude = [location[@"longitude"] doubleValue];
                    CLLocation *photoLocation = [[CLLocation alloc] initWithLatitude:latitude longitude:longitude];
                    
                    [self.photoLocations addObject:photoLocation];
                    
                    if (completionHandler) {
                        completionHandler();
                    }
                    
                } else {
                    NSLog(@"ERROR There was an error in the JSONSerialization");
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self errorWithRequest];
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self errorWithRequest];
            });
        }
    }];
    
    [_task resume];
    
}

#pragma mark - UICollectionViewDataSource Methods

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.photoURLs.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.item >= self.numberOfPhotos/2) {
        [self loadMorePhotos];
    }
    
    BLPhotoCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kCellID forIndexPath:indexPath];
    cell.photo.contentMode = UIViewContentModeScaleAspectFill;
    /* cell.photo.image = [UIImage imageNamed:@"placeholder"]; */
    
    if ([self.selectedItems containsObject:indexPath]) {
        cell.checkImage.hidden = NO;
    } else {
        cell.checkImage.hidden = YES;
    }
    
    if (self.photoURLs.count != 0) {
        /*
         if ( [self.cache objectForKey:@(indexPath.item)] != nil ) {
         cell.photo.image = [self.cache objectForKey:@(indexPath.item)];
         } else {
         _task = [self.session downloadTaskWithURL:self.photoURLs[indexPath.item] completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
         if (!error) {
         NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
         if (httpResp.statusCode == 200) {
         NSData *data = [NSData dataWithContentsOfURL:location];
         dispatch_async(dispatch_get_main_queue(), ^{
         BLPhotoCell *updateCell = (BLPhotoCell *)[collectionView cellForItemAtIndexPath:indexPath];
         if (updateCell) {
         UIImage *image = [UIImage imageWithData:data];
         updateCell.photo.image = image;
         [self.cache setObject:image forKey:@(indexPath.item)];
         }
         });
         
         } else {
         NSLog(@"ERROR There was an error in the HTTP response.");
         }
         } else {
         NSLog(@"ERROR There was an error with the request.");
         }
         }];
         
         [_task resume];
         }
         */
        
        // Image fetch using SDWebImage.
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        [cell.photo sd_setImageWithURL:self.photoURLs[indexPath.item] placeholderImage:[UIImage imageNamed:@"placeholder"] completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        }];
    }
    
    return cell;
}

#pragma mark - Supporting Methods

- (void)loadMorePhotos {
    self.numberOfPhotos += INCR;
    
    CLLocation *location = [[CLLocation alloc] initWithLatitude:self.mapView.centerCoordinate.latitude longitude:self.mapView.centerCoordinate.longitude];
    [self photosAroundLocation:location number:self.numberOfPhotos forSize:flickrPhotoSizeMedium completionHandler:^{
        [_collectionView reloadData];
    }];
}

/*!
 @brief Current location of user.
 */
- (CLLocation *)userLocation {
    return self.mapView.userLocation.location;
}

#pragma mark - UICollectionViewDelegate Methods

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.photoLocationsForAdv) {
        self.photoLocationsForAdv = [[NSMutableOrderedSet alloc] init];
        self.pinPoints = [NSMutableDictionary dictionary];
    }
    
    if (!self.photoURLsForAdv) {
        self.photoURLsForAdv = [[NSMutableOrderedSet alloc] init];
    }
    
    if (!self.selectedItems) {
        self.selectedItems = [[NSMutableArray alloc] init];
    }
    
    if (![self.photoLocationsForAdv containsObject:self.photoLocations[indexPath.item]] && ![self.photoURLsForAdv containsObject:self.photoURLs[indexPath.item]]) {
        CLLocation *location = self.photoLocations[indexPath.item];
        [self.photoLocationsForAdv addObject:location];
        [self.photoURLsForAdv addObject:self.photoURLs[indexPath.item]];
        
        MGLPointAnnotation *pin = [[MGLPointAnnotation alloc] init];
        pin.coordinate = location.coordinate;
        pin.title = [NSString stringWithFormat:@"%f - %f", location.coordinate.latitude, location.coordinate.longitude];
        
        [self.pinPoints setObject:pin forKey:@(indexPath.item)];
        [self.mapView addAnnotation:pin];
        
    } else {
        [self.photoLocationsForAdv removeObject:self.photoLocations[indexPath.item]];
        [self.photoURLsForAdv removeObject:self.photoURLs[indexPath.item]];
        
        MGLPointAnnotation *pin = [self.pinPoints objectForKey:@(indexPath.item)];
        [self.pinPoints removeObjectForKey:@(indexPath.item)];
        [self.mapView removeAnnotation:pin];
    }
    
    if (![self.selectedItems containsObject:indexPath]) {
        [self.selectedItems addObject:indexPath];
    } else {
        [self.selectedItems removeObject:indexPath];
    }
    
    BLPhotoCell *cell = (BLPhotoCell *)[collectionView cellForItemAtIndexPath:indexPath];
    if (cell.checkImage.hidden) {
        cell.checkImage.hidden = NO;
    } else {
        cell.checkImage.hidden = YES;
    }
    
    // show/hide rightBarButton.
    if (self.photoLocationsForAdv.count >= 4) {
        self.navigationItem.rightBarButtonItem.enabled = YES;
    } else {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
    
    
    
    NSLog(@"%lu - %lu", (unsigned long)self.photoLocationsForAdv.count, (unsigned long)self.photoURLsForAdv.count);
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    // Block selection of UICollectionViewCell.
    BLPhotoCell *cell = (BLPhotoCell *)[collectionView cellForItemAtIndexPath:indexPath];
    
    if (self.photoLocationsForAdv.count <= 23) {
        return YES;
    } else if (cell.checkImage.hidden == NO) {
        return YES;
    }
    
    // Create UIAlertController.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Photos Limit" message:@"You can only select up to 24 photos." preferredStyle:UIAlertControllerStyleAlert];
    
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
    
    return NO;
}


#pragma mark - NSManagedObjectContext

/*!
 Returns context
 */
- (NSManagedObjectContext *)managedObjectContext
{
    NSManagedObjectContext *context = nil;
    id delegate = [[UIApplication sharedApplication] delegate];
    if ([delegate performSelector:@selector(managedObjectContext)]) {
        context = [delegate managedObjectContext];
    }
    
    return context;
}

/*!
 Save current context. Core Data
 */
- (void)saveContext
{
    NSError *error = nil;
    if ([[self managedObjectContext] save:&error] == NO) {
        NSAssert(NO, @"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Could Not Save Data" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
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
    } else {
        NSLog(@"Context saved.");
    }
}

#pragma mark - MGLMapViewDelegate Methods

- (BOOL)mapView:(MGLMapView *)mapView annotationCanShowCallout:(id<MGLAnnotation>)annotation {
    // Always try to show a callout when an annotation is tapped.
    return YES;
}

- (void)mapView:(MGLMapView *)mapView didUpdateUserLocation:(MGLUserLocation *)userLocation {
    
    if (firstTimeRequest) {
        [self photosAroundLocation:userLocation.location number:_numberOfPhotos forSize:flickrPhotoSizeMedium completionHandler:^{
            [_collectionView reloadData];
        }];
        
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        [geocoder reverseGeocodeLocation:userLocation.location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
            if (!error && [placemarks count] > 0) {
                CLPlacemark *placemark = [placemarks firstObject];
                self.selectedPin = [[MKPlacemark alloc] initWithPlacemark:placemark];
            }
        }];
        
        
        self.currentCity = userLocation.location;
        [_mapView setCenterCoordinate:userLocation.location.coordinate zoomLevel:10 animated:NO];
    }
    
}

#pragma mark - CLLocationManager Delegate Methods

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusDenied) {
        // Removing all photos of previous location
        [self.photoIDs removeAllObjects];
        [self.photoURLs removeAllObjects];
        [self.photoLocations removeAllObjects];
        [self.photoLocationsForAdv removeAllObjects];
        [self.selectedItems removeAllObjects];
        [self.photoURLsForAdv removeAllObjects];
        [self.pinPoints removeAllObjects];
        [self.cache removeAllObjects];
        self.numberOfPhotos = INCR;
        
        [self photosAroundLocation:self.currentCity number:_numberOfPhotos forSize:flickrPhotoSizeMedium completionHandler:^{
            [_collectionView reloadData];
        }];
        
        [_mapView setCenterCoordinate:self.currentCity.coordinate zoomLevel:10 animated:NO];
    }
}

#pragma mark - HandleMapSearch Protocol Methods

- (void)dropPinZoomIn:(MKPlacemark *)placemark {
    // Cancel current download task.
    [self.task cancel];
    
    // cache the pin
    self.selectedPin = placemark;
    // clear existing pins
    [self.mapView removeAnnotations: self.mapView.annotations];
    MGLPointAnnotation *annotation = [[MGLPointAnnotation alloc] init];
    annotation.coordinate = placemark.coordinate;
    
    // Removing all photos of previous location
    [self.photoIDs removeAllObjects];
    [self.photoURLs removeAllObjects];
    [self.photoLocations removeAllObjects];
    [self.photoLocationsForAdv removeAllObjects];
    [self.selectedItems removeAllObjects];
    [self.photoURLsForAdv removeAllObjects];
    [self.pinPoints removeAllObjects];
    [self.cache removeAllObjects];
    self.numberOfPhotos = INCR;
    
    // Set current city.
    self.currentCity = placemark.location;
    
    [self photosAroundLocation:placemark.location number:self.numberOfPhotos forSize:flickrPhotoSizeMedium completionHandler:^{
        [self.collectionView reloadData];
        
        // Move UICollectionView to the first cell.
        if (self.photoURLs.count > 0) {
            [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] atScrollPosition:UICollectionViewScrollPositionRight animated:NO];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Ups ☹️" message:@"There are no photos." preferredStyle:UIAlertControllerStyleAlert];
            
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
    }];
    
    [self.mapView setCenterCoordinate:placemark.coordinate zoomLevel:10 animated:YES];
}

#pragma mark - UI Methods

- (void)searchButtonClicked {
    // Setting UISearchController
    BLLocationSearchTable *locationSearchTable = [self.storyboard instantiateViewControllerWithIdentifier:@"LocationSearchTable"];
    locationSearchTable.mapView = self.mapView;
    locationSearchTable.handleMapSearchDelegate = self;
    
    // Configuring UISearchController.
    self.resultSearchController = [[UISearchController alloc] initWithSearchResultsController:locationSearchTable];
    
    
    self.resultSearchController.searchResultsUpdater = locationSearchTable;
    self.resultSearchController.hidesNavigationBarDuringPresentation = NO;
    self.resultSearchController.dimsBackgroundDuringPresentation = YES;
    
    // Configuring UISearchBar of UISearchBarController.
    UISearchBar *searchBar = self.resultSearchController.searchBar;
    [searchBar sizeToFit];
    
    
    searchBar.barTintColor = [UIColor colorWithHexString:@"#1abc9c"];
    searchBar.tintColor = [UIColor whiteColor];
    searchBar.placeholder = @"Search for cities";
    
    [self presentViewController:self.resultSearchController animated:YES completion:nil];
}

- (void)exploreButtonClicked {
    // Create UIAlertController.
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Adventure Name" message:@"Enter the name of your adventure:" preferredStyle:UIAlertControllerStyleAlert];
    
    // Change background UIAlertController.
    UIView *subview = alert.view.subviews.firstObject;
    UIView *alertContentView = subview.subviews.firstObject;
    alertContentView.backgroundColor = [UIColor whiteColor];
    alertContentView.layer.cornerRadius = 10;
    
    // Add UITextField to UIAlertController.
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField){
        textField.placeholder = @"Name";
        textField.clearButtonMode = UITextFieldViewModeAlways;
        
        // Add observer to textField.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTextFieldTextDidChangeNotification:) name:UITextFieldTextDidChangeNotification object:textField];
    }];
    
    // Add UIAlertAction.
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        
        // Get name for adventure from Text Field.
        NSString *name = alert.textFields.firstObject.text;
        
        BLAdventureMO *adventure = [NSEntityDescription insertNewObjectForEntityForName:@"Adventure" inManagedObjectContext:[self managedObjectContext]];
        adventure.date = [NSDate date];
        adventure.name = name;
        adventure.location = self.selectedPin.locality;
        
        NSMutableOrderedSet *set = [[NSMutableOrderedSet alloc] init];
        
        for (NSUInteger i = 0; i < self.photoLocationsForAdv.count; i++) {
            BLPinMO *pin = [NSEntityDescription insertNewObjectForEntityForName:@"Pin" inManagedObjectContext:[self managedObjectContext]];
            
            CLLocation *location = [self.photoLocationsForAdv objectAtIndex:i];
            NSURL *url = [self.photoURLsForAdv objectAtIndex:i];
            
            pin.latitude = [NSNumber numberWithFloat:location.coordinate.latitude];
            pin.longitude = [NSNumber numberWithFloat:location.coordinate.longitude];
            pin.imageURL = url.absoluteString;
            
            [set addObject:pin];
        }
        
        // sort pins based on locations.
        [set sortUsingComparator:^NSComparisonResult(BLPinMO *obj1, BLPinMO *obj2) {
            CLLocation *l1 = [[CLLocation alloc] initWithLatitude:obj1.latitude.doubleValue longitude:obj1.longitude.doubleValue];
            CLLocation *l2 = [[CLLocation alloc] initWithLatitude:obj2.latitude.doubleValue longitude:obj2.longitude.doubleValue];
            CLLocation *origin = [[CLLocation alloc] initWithLatitude:self.mapView.centerCoordinate.longitude longitude:self.mapView.centerCoordinate.longitude];
            
            CLLocationDistance d1 = [l1 distanceFromLocation: origin];
            CLLocationDistance d2 = [l2 distanceFromLocation: origin];
            
            return d1 < d2 ? NSOrderedAscending : d1 > d2 ? NSOrderedDescending : NSOrderedSame;
        }];
        
        adventure.pins = [set copy];
        
        [self saveContext];
        
        // Configure BLPathViewController
        BLPathViewController *pathViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"PathViewController"];
        pathViewController.adventure = adventure;
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissView)];
        pathViewController.navigationItem.rightBarButtonItem = doneButton;
        pathViewController.navigationItem.title = name;
        
        // Present in Navigation Controller to dismiss it.
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:pathViewController];
        navController.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:navController animated:YES completion:^{
            // Clear existing pins.
            [self.mapView removeAnnotations: self.mapView.annotations];
            
            // Removing all photos of previous location
            [self.photoIDs removeAllObjects];
            [self.photoURLs removeAllObjects];
            [self.photoLocations removeAllObjects];
            [self.photoLocationsForAdv removeAllObjects];
            [self.selectedItems removeAllObjects];
            [self.photoURLsForAdv removeAllObjects];
            [self.pinPoints removeAllObjects];
            [self.cache removeAllObjects];
            self.numberOfPhotos = INCR;
            
            CLLocationCoordinate2D userLocation = CLLocationCoordinate2DMake(self.mapView.userLocation.coordinate.latitude, self.mapView.userLocation.coordinate.longitude);
            
            if (userLocation.latitude == 0.0 && userLocation.longitude == 0.0) {
                [self.mapView setCenterCoordinate:self.currentCity.coordinate zoomLevel:10 animated:YES];
                
                // move collection view to beginning.
                [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] atScrollPosition:UICollectionViewScrollPositionRight animated:NO];
                
                [self photosAroundLocation:self.currentCity number:self.numberOfPhotos forSize:flickrPhotoSizeMedium completionHandler:^{
                    [self.collectionView reloadData];
                }];
                
            } else {
                [self.mapView setCenterCoordinate:self.mapView.userLocation.location.coordinate zoomLevel:10 animated:YES];
                [self photosAroundLocation:self.mapView.userLocation.location number:self.numberOfPhotos forSize:flickrPhotoSizeMedium completionHandler:^{
                    [self.collectionView reloadData];
                }];
            }
            
        }];
        
        // Remove observer of textField.
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:alert.textFields.firstObject];
    }];
    
    // disable renameAction.
    okAction.enabled = NO;
    
    self.okAction = okAction;
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        // Remove observer of textField.
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:alert.textFields.firstObject];
    }];
    
    [alert addAction:okAction];
    [alert addAction:cancelAction];
    
    [self presentViewController:alert animated:YES completion:nil];
    
    // Change tintColor UIAlertController.
    alert.view.tintColor = [UIColor colorWithHexString:@"#1abc9c"];
    
}

// Dismiss presented view controller.
- (void)dismissView {
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleTextFieldTextDidChangeNotification:(NSNotification *)notification {
    UITextField *textField = (UITextField *)[notification object];
    
    // Enforce a minimum length of >= 1 for secure text alerts and text not equal to previous name.
    self.okAction.enabled = textField.text.length >= 1;
}

@end

