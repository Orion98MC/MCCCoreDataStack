//
//  MCCCoreDataStack.h
//
//  Created by Thierry Passeron on 17/09/12.
//  Copyright (c) 2012 Monte-Carlo Computing. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (MCCCoreDataStackAddon)
- (NSError *)errorByAddingValidationError:(NSError *)secondError;
@end

@interface NSManagedObject (MCCCoreDataStackAddon)
+ (id)managedObjectInContext:(NSManagedObjectContext *)context;
+ (NSFetchRequest *)fetchRequest;

+ (BOOL)insertObjectWithDictionary:(NSDictionary *)dictionary error:(NSError **)error;
+ (BOOL)deleteAllObjects:(NSError **)error;

+ (void)countWithContext:(NSManagedObjectContext *)context predicate:(NSPredicate *)predicate callback:(void(^)(NSError *error, NSInteger count))block;
+ (void)countWithPredicate:(NSPredicate *)predicate callback:(void(^)(NSError *error, NSInteger count))block;

+ (void)findWithContext:(NSManagedObjectContext *)context request:(NSFetchRequest *)request callback:(void(^)(NSError *error, NSArray *data))block;
+ (void)findWithRequest:(NSFetchRequest *)request callback:(void(^)(NSError *error, NSArray *data))block;
@end

@interface MCCCoreDataStack : NSObject

// Creator
+ (id)stackWithModelFilenames:(NSArray *)filenames dbName:(NSString*)dbName; /* Note that the first time you run this, it will create the default stack */

// Global settings
+ (void)setDBBaseDir:(NSString *)path; /* default is the library directory inside the bundle */
+ (void)setTrivialUpdatesOptions:(NSDictionary *)options; /* default is YES for NSMigratePersistentStoresAutomaticallyOption + NSInferMappingModelAutomaticallyOption + NSIgnorePersistentStoreVersioningOption, you should set these options prior to creating your stack */
+ (void)setOnStoreCreated:(id)block; /* triggered the first time the store is created */

// Default Stack accessor
+ (NSPersistentStoreCoordinator *)coordinator;
+ (NSManagedObjectContext *)context; /* return a context for the default stack */
+ (void)setMetaValue:(id)value forKey:(NSString *)key;
+ (id)metaValueForKey:(NSString *)key;
+ (BOOL)resetStack;

// Custom stack accessor
- (NSPersistentStoreCoordinator *)coordinator;
- (NSManagedObjectContext *)context; /* returns a context for this stack */
- (void)setMetaValue:(id)value forKey:(NSString *)key;
- (id)metaValueForKey:(NSString *)key;

@end
