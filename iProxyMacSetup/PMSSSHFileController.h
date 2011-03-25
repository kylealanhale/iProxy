//
//  PMSSSHFileController.h
//  iProxy
//
//  Created by Jérôme Lebel on 24/03/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface PMSSSHFileController : NSObject
{
    NSString *_sshConfigSavePath;
    NSMutableArray *_sshConfigContent;
    AuthorizationRef _authorization;
    BOOL _proxyEnabled;
}

- (void)setupProxy:(NSString *)proxy port:(NSUInteger)port;
- (void)cleanupProxy;

@end
