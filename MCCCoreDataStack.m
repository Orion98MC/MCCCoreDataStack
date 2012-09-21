//
//  MCCCoreDataStack.m
//
//  Created by Thierry Passeron on 17/09/12.
//  Copyright (c) 2012 Monte-Carlo Computing. All rights reserved.
//

#import "MCCCoreDataStack.h"

#define NSManagedObjectContextSaveDidFailNotification @"NSManagedObjectContextSaveDidFailNotification"

@implementation NSError (MCCCoreDataStackAddon)
- (NSError *)errorByAddingValidationError:(NSError *)secondError {
  NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
  NSMutableArray *errors = [NSMutableArray arrayWithObject:secondError];
  
  if ([self code] == NSValidationMultipleErrorsError) {
    [userInfo addEntriesFromDictionary:[self userInfo]];
    [errors addObjectsFromArray:[userInfo objectForKey:NSDetailedErrorsKey]];
  } else {
    [errors addObject:self];
  }
  
  [userInfo setObject:errors forKey:NSDetailedErrorsKey];
  
  return [NSError errorWithDomain:NSCocoaErrorDomain
                             code:NSValidationMultipleErrorsError
                         userInfo:userInfo];
}
@end

@implementation NSManagedObject (MCCCoreDataStackAddon)

+ (id)managedObjectInContext:(NSManagedObjectContext *)context {
  NSAssert([self class] != [NSManagedObject class], @"Only works on NSManagedObject subclass with entities named after the class");
  return [[[self alloc]initWithEntity:[[[[context persistentStoreCoordinator]managedObjectModel]entitiesByName]valueForKey:NSStringFromClass([self class])]  insertIntoManagedObjectContext:context]autorelease];
}

static NSMutableDictionary *entityDescriptions = nil;
+ (void)setEntityDescription:(NSEntityDescription *)entity {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    entityDescriptions = [[NSMutableDictionary dictionary]retain];
  });
  [entityDescriptions setValue:entity forKey:NSStringFromClass([self class])];
}

+ (NSEntityDescription *)entityDescription {
  return [entityDescriptions valueForKey:NSStringFromClass([self class])];
}

+ (NSFetchRequest *)fetchRequest {
  NSAssert([[self class]respondsToSelector:@selector(entityDescription)], @"Entity description is not set. You can't use this method if you setup a CoreData stack by hand");
  NSEntityDescription *entity = [[self class]entityDescription];
  NSFetchRequest *request = [[NSFetchRequest alloc]init];
  request.entity = entity;
  request.predicate = nil;
  return [request autorelease];
}

+ (BOOL)insertObjectWithDictionary:(NSDictionary *)dictionary error:(NSError **)error {
  NSManagedObjectContext *context = [MCCCoreDataStack context];
  
  NSManagedObject *o = [[self class]managedObjectInContext:context];
  [o setValuesForKeysWithDictionary:dictionary];
  
  NSError *saveError = nil;
  if (![context save:&saveError]) {
    if (error) *error = saveError;
    return FALSE;
  }
  return TRUE;
}

+ (void)countWithContext:(NSManagedObjectContext *)context predicate:(NSPredicate *)predicate callback:(void(^)(NSError *error, NSInteger count))block {
  NSError *countError = nil;
  NSInteger count = [context countForFetchRequest:[self fetchRequest] error:&countError];
  block(countError, count);
}

+ (void)countWithPredicate:(NSPredicate *)predicate callback:(void(^)(NSError *error, NSInteger count))block {
  [self countWithContext:[MCCCoreDataStack context] predicate:predicate callback:block];
}

+ (void)findWithContext:(NSManagedObjectContext *)context request:(NSFetchRequest *)request callback:(void(^)(NSError *error, NSArray *data))block {
  NSError *fetchError = nil;
  if (!request) request = [self fetchRequest];
  NSArray *objects = [context executeFetchRequest:request error:&fetchError];
  block(fetchError, objects);
}

+ (void)findWithRequest:(NSFetchRequest *)request callback:(void(^)(NSError *error, NSArray *data))block {
  [self findWithContext:[MCCCoreDataStack context] request:request callback:block];
}

+ (BOOL)deleteAllObjects:(NSError **)error {
  NSManagedObjectContext *context = [MCCCoreDataStack context];
  
  NSError *fetchError = nil;
  NSArray *objects = [context executeFetchRequest:[self fetchRequest] error:&fetchError];
  
  if (objects) {
    for (NSManagedObject *o in objects) {
      [context deleteObject:o];
    }
    
    NSError *saveError = nil;
    if (![context save:&saveError]) {
      if (error) *error = saveError;
      return FALSE;
    }
    return TRUE;
  }
  
  if (error) *error = fetchError;
  return FALSE;
}

@end



@interface MCCCoreDataStack ()
@property (retain, nonatomic) NSPersistentStoreCoordinator *coordinator;
@property (retain, nonatomic) NSArray *modelFilenames;
@property (retain, nonatomic) NSString *dbName;
@end

@implementation MCCCoreDataStack
@synthesize coordinator, modelFilenames, dbName;

static NSString *dbBaseDir = nil;
+ (NSString *)dbBaseDir { /* default is the library directory of the current bundle */
  if (dbBaseDir) return dbBaseDir;
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
  dbBaseDir = ([paths count] > 0) ? [[paths objectAtIndex:0]retain] : nil;
  return dbBaseDir;
}

+ (void)setDBBaseDir:(NSString *)path {
  if (dbBaseDir && dbBaseDir != path) [dbBaseDir release];
  dbBaseDir = [path retain];
}

static NSDictionary *trivialUpdatesOptions = nil;
+ (void)setTrivialUpdatesOptions:(NSDictionary *)options {
  if (trivialUpdatesOptions) [trivialUpdatesOptions release];
  trivialUpdatesOptions = [options retain];
}

static id onStoreCreated = nil;
+ (void)setOnStoreCreated:(id)block {
  if (onStoreCreated) Block_release(onStoreCreated);
  if (block) {
    onStoreCreated = Block_copy(block);
  }
}

- (id)initWithModelFilenames:(NSArray *)filenames dbName:(NSString *)name {
  self = [super init];
  if (!self) return nil;
  
  if (!onStoreCreated) {
    // Default onStoreCreated
    onStoreCreated = [^{
      NSLog(@"Database store was created!");
    }copy];
  }
  
  self.modelFilenames = filenames;
  self.dbName = name;
  
  NSAssert(name, @"A database name is required");
  NSAssert([filenames objectAtIndex:0], @"At least one model filename is required");
  
  NSString *dbPath = [[[self class]dbBaseDir]stringByAppendingPathComponent:dbName];
  self.coordinator = [self persistentStoreCoordinatorWithModel:[self modelByMergingModelsFormFiles:filenames] sqliteStoreWithPath:dbPath];
  
  return self;
}

- (void)dealloc {
  self.modelFilenames = nil;
  self.dbName = nil;
  self.coordinator = nil;
  [super dealloc];
}


#pragma mark class methods for defaultStack

static MCCCoreDataStack *defaultStack = nil;
+ (id)stackWithModelFilenames:(NSArray *)filenames dbName:(NSString*)dbName {
  MCCCoreDataStack *stack = [[self alloc]initWithModelFilenames:filenames dbName:dbName];
  if (!defaultStack) {
    defaultStack = [stack retain];
  }
  return [stack autorelease];
}

+ (NSPersistentStoreCoordinator *)coordinator {
  NSAssert(defaultStack, @"default stack not setup yet");
  return defaultStack.coordinator;
}

+ (NSManagedObjectContext *)context {
  NSAssert(defaultStack, @"default stack not setup yet");
  return [defaultStack context];
}

+ (void)setMetaValue:(id)value forKey:(NSString *)key {
  NSAssert(defaultStack, @"default stack not setup yet");
  [defaultStack setMetaValue:value forKey:key];
}

+ (id)metaValueForKey:(NSString *)key {
  NSAssert(defaultStack, @"default stack not setup yet");
  return [defaultStack metaValueForKey:key];
}

+ (BOOL)resetStack {
  NSAssert(defaultStack, @"default stack not setup yet");
  
  NSError *error = nil;
  NSPersistentStore *store = [[defaultStack.coordinator persistentStores]objectAtIndex:0];
  NSURL *storeURL = store.URL;
  
  BOOL removed = [defaultStack.coordinator removePersistentStore:store error:&error];
  
  if (!removed) {
    NSLog(@"Failed to remove store with error: %@", error);
    return FALSE;
  }
  
  BOOL deleted = [[NSFileManager defaultManager]removeItemAtURL:storeURL error:&error];
  if (!deleted) {
    NSLog(@"Failed to delete store file with error: %@", error);
    return FALSE;
  }
  
  NSArray *filenames = [defaultStack.modelFilenames copy];
  NSString *dbName = [defaultStack.dbName copy];
  
  // Release the default stack
  [defaultStack release], defaultStack = nil;
  
  // Recreate the stack
  [self stackWithModelFilenames:filenames dbName:dbName];
  
  [filenames release];
  [dbName release];
  
  return TRUE;
}



#pragma mark instance methods

- (NSManagedObjectContext *)context {
  NSManagedObjectContext *managedObjectContext = [[[NSManagedObjectContext alloc]init]autorelease];
  [managedObjectContext setPersistentStoreCoordinator:coordinator];
  [managedObjectContext setUndoManager:nil];
  return managedObjectContext;
}

- (void)setMetaValue:(id)value forKey:(NSString *)key {
  NSPersistentStore *store = [[coordinator persistentStores]objectAtIndex:0];
  if (!store) return;
  
  NSDictionary *newMeta = [NSMutableDictionary dictionaryWithDictionary:[store metadata]];
  [newMeta setValue:value forKey:key];
  [store setMetadata:newMeta];
}

- (id)metaValueForKey:(NSString *)key {
  NSPersistentStore *store = [[coordinator persistentStores]objectAtIndex:0];
  return store ? [[store metadata]valueForKey:key] : nil;
}

- (NSPersistentStoreCoordinator *)coordinator {
  return coordinator;
}


#pragma mark private methods

/* You may override this class method. By default it removes the store which could not be loaded */
+ (void)persistentStoreCoordinatorCreationFailedForStoreURL:(NSURL *)url withError:(NSError *)error {
  NSLog(@"Failed to create persistent store at url: %@, error: %@", url, error);
  [[NSFileManager defaultManager]removeItemAtURL:url error:nil];
  exit(1);
}

- (NSManagedObjectModel *)modelByMergingModelsFormFiles:(NSArray *)filenames {
  NSURL *modelURL;
  NSMutableArray *models = [NSMutableArray array];
  for (NSString *filename in filenames) {
    modelURL = [[NSBundle mainBundle] URLForResource:filename withExtension:@"momd"];
    [models addObject:[[[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL]autorelease]];
  }
  NSManagedObjectModel *managedObjectModel = [NSManagedObjectModel modelByMergingModels:models];
    
  return managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinatorWithModel:(NSManagedObjectModel *)model sqliteStoreWithPath:(NSString *)path {
  if (!trivialUpdatesOptions) {
    trivialUpdatesOptions = [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
      [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
      [NSNumber numberWithBool:YES], NSIgnorePersistentStoreVersioningOption,
    nil];
  }
  
  NSURL *storeURL = [NSURL fileURLWithPath:path];
  BOOL willCreateStore = ![[NSFileManager defaultManager]fileExistsAtPath:path];
  
  NSError *error = nil;
  NSPersistentStoreCoordinator* persistentStoreCoordinator = [[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model]autorelease];
  
  // Jumpstart the entities class if they exist
  for (NSEntityDescription *modelEntity in [model entities]) {
    Class modelClass = NSClassFromString(modelEntity.name);
    if (modelClass) {
      [modelClass setEntityDescription:modelEntity];
    }
  }
  
  if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:trivialUpdatesOptions error:&error]) {
    [[self class]persistentStoreCoordinatorCreationFailedForStoreURL:storeURL withError:error];
  } else {
    if (willCreateStore && onStoreCreated) {
      ((void(^)(void))onStoreCreated)();
    }
  }
  
  return persistentStoreCoordinator;
}

@end
