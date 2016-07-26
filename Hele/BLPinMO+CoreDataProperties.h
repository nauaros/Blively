//
//  BLPinMO+CoreDataProperties.h
//  Hele
//
//  Created by Naufal Aros El Morabet on 10/07/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "BLPinMO.h"

NS_ASSUME_NONNULL_BEGIN

@interface BLPinMO (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *imageURL;
@property (nullable, nonatomic, retain) NSNumber *latitude;
@property (nullable, nonatomic, retain) NSNumber *longitude;
@property (nullable, nonatomic, retain) BLAdventureMO *adventure;

@end

NS_ASSUME_NONNULL_END
