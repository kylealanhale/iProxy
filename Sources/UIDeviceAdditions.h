#import <UIKit/UIKit.h>

@interface UIDevice (UIDeviceAdditions)

- (NSString *)IPAddressForInterface:(NSString*)ifname;

@end
