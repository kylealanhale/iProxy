//
//  UIColorAdditions.h
//  iProxy
//
//  Created by Jérôme Lebel on 14/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface UIColor (UIColorAdditions)

+ (UIColor *)colorWithRGB:(int)red, int green, int blue;
+ (UIColor *)colorWithRGBA:(int)red, int green, int blue, CGFloat alpha;

@end
