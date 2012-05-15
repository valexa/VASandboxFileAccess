//
//  VASandboxFileAccess.h
//
//  Created by Vlad Alexa on 2/23/12.
//

#import <Foundation/Foundation.h>

@interface VASandboxFileAccess : NSObject{

}

+(BOOL)punchHoleInSandboxForPath:(NSString*)path denyNotice:(NSString*)denyNotice;
+(NSURL*)sandboxFileHandle:(NSString*)path forced:(BOOL)forced denyNotice:(NSString*)denyNotice;

+(BOOL)foundBookmarkForPath:(NSString*)path;
+(NSString*)sandboxExpandTildeInPath:(NSString*)path;

+(NSURL*)getSecurityBookmark:(NSURL*)url;

+(BOOL)addSecurityBookmark:(NSURL*)url;
+(BOOL)addRegularBookmark:(NSURL*)url;

+(void)startAccessingSecurityScopedResource:(NSURL*)url;
+(void)stopAccessingSecurityScopedResource:(NSURL*)url;

+(void)willEncodeRestorableState:(NSCoder*)coder;
+(void)didDecodeRestorableState:(NSCoder*)coder;

+(void)pruneUnrestorableBookmarks;

@end
