//
//  VASandboxFileAccess.m
//
//  Created by Vlad Alexa on 2/23/12.
//

#import "VASandboxFileAccess.h"

@implementation VASandboxFileAccess


+(BOOL)punchHoleInSandboxForPath:(NSString*)path denyNotice:(NSString*)denyNotice
{
    //make sure we have a expanded and resolved path
    path = [[VASandboxFileAccess sandboxExpandTildeInPath:path] stringByResolvingSymlinksInPath];
    NSMutableString *message = [NSMutableString stringWithFormat:@"Permission required to access: %@",[path lastPathComponent]];
    
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    [openDlg setPrompt:@"Permit access"];
    [openDlg setTitle:message];
	[openDlg setAllowsMultipleSelection:NO];    
    [openDlg setShowsHiddenFiles:YES];
    [openDlg setDirectoryURL:[NSURL fileURLWithPath:path]];
    [openDlg setNameFieldStringValue:[path lastPathComponent]];
    BOOL directory;
    [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&directory];    
	if (directory) {
        [message appendString:@" folder"];        
        [openDlg setCanChooseDirectories:YES];  
    }else{
        [openDlg setCanChooseFiles:YES];        
        [openDlg setAllowedFileTypes:[NSArray arrayWithObject:[path pathExtension]]];        
    }
	if ([openDlg runModalForDirectory:path file:[path lastPathComponent] types:nil] == NSOKButton){
        NSURL *selection = [[openDlg URLs] objectAtIndex:0];
        if ([[[selection path] stringByResolvingSymlinksInPath] isEqualToString:path]) {
            return YES;
        }else{
            [[NSAlert alertWithMessageText:@"Wrong file was selected." defaultButton:@"Try Again" alternateButton:nil otherButton:nil informativeTextWithFormat:message] runModal];
            [VASandboxFileAccess punchHoleInSandboxForPath:path denyNotice:denyNotice];
        }
	}else{
        if (denyNotice) {
            if ([denyNotice isEqualToString:@""]) denyNotice = @"This software can not provide it's full functionality without access to certain files.";            
            [[NSAlert alertWithMessageText:@"Was denied access to required files." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:denyNotice] runModal];                    
        }
    }   
    return NO;
}

+(NSURL*)sandboxFileHandle:(NSString*)path forced:(BOOL)forced denyNotice:(NSString*)denyNotice
{    
    NSURL *url = [NSURL fileURLWithPath:[[VASandboxFileAccess sandboxExpandTildeInPath:path] stringByResolvingSymlinksInPath]];
    
    //only needed if we are above 10.6
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_6) return url;
        
    //just return if the file does not exist
    if ([[NSFileManager defaultManager] fileExistsAtPath:[url path]] != YES) return url;

    //only needed if we do not allready have permisions to the file
    if ([[NSFileManager defaultManager] isReadableFileAtPath:[url path]] == YES && forced == NO) {
        return url;
    }else {
        NSURL *bookmarkURL = [self getSecurityBookmark:url];
        if (bookmarkURL) {
            //found secure bookmark, return it
            return bookmarkURL;
        }else {
            if (forced == YES && [VASandboxFileAccess foundBookmarkForPath:path] == YES) return url;            
            //punch hole and save bookmark
            if ([VASandboxFileAccess punchHoleInSandboxForPath:[url path] denyNotice:denyNotice]) {
                if (![VASandboxFileAccess addSecurityBookmark:url]) {
                    [VASandboxFileAccess addRegularBookmark:url];
                }               
            } else {
                NSLog(@"Was not granted access to %@ in sandbox",[url path]);
            }        
        }
    }    
    return url;
}

+(BOOL)foundBookmarkForPath:(NSString*)path
{
    [VASandboxFileAccess pruneUnrestorableBookmarks];    
    path = [[VASandboxFileAccess sandboxExpandTildeInPath:path] stringByResolvingSymlinksInPath];
    NSDictionary *regular = [[NSUserDefaults standardUserDefaults] objectForKey:@"sandboxRegularBookmarks"]; 
    for (NSString *key in regular) {
        if ([key isEqualToString:path]) {
            return YES;
        }
    }    
    NSDictionary *secure = [[NSUserDefaults standardUserDefaults] objectForKey:@"sandboxSecureBookmarks"]; 
    for (NSString *key in secure) {
        if ([key isEqualToString:path]) {
            return YES;
        }
    }        
    return NO;
}

+(NSString*)sandboxExpandTildeInPath:(NSString*)path
{
    if ([path rangeOfString:@"~"].location == 0) {
        NSString *sandboxExpand = [path stringByExpandingTildeInPath];
        NSString *normalExpand = [[@"/Users/" stringByAppendingPathComponent:NSUserName()] stringByAppendingPathComponent:[path stringByReplacingOccurrencesOfString:@"~" withString:@""]];        
        if (![sandboxExpand isEqualToString:normalExpand]) {
            if ([[NSFileManager defaultManager] fileExistsAtPath:sandboxExpand]) {
                return sandboxExpand;            
            }else{
                NSLog(@"Notice : expanded %@ to %@ , the stringByExpandingTildeInPath sandbox expansion is to non-existant %@",path,normalExpand,sandboxExpand);                           
            }
        }        
        return normalExpand;         
    }
    return path;
}

+(NSURL*)getSecurityBookmark:(NSURL*)url
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *sandboxedBookmarks = [NSMutableDictionary dictionaryWithDictionary:[defaults objectForKey:@"sandboxSecureBookmarks"]];
    NSData *bookmark = [sandboxedBookmarks objectForKey:[[url URLByDeletingLastPathComponent] path]];     //first see if we have a bookmark for the parent directory
    if (bookmark == nil) bookmark = [sandboxedBookmarks objectForKey:[url path]];                         //if not then look for a bookmark of the exact file
    if (bookmark) {
        NSError *error = nil;
        BOOL bookmarkIsStale = NO;    
        NSURL *bookmarkURL = [NSURL URLByResolvingBookmarkData:bookmark options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&bookmarkIsStale error:&error]; 
        if (bookmarkIsStale || (error != nil)) {
            [sandboxedBookmarks removeObjectForKey:[url path]];
            [defaults setObject:sandboxedBookmarks forKey:@"sandboxSecureBookmarks"];                
            [defaults synchronize];                
            NSLog(@"Secure bookmark was pruned, resolution of %@ failed with error: %@",[url path],[error localizedDescription]);
        }else {
            return bookmarkURL;
        }         
    }
    return nil;
}

+(BOOL)addSecurityBookmark:(NSURL*)url
{
    NSError *error = nil;
    NSData *bookmarkData = [url bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
    if (error || (bookmarkData == nil)) {
        NSLog(@"Secure bookmark creation of %@ failed with error: %@",[url path],[error localizedDescription]);
        return NO;        
    }else{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
        NSMutableDictionary *sandboxedBookmarks = [NSMutableDictionary dictionaryWithDictionary:[defaults objectForKey:@"sandboxSecureBookmarks"]];        
        [sandboxedBookmarks setObject:bookmarkData forKey:[url path]];
        [defaults setObject:sandboxedBookmarks forKey:@"sandboxSecureBookmarks"];
        [defaults synchronize];
    }  
    return YES;
}

+(BOOL)addRegularBookmark:(NSURL*)url
{
    NSError *error = nil;    
    NSData *data = [url bookmarkDataWithOptions:NSURLBookmarkCreationMinimalBookmark includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
    if (error || (data == nil)) {
        NSLog(@"Regular bookmark creation of %@ failed with error: %@",[url path],[error localizedDescription]);   
        return NO;
    }else{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[defaults objectForKey:@"sandboxRegularBookmarks"]];                        
        [dict setObject:data forKey:[url path]];
        [defaults setObject:dict forKey:@"sandboxRegularBookmarks"];
        [defaults synchronize];                                            
    }    
    return YES;
}

+(void)startAccessingSecurityScopedResource:(NSURL*)url
{
    if ([url query]) [url startAccessingSecurityScopedResource];     
}

+(void)stopAccessingSecurityScopedResource:(NSURL*)url
{
    if ([url query]) [url stopAccessingSecurityScopedResource];     
}

+(void)willEncodeRestorableState:(NSCoder*)coder
{
    NSMutableArray *sandboxedEncoded = [NSMutableArray arrayWithCapacity:1];
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] objectForKey:@"sandboxRegularBookmarks"]; 
    for (NSString *key in dict) {
        NSData *data = [dict objectForKey:key];
        BOOL bookmarkIsStale;
        NSURL *url = [NSURL URLByResolvingBookmarkData:data options:NSURLBookmarkResolutionWithoutUI relativeToURL:nil bookmarkDataIsStale:&bookmarkIsStale error:nil];
        if (url && bookmarkIsStale == NO) {
            [sandboxedEncoded addObject:url];
        }
    }
    if ([sandboxedEncoded count] > 0) {
        [coder encodeObject:sandboxedEncoded forKey:@"sandboxRegularBookmarks"];
        //NSLog(@"encoded %@",sandboxedEncoded);        
    }
}

+(void)didDecodeRestorableState:(NSCoder*)coder
{
    NSArray *decoded = [coder decodeObjectForKey:@"sandboxRegularBookmarks"];
    if (decoded) {
        //NSLog(@"decoded %@",decoded);        
    } 
}

+(void)pruneUnrestorableBookmarks
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[defaults objectForKey:@"sandboxRegularBookmarks"]];     
    NSMutableArray *prune = [NSMutableArray arrayWithCapacity:1];
    for (NSString *key in dict) {
        if (![[NSFileManager defaultManager] isReadableFileAtPath:key]) {
            [prune addObject:key];
        }
    }
    if ([prune count] > 0 ) {
        for (NSString *key in prune) {
            [dict removeObjectForKey:key];
            NSLog(@"Pruned regular bookmark for %@",key);
        }
        [defaults setObject:dict forKey:@"sandboxRegularBookmarks"];
        [defaults synchronize];
    }

}

@end
