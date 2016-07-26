//
//  Cell.m
//  Hele
//
//  Created by Naufal Aros El Morabet on 10/07/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//

#import "BLPhotoCell.h"

@implementation BLPhotoCell

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.layer.cornerRadius = 10.0;
    self.clipsToBounds = YES;
}

@end
