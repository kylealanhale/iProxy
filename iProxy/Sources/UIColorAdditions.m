//
//  UIColorAdditions.m
//  iProxy
//
//  Created by Jérôme Lebel on 14/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "UIColorAdditions.h"


@implementation UIColor(UIColorAdditions)

+ (UIColor *)colorWithRGB:(int)red, int green, int blue
{
	return [UIColor colorWithRGBA:red, green, blue, 1.0];
}

+ (UIColor *)colorWithRGBA:(int)red, int green, int blue, CGFloat alpha
{
	return [UIColor colorWithRed:(float)red/0xff green:(float)green/0xff blue:(float)blue/0xff alpha:alpha];
}

@end
