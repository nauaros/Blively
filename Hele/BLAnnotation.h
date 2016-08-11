//
//  View.h
//  Hele
//
//  Created by Naufal Aros El Morabet on 09/08/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//

#import <UIKit/UIKit.h>
@import Mapbox;

@interface BLAnnotation : MGLAnnotationView

@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UILabel *number;

@end
