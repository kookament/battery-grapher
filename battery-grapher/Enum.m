#import "Enum.h"
#include <objc/runtime.h>

@implementation Enum
static NSMutableDictionary *enumItems = nil;

// -------------- //
// Static methods //
// -------------- //

//
// Non-class, non-instance methods.
//

static NSString *qualifiedSelectorName(Class c, SEL s) {
    return [NSString stringWithFormat:@"%s.%s", class_getName(c), sel_getName(s)];
}

static NSString *qualifiedSelectorNameRemovingPrefix(Class c, SEL s) {
    return [NSString stringWithFormat:@"%s.%s", class_getName(c), sel_getName(s) + 7];
}

static NSString *unqualifiedSelectorNameRemovingPrefix(SEL s) {
    return [NSString stringWithFormat:@"%s", sel_getName(s) + 7];
}

//
// Used as class methods (as IMP).
//

static Enum *getEnumObjectWithName(id self, SEL _cmd) {
    return [enumItems objectForKey:qualifiedSelectorName(self, _cmd)];
}

static Enum *illegalEnumFunction(id self, SEL _cmd) {
    [NSException raise:@"Invalid enum function called" format:@"Do not call enum functions using their mangled names."];
    return nil;
}

// ---------------- //
// Instance methods //
// ---------------- //

@synthesize name;

- (void) _setName:(NSString*)n {
    name = n;
}

- (NSString*) description {
    return name;
}

- (void) encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:[self name]    forKey:@"name"];
}

- (Enum*) initWithCoder:(NSCoder*)coder {
    NSString *n = [coder decodeObjectForKey:@"name"];
    Enum *e = [enumItems objectForKey:n];
    if (e == nil) {
        [NSException raise:@"Unrecognized enum item" format:@"Enum with name \"%@\" does not exist.", n];
    }
    return e;
}

// ------------- //
// Class methods //
// ------------- //

+ (void) initialize {
    // Enum must be subclassed.
    if (self == [Enum class]) {
        return;
    }
    
    // Metaclass: we want the static methods.
    Class metaClass = objc_getMetaClass([[self className] UTF8String]);
    
    unsigned int length;
    Method *classMethods = class_copyMethodList(metaClass, &length);
    NSMutableArray *allEnumItems = [NSMutableArray arrayWithCapacity:length];
    
    for (int i = 0; i < length; ++i) {
        Method m = classMethods[i];
        SEL enumItemSelector = method_getName(m);
        
        if (!strncmp("_enum__", sel_getName(enumItemSelector), 7)) {
            [allEnumItems addObject:[self addEnumObjectWithName:qualifiedSelectorNameRemovingPrefix(self, enumItemSelector)]];
            
            method_setImplementation(m, (IMP) illegalEnumFunction);
            m = class_getClassMethod(self, NSSelectorFromString(unqualifiedSelectorNameRemovingPrefix(enumItemSelector)));
            method_setImplementation(m, (IMP) getEnumObjectWithName);
        }
    }
    
    [enumItems setObject:allEnumItems forKey:NSStringFromClass(self)];
}

+ (Enum*) addEnumObjectWithName:(NSString*)name {
    if (enumItems == nil) {
        enumItems = [[NSMutableDictionary alloc] init];
    }
    assert([enumItems objectForKey:name] == nil);
    Enum *e = [[[self class] alloc] init];
    [e _setName:name];
    [enumItems setObject:e forKey:name];
    return e;
}

+ (NSArray*) allEnumItems {
    return [enumItems objectForKey:NSStringFromClass(self)];
}

@end
