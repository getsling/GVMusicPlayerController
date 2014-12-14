//
//  NSString+TimeToString.h
//  lastfmlocalplayback
//
//  Created by Kevin Renskers on 19-09-12.
//  Copyright (c) 2012 Gangverk. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (TimeToString)

+ (NSString *)stringFromTime:(NSTimeInterval)seconds;

@end
