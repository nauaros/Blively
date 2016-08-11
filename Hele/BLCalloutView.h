//
//  BLCalloutView.h
//  Hele
//
//  Created by Naufal Aros El Morabet on 09/08/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//

#import <UIKit/UIKit.h>

@import Mapbox;

@interface BLCalloutView : UIView <MGLCalloutView>

@property (nonatomic, strong) NSString *direction;
@property (weak, nonatomic) IBOutlet UIImageView *photo;

@end
