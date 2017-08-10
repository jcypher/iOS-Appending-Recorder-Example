//
//  TAAE2Utils.h
//  RecordEngine
//
//  Original source: AEAudioBufferListUtilities.h and other TAAE2 files
//  TheAmazingAudioEngine
//
//  Original was created by Michael Tyson on 24/03/2016.
//  Copyright © 2016 A Tasty Pixel. All rights reserved.
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//
//  THE CODE IN THIS FILE IS LIKELY MODIFIED FROM IT'S ORIGINAL TAAE2 SOURCES
//  Modifications by Leo Thiessen on 2017-06-08.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>



#pragma mark - AEUtilities.h (may be modified)

/*!
 * An error occurred within AECheckOSStatus
 *
 *  Create a symbolic breakpoint with this function name to break on errors.
 */
void AEError(OSStatus result, const char * _Nonnull operation, const char * _Nonnull file, int line);

/*!
 * Check an OSStatus condition
 *
 * @param result The result
 * @param operation A description of the operation, for logging purposes
 */
#define AECheckOSStatus(result,operation) (_AECheckOSStatus((result),(operation),strrchr(__FILE__, '/')+1,__LINE__))
static inline BOOL _AECheckOSStatus(OSStatus result, const char * _Nonnull operation, const char * _Nonnull file, int line) {
    if ( result != noErr ) {
        AEError(result, operation, file, line);
        return NO;
    }
    return YES;
}






