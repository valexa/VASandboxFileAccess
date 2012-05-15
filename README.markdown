VASandboxFileAccess - by Vlad Alexa

Introduction
------------

VASandboxFileAccess is a two-pronged implementation of file access and persistence with both the 10.7.3 sandboxing api's and the NSApplicationDelegate state restoration api, if permissions are needed for a file it spawns a powerbox open dialog to the user, once permission is aquired a bookmark is saved to provide persistence (a secure bookmark is attempted first with the regular one as a fallback).


Secure bookmarks
------------

Secure bookmarks refer to the bookmarks created with the NSURLBookmarkCreationWithSecurityScope, these give you a limited access scope within the startAccessingSecurityScopedResource and stopAccessingSecurityScopedResource 

To use them you would do something like:

        NSURL *secScopedUrl = [VASandboxFileAccess sandboxFileHandle:path forced:NO denyNotice:nil];
        [VASandboxFileAccess startAccessingSecurityScopedResource:secScopedUrl];
        //do your file access here
        [VASandboxFileAccess stopAccessingSecurityScopedResource:secScopedUrl]; 
        
This same code is used for regular bookmarks too in which case start and stopAccessing... do nothing, this relies on the implementation detail of secure bookmarks having a non nil query property.


Regular bookmarks
------------

Regular bookmarks refer to the ones used with the NSApplicationDelegate state restoration, these give you a sesion wide access (except if you manually call stopAccessingSecurityScopedResource on the path of one)

They are automatically applied to the sandbox when restored so you do not need to do anything special except implementing the code below in your app delegate:

        - (void) application:(NSApplication *)app willEncodeRestorableState:(NSCoder *)coder
        {
            [VASandboxFileAccess willEncodeRestorableState:coder];    
        }

        - (void) application:(NSApplication *)app didDecodeRestorableState:(NSCoder *)coder
        {
            [VASandboxFileAccess didDecodeRestorableState:coder];       
        }

Notes
------------

Typically system files will not be able to be bookmarked with the 10.7.3 api so regular bookmarks will be used, this is all implemented transparently, all the code you need to add after importing VASandboxFileAccess.h is referenced above.

Bookmarks are stored in the user preferences under sandboxSecureBookmarks and sandboxRegularBookmarks, pruning non-usable bookmarks is implemented, both types of bookmarks persist over reboots.

If acess is required for a given file and there is already a bookmark for the folder that holds it then access is given based on that folder and a bookmark for the specific file is not needed or created.

The forced option on sandboxFileHandle: should be set to YES if you want to start saving secure bookmarks while the app does not yet have sandboxing enabled so the users will not get permission open windows once you sandbox it.

The only issue i am aware of is that the specific file requested in the open dialog is not always selected, this is likely a issue with the powerbox, the folder/path is always properly set.


Requisites
-----------

The com.apple.security.files.user-selected.read-write entitlement set to YES ,the application to be signed and the implementation of the code above.


Source Code
-----------

The VASandboxFileAccess code is available under a BSD license from GitHub :

http://github.com/valexa/VASandboxFileAccess
