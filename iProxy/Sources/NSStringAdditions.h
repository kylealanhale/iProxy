#import <Foundation/Foundation.h>

@interface NSString (NSStringAdditions)

+ (NSString *)addressFromData:(NSData *)data;
+ (NSString *)addressFromSockaddr:(struct sockaddr *)data;

- (NSString*) URLEncodedString;
- (NSString*) URLDecodedString;
- (NSString*) md5;

@end
