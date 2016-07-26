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

@interface BLExploreViewController () <UICollectionViewDataSource, UICollectionViewDelegate, MGLMapViewDelegate, CLLocationManagerDelegate, HandleMapSearch>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;

@property (nonatomic, strong) NSMutableArray *photoIDs;
@property (nonatomic, strong) NSMutableArray *photoURLs;
@property (nonatomic, strong) NSMutableArray *photoLocations;
@property (nonatomic, strong) NSCache *cache;
@property (nonatomic, assign) int numberOfPhotos;

// pragma mark - IBOutlets
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (strong, nonatomic) IBOutlet MGLMapView *mapView;

//
@property (nonatomic, strong) NSMutableOrderedSet *photoLocationsForAdv;
@property (nonatomic, strong) NSMutableOrderedSet *photoURLsForAdv;
@property (nonatomic, strong) NSMutableDictionary *pinPoints;

@property (nonatomic, strong) UISearchController *resultSearchController;
@property (nonatomic, strong) MKPlacemark *selectedPin;

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
    
    CLLocationDegrees lat = 43.6525;
    CLLocationDegrees lon = -79.381667;
    CLLocation *location = [[CLLocation alloc] initWithLatitude:lat longitude:lon];
    
    
    [self photosAroundLocation:location number:_numberOfPhotos forSize:flickrPhotoSizeMedium completionHandler:^{
        [_collectionView reloadData];
    }];

    MGLPointAnnotation *point = [[MGLPointAnnotation alloc] init];
    point.coordinate = CLLocationCoordinate2DMake(43.6525, -79.381667);
    point.title = @"Toronto";
    point.subtitle = @"David Bay Street, Ontario.";
    
    [self.mapView addAnnotation:point];
    
    [_mapView setCenterCoordinate:location.coordinate zoomLevel:8 animated:NO];
    
    // Setting UISearchController
    BLLocationSearchTable *locationSearchTable = [self.storyboard instantiateViewControllerWithIdentifier:@"LocationSearchTable"];
    locationSearchTable.mapView = self.mapView;
    locationSearchTable.handleMapSearchDelegate = self;
    _resultSearchController = [[UISearchController alloc] initWithSearchResultsController:locationSearchTable];
    _resultSearchController.searchResultsUpdater = locationSearchTable;
    
    
    // Configuring UISearchBar in the UINavigationItem
    UISearchBar *searchBar = _resultSearchController.searchBar;
    [searchBar sizeToFit];
    searchBar.placeholder = @"Search for cities";
    self.navigationItem.titleView = _resultSearchController.searchBar;
    
    _resultSearchController.hidesNavigationBarDuringPresentation = NO;
    _resultSearchController.dimsBackgroundDuringPresentation = YES;
    self.definesPresentationContext = YES;
    
    // Configuring UICollectionView
    /*UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.tintColor = [UIColor grayColor];
    [refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    [self.collectionView addSubview:refreshControl];*/
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
    
    dispatch_group_enter(group);
    [self photosAroundLocation:location number:number completionHandler:^{
        
        if (firstTimeRequest) {
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
            
            firstTimeRequest = NO;
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
    NSString *tags = @"architecture,monuments";
    int accuracy = 11;
    int content_type = 1;
    NSString *media = @"photos";
    int has_geo = 1;
    CLLocationDegrees lat = location.coordinate.latitude;
    CLLocationDegrees lon = location.coordinate.longitude;
    int per_page = number;
    NSString *format = @"json";
    
    NSString *urlString = [NSString stringWithFormat:@"https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=%@&tags=%@&accuracy=%d&content_type=%d&media=%@&has_geo=%d&lat=%f&lon=%f&per_page=%d&format=%@&nojsoncallback=1", apiKey, tags, accuracy, content_type, media, has_geo,lat, lon, per_page, format];
    
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
                        NSLog(@"Primera vez");
                        for (NSDictionary *photo in photoArray) {
                            [self.photoIDs addObject:photo];
                        }
                    } else {
                        NSLog(@"Segunda vez");
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
                NSLog(@"ERROR There was an HTTP error.");
            }
        } else {
            NSLog(@"ERROR There was an error with the API request.");
        }
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
                NSLog(@"ERROR There was an error in the HTTP response.");
            }
        } else {
            NSLog(@"ERROR There was an error with the request.");
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
                NSLog(@"ERROR There was an error in the HTTP response.");
            }
        } else {
            NSLog(@"ERROR There was an error with the request.");
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
    if (self.photoURLs.count == 0) {
        return 15;
    } else {
        return self.photoURLs.count;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.item >= self.numberOfPhotos/2) {
        NSLog(@"Estamos en el final.");
        [self loadMorePhotos];
    }
    BLPhotoCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kCellID forIndexPath:indexPath];
    cell.photo.image = [UIImage imageNamed:@"placeholder"];
    
    if (self.photoURLs.count != 0) {
        
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
    }
    
    return cell;
}

#pragma mark - Supporting Methods

- (void)loadMorePhotos {
    self.numberOfPhotos += INCR;
    //[self.photoIDs removeAllObjects];
    //[self.photoURLs removeAllObjects];
    //[self.photoLocations removeAllObjects];
    NSLog(@"LONGITUDE %lu", (unsigned long)self.photoIDs.count);
    CLLocation *location = [[CLLocation alloc] initWithLatitude:self.mapView.centerCoordinate.latitude longitude:self.mapView.centerCoordinate.longitude];
    [self photosAroundLocation:location number:self.numberOfPhotos forSize:flickrPhotoSizeMedium completionHandler:^{
        [_collectionView reloadData];
        NSLog(@"LONGITUDE %lu", (unsigned long)self.photoIDs.count);
    }];
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
    
    if (![self.photoLocationsForAdv containsObject:self.photoLocations[indexPath.item]] && ![self.photoURLsForAdv containsObject:self.photoURLs[indexPath.item]]) {
        
        CLLocation *location = self.photoLocations[indexPath.item];
        // FIXME: Convert to struct {CLLLocation location; NSURL urlPhoto}
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
    
    
    NSLog(@"%lu - %lu", (unsigned long)self.photoLocationsForAdv.count, (unsigned long)self.photoURLsForAdv.count);
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

- (IBAction)explore:(id)sender
{
    if (self.photoLocationsForAdv.count > 0) {
        
        BLAdventureMO *adventure = [NSEntityDescription insertNewObjectForEntityForName:@"Adventure" inManagedObjectContext:[self managedObjectContext]];
        adventure.date = [NSDate date];
        if ([self.textField.text isEqualToString:@""]) {
            adventure.name = @"Cheers";
        } else {
            adventure.name = self.textField.text;
        }
        
        NSMutableOrderedSet *set = [[NSMutableOrderedSet alloc] init];
        
        // FIXME: Use sctruct instead of two arrays
        for (NSUInteger i = 0; i < self.photoLocationsForAdv.count; i++) {
            BLPinMO *pin = [NSEntityDescription insertNewObjectForEntityForName:@"Pin" inManagedObjectContext:[self managedObjectContext]];
            
            CLLocation *location = [self.photoLocationsForAdv objectAtIndex:i];
            NSURL *url = [self.photoURLsForAdv objectAtIndex:i];
            
            pin.latitude = [NSNumber numberWithFloat:location.coordinate.latitude];
            pin.longitude = [NSNumber numberWithFloat:location.coordinate.longitude];
            pin.imageURL = url.absoluteString;
            
            [set addObject:pin];
        }
        
        adventure.pins = [set copy];
        
        [self saveContext];
        
    }
    
}

/*!
 Save current context. Core Data
 */
- (void)saveContext
{
    NSError *error = nil;
    if ([[self managedObjectContext] save:&error] == NO) {
        NSAssert(NO, @"Error saving context: %@\n%@", [error localizedDescription], [error userInfo]);
    } else {
        NSLog(@"Context saved.");
    }
}

#pragma mark - MGLMapViewDelegate methods

- (BOOL)mapView:(MGLMapView *)mapView annotationCanShowCallout:(id<MGLAnnotation>)annotation {
    // Always try to show a callout when an annotation is tapped.
    return YES;
}

#pragma mark - HandleMapSearch protocol methods

- (void)dropPinZoomIn:(MKPlacemark *)placemark {
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
    [self.photoURLsForAdv removeAllObjects];
    [self.pinPoints removeAllObjects];
    [self.cache removeAllObjects];
    self.numberOfPhotos = INCR;
    
    CLLocation *placemarkLocation = [[CLLocation alloc] initWithLatitude:placemark.coordinate.latitude longitude:placemark.coordinate.longitude];
    [self photosAroundLocation:placemarkLocation number:self.numberOfPhotos forSize:flickrPhotoSizeMedium completionHandler:^{
        [self.collectionView reloadData];
    }];
    
    // Move UICollectionView to the first cell.
    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0] atScrollPosition:UICollectionViewScrollPositionRight animated:NO];
    
    annotation.title = placemark.name;
    if (placemark.locality && placemark.administrativeArea) {
        annotation.subtitle = [NSString stringWithFormat:@"%@ %@", placemark.locality, placemark.administrativeArea];
    }
    
    [self.mapView addAnnotation: annotation];
    [self.mapView setCenterCoordinate:placemark.coordinate zoomLevel:12 animated:YES];
}

@end

