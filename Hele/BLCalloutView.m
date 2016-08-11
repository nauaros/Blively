//
//  BLCalloutView.m
//  Hele
//
//  Created by Naufal Aros El Morabet on 09/08/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//

#import "BLCalloutView.h"

@interface BLCalloutView ()

@property (strong, nonatomic) IBOutlet UIView *view;
@property (weak, nonatomic) IBOutlet UILabel *address;

@end

@implementation BLCalloutView {
    id<MGLAnnotation> _representedObject;
    UIView *_leftAccessoryView;
    UIView *_righAccessoryView;
    id<MGLCalloutViewDelegate> delegate;
}

@synthesize representedObject = _representedObject;
@synthesize leftAccessoryView = _leftAccessoryView;
@synthesize rightAccessoryView = _rightAccessoryView;
@synthesize delegate = _delegate;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [[NSBundle mainBundle] loadNibNamed:@"BLCalloutView" owner:self options:nil];
        
        
        // Modify annotation's view layer.
        self.view.layer.cornerRadius = 4.0;
        self.view.layer.borderColor = [[UIColor blackColor] CGColor];
        self.view.layer.borderWidth = 0.15;
        
        self.photo.layer.cornerRadius = 4.0;
        
        self.bounds = self.view.bounds;

        [self addSubview:self.view];
    }
    
    return self;
}


#pragma mark - MGLCalloutView API

- (void)presentCalloutFromRect:(CGRect)rect inView:(UIView *)view constrainedToView:(UIView *)constrainedView animated:(BOOL)animated
{
    // Do not show a callout if there is no title set for the annotation
    if (![self.representedObject respondsToSelector:@selector(title)])
    {
        return;
    }
    
    // Set address.
    [self.address setText:self.representedObject.title];
 
    [view addSubview:self];
    
    CGFloat frameWidth = self.view.bounds.size.width;
    CGFloat frameHeight = self.view.bounds.size.height;
    CGFloat frameOriginX = rect.origin.x + (rect.size.width/2.0) - (frameWidth/2.0);
    CGFloat frameOriginY = rect.origin.y - frameHeight;
    
    // Default annotation frame.
    self.frame = CGRectMake(frameOriginX, frameOriginY, frameWidth, frameHeight);
    
    // Display sizes.
    CGRect displaySize = [UIScreen mainScreen].bounds;
    CGFloat statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;
    CGFloat navBarHeight = 44;
    
    
    CGFloat x = self.frame.origin.x;
    CGFloat y = self.frame.origin.y;
    CGFloat width = self.view.frame.size.width;
    
    // Position of Annotation view.
    if (y <= (statusBarHeight + navBarHeight + 10)) {
        frameOriginY = rect.origin.y + rect.size.height + 5;
    } else {
        frameOriginY = rect.origin.y - frameHeight - 5;
    }
    
    if (x >= 5 && (x + width) <= (displaySize.size.width - 5)) {
        frameOriginX = rect.origin.x + (rect.size.width/2.0) - (frameWidth/2.0);
    } else if (x + width >= displaySize.size.width) {
        float v1 = ((x + width) - displaySize.size.width) + 5;
        frameOriginX = rect.origin.x + (rect.size.width/2.0) - (frameWidth/2.0) - v1;
    } else  if (x <= 0) {
        float v1 = -x + 5;
        frameOriginX = rect.origin.x + (rect.size.width/2.0) - (frameWidth/2.0) + v1;
    }
    
    self.frame = CGRectMake(frameOriginX, frameOriginY, frameWidth, frameHeight);
    
    if (animated)
    {
        self.alpha = 0.0;
        
        [UIView animateWithDuration:0.2 animations:^{
            self.alpha = 1.0;
        }];
    }
}

- (void)dismissCalloutAnimated:(BOOL)animated
{
    if (self.superview)
    {
        if (animated)
        {
            [UIView animateWithDuration:0.2 animations:^{
                self.alpha = 0.0;
            } completion:^(BOOL finished) {
                [self removeFromSuperview];
            }];
        }
        else
        {
            [self removeFromSuperview];
        }
    }
}

@end