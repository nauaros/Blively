//
//  BLPointAnnotation.h
//  Hele
//
//  Created by Naufal Aros El Morabet on 11/08/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//

#import <Mapbox/Mapbox.h>

@interface BLPointAnnotation : MGLPointAnnotation

@property (nonatomic) NSUInteger numberOrder;
@property (nonatomic, strong) NSURL *image;

@end
