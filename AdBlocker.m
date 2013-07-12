//
//  AdBlocker.m
//  Zeusmos
//
//  Created by Kevin Ko on 7/15/12.
//  Copyright (c) 2012 uhelios. All rights reserved.
//


#import "AdBlocker.h"

#define DOCUMENTS [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]
#define UPDATE_URL @"http://easylist-downloads.adblockplus.org/easylist.txt"

#define WhiteListFiltersKey					@"WhiteList"
#define PageWhiteListFiltersKey				@"PageWhiteList"
#define BlockListFiltersKey					@"BlockList"

@implementation NSString (RegexFiltering)

- (BOOL)_isMatchedByAnyRegexInArray:(NSArray *)regexArray
{
	if (!regexArray)
		return NO;
	
    for (NSString *regex in regexArray) {
        @try {
            if ([self isMatchedByRegex:regex options:RKLCaseless inRange:NSMakeRange(0, [self length]) error:NULL])
                return YES;
        }
        @catch (NSException *exception) {
            NSLog(@"%@", [exception description]);
        }
        @finally {
            
        }
    }
    return NO;
}

- (NSString *)stringByReplacingOccurrencesOfRegex:(NSString *)regex replace:(NSInteger)capture withString:(NSString *)reference {
    __block int count = 0;
    self = [self stringByReplacingOccurrencesOfRegex:regex usingBlock:^NSString *(NSInteger captureCount, NSString *const *capturedStrings, const NSRange *capturedRanges, volatile BOOL *const stop) {
        if (count < capture) {
            count++;
            return reference;
        }
        count++;
        return capturedStrings[0];
        
    }];
    return self;
}

- (NSDictionary *)parseAsFilter
{
	NSMutableDictionary *filter = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								   [NSNumber numberWithBool:NO],@"IsWhitelist",
								   nil,@"RegularExpression",
								   nil];
	
	NSString *current = [NSString stringWithString:self];
	NSString *filterEditorString = current;
    
	if ([current length] == 0)
		return nil;
	
	// For now, we ignore special-adblock-filters
	//current = [current stringByMatching:@"\\$(~?[\\w\\-]+(?:,~?[\\w\\-]+)*)$"
	//							replace:1
	//				withReferenceString:@""];
	
	if ([self isMatchedByRegex:@"#"])
		return nil;
	if ([self isMatchedByRegex:@"\\$"])
		return nil;
	
	// Comment?
	if ([current length] >= 1 && [current characterAtIndex:0] == '!')
		return nil;
	
	// Whitelist?
	if ([current length] >= 2 && [current characterAtIndex:0] == '@' && [current characterAtIndex:1] == '@') {
		current = [current substringFromIndex:2];
		filterEditorString = current;
		if ([current isMatchedByRegex:@"^\\|?https?://"]) {
			[filter setObject:[NSNumber numberWithBool:YES] forKey:@"IsPageWhitelist"];
			filterEditorString = [filterEditorString stringByMatching:@"^\\|?https?://" replaceWithEmptyString:1];
		} else {
			[filter setObject:[NSNumber numberWithBool:YES] forKey:@"IsWhitelist"];
			filterEditorString = current;
		}
	}
	
	// Regular expression?
	if ([current length] >= 2 && [current characterAtIndex:0] == '/' && [current characterAtIndex:[current length]-1] == '/') {
		[filter setObject:[NSNumber numberWithBool:YES] forKey:@"IsAlreadyRegularExpression"];
		current = [current substringWithRange:NSMakeRange(1, [current length]-2)];
		filterEditorString = current;
        
	} else {
		NSString *anchorParsed;
		
		// Next few lines inspired by AdBlock Plus
		// http://adblockplus.org
		// Prefs.js, line 924 of CVS version 1.64 (Mon Sep 24 09:22:37 2007)
		
		// Escape special symbols
        current = [current stringByReplacingOccurrencesOfRegex:@"(\\W)" withString:@"\\\\$1"];
		
		// Replace "\*" by ".*"
        current = [current stringByReplacingOccurrencesOfRegex:@"(\\\\\\*)" withString:@".*"];
		
		// Anchor at beginning
        anchorParsed = [current stringByReplacingOccurrencesOfRegex:@"(^\\\\\\|)" replace:1 withString:@"^"];
		if (![current isEqualToString:anchorParsed]) {
			[filter setObject:[NSNumber numberWithBool:YES] forKey:@"HasBeginningAnchor"];
			current = anchorParsed;
            filterEditorString = [filterEditorString stringByReplacingOccurrencesOfRegex:@"(^\\|)" replace:1 withString:@""];
		}
		
		// Anchor at end
        anchorParsed = [current stringByReplacingOccurrencesOfRegex:@"(\\\\\\|$)" replace:1 withString:@"$$"];
		if (![current isEqualToString:anchorParsed]) {
			[filter setObject:[NSNumber numberWithBool:YES] forKey:@"HasEndAnchor"];
			current = anchorParsed;
            filterEditorString = [filterEditorString stringByReplacingOccurrencesOfRegex:@"(\\|$)" replace:1 withString:@""];
			
		}
    }
	
	[filter setObject:current forKey:@"RegularExpression"];
	[filter setObject:filterEditorString forKey:@"FilterEditorString"];
	return filter;
}

// FIXME: RegexKit bug?
- (NSString *)stringByMatching:(id)aRegex replaceWithEmptyString:(const NSUInteger)count
{
	NSMutableString *temp = [NSMutableString stringWithString:[self stringByReplacingOccurrencesOfRegex:(NSString *)aRegex replace:count withString:@"FIX_THIS_BUG"]];
	[temp replaceOccurrencesOfString:@"FIX_THIS_BUG" withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [temp length])];
	return temp;
}

@end

@implementation AdBlocker
@synthesize filters;

- (NSString *)stringBetweenString:(NSString *)content start:(NSString*)start andString:(NSString*)end {
    NSScanner* scanner = [NSScanner scannerWithString:content];
    [scanner setCharactersToBeSkipped:nil];
    [scanner scanUpToString:start intoString:NULL];
    if ([scanner scanString:start intoString:NULL]) {
        NSString* result = nil;
        if ([scanner scanUpToString:end intoString:&result]) {
            return result;
        }
    }
    return nil;
}

- (void)checkForUpdates:(NSString *)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        return;
    NSError *err = NULL;
    NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    NSString *current_revision = [self stringBetweenString:contents start:@"! Checksum: " andString:@"\n"];
    NSString *online_contents = [NSString stringWithContentsOfURL:[NSURL URLWithString:UPDATE_URL] encoding:NSUTF8StringEncoding error:&err];
    if (err == NULL) {
        NSString *online_revision = [self stringBetweenString:online_contents start:@"! Checksum: " andString:@"\n"];
        if (![online_revision isEqualToString:current_revision] && online_revision != NULL) {
            NSLog(@"Updated Adblocker List to Revision: %@", online_revision);
            [online_contents writeToFile:[DOCUMENTS stringByAppendingPathComponent:@"adblock_list.txt"] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
            [self load:[DOCUMENTS stringByAppendingPathComponent:@"adblock_list.txt"]];
        }
        else {
            NSLog(@"No Adblocker List Updates Available");
        }
    }
    else {
        NSLog(@"Error Fetching Adblocker Update");
    }
}

- (BOOL)examineURL:(NSString *)url {
    // Is the whole page whitelisted?
    if (![url _isMatchedByAnyRegexInArray:[self.filters objectForKey:PageWhiteListFiltersKey]]) { // (Should we rather consider the current frame URL? [[[dataSource request] URL] absoluteString])
        
        // Is this URL whitelisted?
        if (![url _isMatchedByAnyRegexInArray:[self.filters objectForKey:WhiteListFiltersKey]])

            // Should we block this URL?
            if ([url _isMatchedByAnyRegexInArray:[self.filters objectForKey:BlockListFiltersKey]]) {
                NSLog(@"Blocking: %@.", url);
                return YES;
            }
    }
    return NO;
}

- (void)load:(NSString *)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path])
        return;
    
    if (self.filters) {
        [self.filters release];
        self.filters = nil;
    }
    
    self.filters = [[[NSMutableDictionary alloc] init] autorelease];
    NSMutableSet *whiteList = [NSMutableSet set];
	NSMutableSet *pageWhiteList = [NSMutableSet set];
	NSMutableSet *blockList = [NSMutableSet set];
	
	NSData *d = [NSData dataWithContentsOfFile:path];
    NSString *list = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];

    NSArray *lines = [list componentsSeparatedByString:@"\n"];
    lines = [lines subarrayWithRange:NSMakeRange(1, [lines count]-1)]; // Ignore first line
    NSString *line;
    for (line in lines) {
        NSDictionary *f;
        if ((f = [line parseAsFilter])) {
            if ([[f objectForKey:@"IsWhitelist"] boolValue]) {
                [whiteList addObject:[f objectForKey:@"RegularExpression"]];
            } else if ([[f objectForKey:@"IsPageWhitelist"] boolValue]) {
                [pageWhiteList addObject:[f objectForKey:@"RegularExpression"]];
            } else {
                [blockList addObject:[f objectForKey:@"RegularExpression"]];
            }
        }
    }

	[self.filters setValue:[whiteList allObjects] forKey:WhiteListFiltersKey];
	[self.filters setValue:[pageWhiteList allObjects] forKey:PageWhiteListFiltersKey];
	[self.filters setValue:[blockList allObjects] forKey:BlockListFiltersKey];
}

+ (AdBlocker *)sharedInstance
{
    static AdBlocker *sharedInstance;
    
    @synchronized(self)
    {
        if (!sharedInstance) {
            sharedInstance = [[AdBlocker alloc] init];
        }
        return sharedInstance;
    }
}

- (id)init
{
    self = [super init];
    
    if (self) {
        // Work your initialising magic here as you normally would
    }
    
    return self;
}

@end
