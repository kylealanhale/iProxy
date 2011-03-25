//
//  PMSSSHFileController.m
//  iProxy
//
//  Created by Jérôme Lebel on 24/03/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PMSSSHFileController.h"
#import <Foundation/Foundation.h>

#define BEGIN_LINE_COMMENT @"# IPROXY BEGIN #"
#define END_LINE_COMMENT @"# IPROXY END #"
#define SSH_CONFIG_FILE_PATH @"/etc/ssh_config"
#define LOCAL_SSH_CONFIG_FILE_PATH @"~/.ssh/config"

#define LOCAL_SSH 1

@interface PMSSSHFileController()
- (BOOL)_cleanupSSHConfig;
- (void)_addProxy:(NSString *)proxy port:(NSUInteger)port;
- (BOOL)_writeSSHConfig;
- (BOOL)_load;
@end

@implementation PMSSSHFileController

- (id)init
{
    self = [super init];
    if (self != NULL) {
        [self _load];
    }
    return self;
}

- (void)dealloc
{
    [self cleanupProxy];
    AuthorizationFree(_authorization, kAuthorizationFlagDestroyRights);
    [_sshConfigContent release];
    [_sshConfigSavePath release];
    [super dealloc];
}

- (BOOL)_cleanupSSHConfig
{
    BOOL result = NO;
    NSUInteger beginIndex;
    NSUInteger endIndex;
    
    beginIndex = [_sshConfigContent indexOfObject:BEGIN_LINE_COMMENT];
    endIndex = [_sshConfigContent indexOfObject:END_LINE_COMMENT];
    if (beginIndex != NSNotFound && endIndex != NSNotFound && (endIndex - beginIndex == 2 || endIndex - beginIndex == 1)) {
        for (NSUInteger ii = 0; ii <= endIndex - beginIndex; ii++) {
            [_sshConfigContent removeObjectAtIndex:beginIndex];
        }
        result = YES;
    } else if (beginIndex == NSNotFound && endIndex == NSNotFound) {
        result = YES;
    }
    return result;
}

- (void)_addProxy:(NSString *)proxy port:(NSUInteger)port
{
    [_sshConfigContent addObject:BEGIN_LINE_COMMENT];
    [_sshConfigContent addObject:[NSString stringWithFormat:@"ProxyCommand /usr/bin/nc -X 5 -x %@:%d %%h %%p", proxy, port]];
    [_sshConfigContent addObject:END_LINE_COMMENT];
}

- (BOOL)_moveFromPath:(NSString *)fromPath toPath:(NSString *)toPath withAuthorisation:(BOOL)authorisation
{
    OSStatus status;
    BOOL result = NO;
    
    if (!_authorization && authorisation) {
        status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &_authorization);
        if (status != noErr) {
            NSLog(@"err %d %p", status, _authorization);
        }
    }
    if (_authorization && authorisation) {
        const char *chmodArgs[] = { "0644", [toPath fileSystemRepresentation], NULL };
        const char *ownArgs[] = { "root:wheel", [toPath fileSystemRepresentation], NULL };
        const char *mvArgs[] = { "-f", [fromPath fileSystemRepresentation], [toPath fileSystemRepresentation], NULL };
        
        status = AuthorizationExecuteWithPrivileges(_authorization, "/bin/mv", kAuthorizationFlagDefaults, (char * const *)mvArgs, NULL);
        result = status == errAuthorizationSuccess;
        if (!result) {
            NSLog(@"mv Authorization Result Code: %d", status);
        }
        status = AuthorizationExecuteWithPrivileges(_authorization, "/usr/sbin/chown", kAuthorizationFlagDefaults, (char * const *)ownArgs, NULL);
        if (!result) {
            NSLog(@"chmod Authorization Result Code: %d", status);
        }
        status = AuthorizationExecuteWithPrivileges(_authorization, "/bin/chmod", kAuthorizationFlagDefaults, (char * const *)chmodArgs, NULL);
        if (!result) {
            NSLog(@"chmod Authorization Result Code: %d", status);
        }
    } else if (!authorisation) {
        system([[NSString stringWithFormat:@"mv %s %s", [fromPath fileSystemRepresentation], [toPath fileSystemRepresentation]] UTF8String]);
        system([[NSString stringWithFormat:@"chmod 0644 %s", [toPath fileSystemRepresentation]] UTF8String]);
    }
    return result;
}

- (BOOL)_writeSSHConfig
{
    NSString *content;
    NSString *tmpSSHConfigPath;
    BOOL result;
    
    content = [_sshConfigContent componentsJoinedByString:@"\n"];
    tmpSSHConfigPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ssh_config.iproxy"];
    result = [content writeToFile:tmpSSHConfigPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    if (result) {
#if LOCAL_SSH
        result = [self _moveFromPath:tmpSSHConfigPath toPath:LOCAL_SSH_CONFIG_FILE_PATH withAuthorisation:NO];
#else
        result = [self _moveFromPath:tmpSSHConfigPath toPath:SSH_CONFIG_FILE_PATH withAuthorisation:YES];
#endif
    }
    return result;
}

- (BOOL)_load
{
    BOOL result = NO;
    NSString *originalContent;
    NSString *path;
    
#if LOCAL_SSH
    path = LOCAL_SSH_CONFIG_FILE_PATH;
#else
    path = SSH_CONFIG_FILE_PATH;
#endif
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        originalContent = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    } else {
        originalContent = @"";
    }
    if (originalContent) {
        _sshConfigContent = [[originalContent componentsSeparatedByString:@"\n"] mutableCopy];
        _sshConfigSavePath = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"ssh_config.iproxy"] retain];
        if (![originalContent writeToFile:_sshConfigSavePath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
            NSUInteger count;
            
            count = [_sshConfigContent count];
            result = [self _cleanupSSHConfig];
            if (result && count != [_sshConfigContent count]) {
                [self _writeSSHConfig];
            }
        }
    }
    return result;
}

- (void)setupProxy:(NSString *)proxy port:(NSUInteger)port
{
    [self _addProxy:proxy port:port];
    [self _writeSSHConfig];
    _proxyEnabled = YES;
}

- (void)cleanupProxy
{
    if (_proxyEnabled) {
        [self _cleanupSSHConfig];
        [self _writeSSHConfig];
    }
}

//- (void)test:(id)unused
//{
//    AuthorizationRef authorization;
//    OSStatus status;
//    
//    status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorization);
//    NSLog(@"err %d %p", status, authorization);
//    char *tool = "/bin/cat";
//    char *args[] = {NULL};
//    FILE *pipe = NULL;
//    
//    status = AuthorizationExecuteWithPrivileges(authorization, tool, kAuthorizationFlagDefaults, args, &pipe);
//    
//    char readBuffer[128];
//    if (status == errAuthorizationSuccess) {
//        for (;;) {
//            int bytesRead = read(fileno(pipe), readBuffer, sizeof(readBuffer));
//            if (bytesRead < 1) break;
//            readBuffer[bytesRead] = 0;
//            NSLog(@"%s", readBuffer);
//        }
//    } else {
//        NSLog(@"Authorization Result Code: %d", status);
//    }
//    status = AuthorizationFree(authorization, kAuthorizationFlagDestroyRights);
//}

@end
