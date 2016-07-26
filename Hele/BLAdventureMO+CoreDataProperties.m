//
//  BLAdventureMO+CoreDataProperties.m
//  Hele
//
//  Created by Naufal Aros El Morabet on 10/07/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "BLAdventureMO+CoreDataProperties.h"

@implementation BLAdventureMO (CoreDataProperties)

@dynamic date;
@dynamic location;
@dynamic name;
@dynamic pins;

-(void)addPin:(BLPinMO *)pin
{
    NSMutableOrderedSet *oldPins = [NSMutableOrderedSet orderedSetWithOrderedSet:self.pins];
    [oldPins addObject:pin];
    self.pins = [NSOrderedSet orderedSetWithSet:[oldPins set]];
}

@end
