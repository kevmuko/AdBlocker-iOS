//
//  FilteredWebCache.m
//  Zeusmos
//
//  Created by Kevin Ko on 9/30/12.
//  Copyright (c) 2012 uhelios. All rights reserved.
//

#import "FilteredWebCache.h"
#import "AdBlocker.h"
@implementation FilteredWebCache

- (NSCachedURLResponse*)cachedResponseForRequest:(NSURLRequest*)request
{
    NSURL *url = [request URL];
    BOOL blockURL = [[AdBlocker sharedInstance] examineURL:[url relativeString]];
    if (blockURL) {
        NSURLResponse *response =
        [[NSURLResponse alloc] initWithURL:url
                                  MIMEType:@"text/plain"
                     expectedContentLength:1
                          textEncodingName:nil];
        
        NSCachedURLResponse *cachedResponse =
        [[NSCachedURLResponse alloc] initWithResponse:response
                                                 data:[NSData dataWithBytes:" " length:1]];
        
        [super storeCachedResponse:cachedResponse forRequest:request];
        
        [cachedResponse release];
        [response release];
    }
    return [super cachedResponseForRequest:request];
}

@end
