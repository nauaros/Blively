//
//  BLAdventureCell.m
//  Hele
//
//  Created by Naufal Aros El Morabet on 07/08/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//

#import "BLAdventureCell.h"

@implementation BLAdventureCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // Margin to reduce in image view.
    int margin = 10;
    
    self.separatorInset = UIEdgeInsetsZero;
    self.layoutMargins = UIEdgeInsetsZero;
    
    // Update the frame of the Image View.
    self.imageView.frame = CGRectMake(self.imageView.frame.origin.x - 7, self.imageView.frame.origin.y + margin/2, self.imageView.frame.size.height - margin, self.imageView.frame.size.height - margin);
    self.imageView.layer.cornerRadius = 3.0;
    self.imageView.clipsToBounds = YES;
    self.imageView.autoresizingMask = UIViewAutoresizingNone;
    
    // Update the frame of the Text Label.
    CGFloat x = (self.imageView.frame.origin.x) + (self.imageView.frame.size.height) + 10;
    self.textLabel.frame = CGRectMake(x, self.imageView.frame.origin.y + margin/2, self.textLabel.frame.size.width, self.textLabel.frame.size.height);
    
    // Update the frame of the Detail Text Label.
    self.detailTextLabel.frame = CGRectMake(x, self.detailTextLabel.frame.origin.y, self.detailTextLabel.frame.size.width, self.detailTextLabel.frame.size.height);
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
