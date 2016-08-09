//
//  View.m
//  Hele
//
//  Created by Naufal Aros El Morabet on 09/08/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//

#import "BLAnnotation.h"

@interface BLAnnotation ()
@end

@implementation BLAnnotation

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        // Initialization code
        
        // 1. Load .xib
        [[NSBundle mainBundle] loadNibNamed:@"BLAnnotation" owner:self options:nil];
        
        // 2. Adjust bounds.
        self.bounds = self.view.bounds;
        
        // 3. add as a subview.
        self.view.layer.borderColor = [[UIColor blackColor] CGColor];
        [self addSubview:self.view];
        
    }
    
    return self;
}

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    
    if (self) {
        // Initialization code
        
        // 1. Load .xib
        [[NSBundle mainBundle] loadNibNamed:@"BLAnnotation" owner:self options:nil];
        
        // 2. Adjust bounds.
        self.bounds = self.view.bounds;
        
        // 3. add as a subview.
        self.view.layer.borderColor = [[UIColor blackColor] CGColor];
        [self addSubview:self.view];
        
    }
    
    return self;
    
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        
        // 1. Load the interface file from the .xib
        [[NSBundle mainBundle] loadNibNamed:@"BLAnnotation" owner:self options:nil];
        
        // 2. Add as a subview.
        self.view.layer.borderColor = [[UIColor blackColor] CGColor];
        [self addSubview:self.view];
    }
    
    return self;
}

@end
