//
//  LocationSearchTable.m
//  Hele
//
//  Created by Naufal Aros El Morabet on 18/07/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//

#import <MapKit/MapKit.h>
#import "BLLocationSearchTable.h"

@import Mapbox;

@interface BLLocationSearchTable ()

@property (nonatomic, strong) NSArray<MKMapItem *> *matchingItems;

@end

@implementation BLLocationSearchTable

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //_geocoder = [MBGeocoder sharedGeocoder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Supporting methods

- (NSString *)stringOrEmpty:(NSString *)str {
    return str = str ? str : @"";
}

- (NSString *)parseAddress:(MKPlacemark *)selectedItem {
    // put a space between "4" and "Melrose Place"
    char firstSpace = *((selectedItem.subThoroughfare != nil && selectedItem.thoroughfare != nil) ? " " : "");
    // put a comma between street and city/state
    char comma = *((selectedItem.subThoroughfare != nil || selectedItem.thoroughfare != nil) && (selectedItem.subAdministrativeArea != nil || selectedItem.administrativeArea != nil) ? ", " : "");
    // put a space between "Washington" and "DC"
    char secondSpace = *((selectedItem.subAdministrativeArea != nil && selectedItem.administrativeArea != nil) ? " " : "");
    NSString *addressLine = [NSString stringWithFormat:@"%@%c%@%c %@%c%@", [self stringOrEmpty:selectedItem.subThoroughfare], firstSpace, [self stringOrEmpty:selectedItem.thoroughfare], comma, [self stringOrEmpty:selectedItem.locality], secondSpace, [self stringOrEmpty:selectedItem.administrativeArea]];
    return addressLine;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.matchingItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    // Configuring cell...
    MKPlacemark *selectedItem = self.matchingItems[indexPath.row].placemark;
    cell.textLabel.text = selectedItem.name;
    cell.detailTextLabel.text = [self parseAddress: selectedItem];
    
    return cell;
}

#pragma mark - Table view Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MKPlacemark *selectedItem = self.matchingItems[indexPath.row].placemark;
    [self.handleMapSearchDelegate dropPinZoomIn:selectedItem];
    [self dismissViewControllerAnimated:YES completion:nil];
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - UISearchResultsUpdating method

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    MGLMapView *mapView = self.mapView;
    NSString *searchBarText;
    if (searchController.searchBar.text) {
        searchBarText = searchController.searchBar.text;
    } else {
        return;
    }
    
    // Create MKLocalSearchRequest
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    request.naturalLanguageQuery = searchBarText;
    request.region = MKCoordinateRegionMake(mapView.centerCoordinate, MKCoordinateSpanMake(0.5, 0.5));
    
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest: request];
    [search startWithCompletionHandler:^(MKLocalSearchResponse * _Nullable response, NSError * _Nullable error) {
        if (!response || error) {
            return;
        }
        
        NSPredicate *noBusiness = [NSPredicate predicateWithFormat:@"business.uID == 0"];
        NSArray *locations = [NSArray arrayWithArray: response.mapItems];
        self.matchingItems = [locations filteredArrayUsingPredicate: noBusiness];
        [self.tableView reloadData];
    }];
}

@end