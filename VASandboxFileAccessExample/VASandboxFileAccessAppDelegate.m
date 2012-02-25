//
//  VASandboxFileAccessAppDelegate.m
//  VASandboxFileAccessExample
//
//  Created by Vlad Alexa on 2/25/12.
//

#import "VASandboxFileAccessAppDelegate.h"

#import "VASandboxFileAccess.h"

@implementation VASandboxFileAccessAppDelegate

@synthesize window = _window;

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] objectForKey:@"sandboxSecureBookmarks"];     
    NSMutableArray *secure = [NSMutableArray arrayWithCapacity:1];
    for (NSString *key in dict) {
        [secure addObject:key];
    }    
    NSLog(@"started with bookmarks %@",secure);
        
    NSArray *list = [NSArray arrayWithObjects:
                     @"/usr/share/MySQLMigrationToolManifest.txt",                    
                     @"/sbin/dynamic_pager",              
                     @"/bin/cat",                        
                     @"/Library/Desktop Pictures/Andromeda Galaxy.jpg",                               
                     @"/private/var/log",                     
                     @"/private/var/log/windowserver.log",
                     @"/private/var/log/kernel.log",
                     @"~/.bash_history",
                     @"~/Library/Preferences/loginwindow.plist",
                     nil];   
    
    for (NSString *path in list) {
        NSURL *secScopedUrl = [VASandboxFileAccess sandboxFileHandle:path forced:NO];
        [VASandboxFileAccess startAccessingSecurityScopedResource:secScopedUrl];
        if ([[NSFileManager defaultManager] isReadableFileAtPath:[secScopedUrl path]]){
            //NSLog(@"%@ readable",path);
        }else {
            NSLog(@"Access denied to %@ %@",[secScopedUrl path],[secScopedUrl query]);        
        }    
        [VASandboxFileAccess stopAccessingSecurityScopedResource:secScopedUrl];   
    }
    
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] objectForKey:@"sandboxSecureBookmarks"];     
    NSMutableArray *secure = [NSMutableArray arrayWithCapacity:1];
    for (NSString *key in dict) {
        [secure addObject:key];
    }    
    NSLog(@"eneded with bookmarks %@",secure);    
}

- (void) application:(NSApplication *)app willEncodeRestorableState:(NSCoder *)coder
{
    [VASandboxFileAccess willEncodeRestorableState:coder];    
}

- (void) application:(NSApplication *)app didDecodeRestorableState:(NSCoder *)coder
{
    [VASandboxFileAccess didDecodeRestorableState:coder];       
}

@end
