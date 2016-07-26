//
//  BLAdventureMO+CoreDataProperties.h
//  Hele
//
//  Created by Naufal Aros El Morabet on 10/07/16.
//  Copyright © 2016 Naufal Aros. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "BLAdventureMO.h"

NS_ASSUME_NONNULL_BEGIN

@interface BLAdventureMO (CoreDataProperties)

@property (nullable, nonatomic, retain) NSDate *date;
@property (nullable, nonatomic, retain) NSString *location;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSOrderedSet<BLPinMO *> *pins;

@end

@interface BLAdventureMO (CoreDataGeneratedAccessors)

- (void)insertObject:(BLPinMO *)value inPinsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromPinsAtIndex:(NSUInteger)idx;
- (void)insertPins:(NSArray<BLPinMO *> *)value atIndexes:(NSIndexSet *)indexes;
- (void)removePinsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInPinsAtIndex:(NSUInteger)idx withObject:(BLPinMO *)value;
- (void)replacePinsAtIndexes:(NSIndexSet *)indexes withPins:(NSArray<BLPinMO *> *)values;
- (void)addPinsObject:(BLPinMO *)value;
- (void)removePinsObject:(BLPinMO *)value;
- (void)addPins:(NSOrderedSet<BLPinMO *> *)values;
- (void)removePins:(NSOrderedSet<BLPinMO *> *)values;

@end

NS_ASSUME_NONNULL_END
