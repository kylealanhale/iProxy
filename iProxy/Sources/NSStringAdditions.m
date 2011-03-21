#import "NSStringAdditions.h"
#import <CommonCrypto/CommonDigest.h>
#include <arpa/inet.h>

@implementation NSString (NSStringAdditions)

+ (NSString *)addressFromData:(NSData *)data
{
    struct sockaddr_storage *addressStorage;
    NSString *result = nil;
    char buffer[255];
    
    memset(buffer, 0, sizeof(buffer));
    addressStorage = (void *)[data bytes];
    switch (addressStorage->ss_family) {
        case AF_INET:
        case AF_INET6:
            inet_ntop(addressStorage->ss_family, (void *)addressStorage, buffer, sizeof(buffer) - 1);
            break;
        default:
            NSAssert(NO, @"unknown %d", addressStorage->ss_family);
            break;
    }
    result = [NSString stringWithFormat:@"%s", buffer];
    return result;
}

- (NSString*) URLEncodedString
{
    NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(
        kCFAllocatorDefault,
        (CFStringRef)self,
        NULL,
        CFSTR("!*'();:@&=+$,/?%#[]"),
        kCFStringEncodingUTF8);

	return [result autorelease];
}

- (NSString*) URLDecodedString
{
	NSString *result = (NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(
        kCFAllocatorDefault,
        (CFStringRef)self,
        CFSTR(""),
        kCFStringEncodingUTF8);

	return [result autorelease];
}

- (NSString *) md5
{
	const char *cStr = [self UTF8String];
	unsigned char result[16];
	CC_MD5( cStr, strlen(cStr), result );
	return [NSString stringWithFormat:
		@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
		result[0], result[1], result[2], result[3], 
		result[4], result[5], result[6], result[7],
		result[8], result[9], result[10], result[11],
		result[12], result[13], result[14], result[15]
		];	
}

@end
