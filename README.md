## Description

A super simple and lightweight CoreData stack for iOS4+

## Usage

Don't forget to add the CoreData framework to your project.

### Basic setup

Setup the default CoreData stack in your application delegate

```objective-c
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

  // Setup CoreData stack
  [MCCCoreDataStack stackWithModelFilenames:@[ @"MyModel" ] dbName:@"MyDB"];

  /* ... */
}
```

This sets the default CoreData stack with a model file MyModel.momd (a compiled version of your XCode data model description file .xcdatamodeld) and stores a sqlite type database in a file named MyDB in the library folder of your bundle.

Now anywhere in your app, you can access this default stack. 

```objective-c
// Create a new context
NSManagedObjectContext *context = [MCCCoreDataStack context];
```

If you have entities in your Model and if they have a NSManagedObject subclass of their own, then it's even easier to fetch.


### NSManagedObject addons

For example, let's say you have a Person entity in your Model and that you created a custom NSManagedObject class for this entity.

```objective-c
@interface Person : NSManagedObject
@property (nonatomic, retain) NSString * name;
@end

@implementation Person
@dynamic name;
@end
```

The stack adds few useful methods to NSManagedObject in order to add/delete/fetch/count easily.


#### Creating 

You may create a new Person like this:

```objective-c
NSError *error = nil;

[Person insertObjectWithDictionary:@{
    @"name" : @"Starsky"
} error:&error];
```

A context is automatically created for you.

You may choose to create multiple Person-s in a context:

```objective-c
NSError *error = nil;

NSManagedObjectContext *context = [MCCCoreDataStack context];

Person *starsky = [Person managedObjectInContext:context];
[starsky setValuesForKeysWithDictionary:@{
     @"name" : @"Starsky"
}];

Person *hutch = [Person managedObjectInContext:context];
hutch.name = @"Hutch";

// Now save the context
if (![context save:&error]) {
  NSLog(@"Save error: %@", error);
}

```

#### Fetching / counting

You may fetch as usual but the fetch request is easier to setup:

```objective-c
NSManagedObjectContext *context = [MCCCoreDataStack context];
NSError *error = nil;

NSArray *results = [context executeFetchRequest:[Person fetchRequest] error:&error];
```

Notice the [Person fetchRequest] which returns a new fetchRequest for the related entity.

Or use one of the NSManagedObject additions that use Blocks! :

```objective-c
NSManagedObjectContext *context = [MCCCoreDataStack context];

[Person findWithContext:context 
  request:[Person fetchRequest] 
  callback:^(NSError *error, NSArray *data) {
    if (!error) {
       /* Update the UI with new persons data */
    }
}];
```

If you don't specify a request (set it to nil), a default fetchRequest is used.

There is even one find method that don't need a context, an automatically created context is used in this case:

```objective-c
[Person findWithRequest:nil callback:^(NSError *error, NSArray *data) {
  if (!error) {
     /* Update the UI with new persons data */
  }
}];
```

Counting is basically the same except it takes a NSPredicate:

```objective-c
[Person countWithPredicate:nil callback:^(NSError *error, NSInteger count) {
  if (!error) {
     /* Update the UI with the count */
  }
}];
```


## License terms

Copyright (c), 2012 Thierry Passeron

The MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.