//
//  AdBlocker.h
//  Zeusmos
//
//  Created by Kevin Ko on 7/15/12.
//  Copyright (c) 2012 uhelios. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RegexKitLite.h"

@interface NSString (RegexFiltering)

- (BOOL)_isMatchedByAnyRegexInArray:(NSArray *)regexArray;
- (NSString *)stringByReplacingOccurrencesOfRegex:(NSString *)regex replace:(NSInteger)capture withString:(NSString *)reference;
- (NSDictionary *)parseAsFilter;
- (NSString *)stringByMatching:(id)aRegex replaceWithEmptyString:(const NSUInteger)count;

@end

@interface AdBlocker : NSObject {
    NSMutableDictionary *filters;
}
@property (nonatomic, retain) NSMutableDictionary *filters;

- (void)checkForUpdates:(NSString *)path;
- (void)load:(NSString *)path;
- (BOOL)examineURL:(NSString *)url;
+ (id)sharedInstance;

@end
