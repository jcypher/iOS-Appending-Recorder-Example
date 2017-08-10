//
//  TAAE2Utils.m
//  RecordEngine
//
//  Original source: AEAudioBufferListUtilities.m and other TAAE2 files
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

#import "TAAE2Utils.h"
#import <Accelerate/Accelerate.h>
#import <mach/mach_time.h>



#pragma mark - AETime.m

typedef uint64_t AEHostTicks;
typedef double AESeconds;

static double __hostTicksToSeconds = 0.0;
static double __secondsToHostTicks = 0.0;

const AudioTimeStamp AETimeStampNone = {};

void AETimeInit() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t tinfo;
        mach_timebase_info(&tinfo);
        __hostTicksToSeconds = ((double)tinfo.numer / tinfo.denom) * 1.0e-9;
        __secondsToHostTicks = 1.0 / __hostTicksToSeconds;
    });
}

AEHostTicks AECurrentTimeInHostTicks(void) {
    return mach_absolute_time();
}

AESeconds AECurrentTimeInSeconds(void) {
    if ( !__hostTicksToSeconds ) AETimeInit();
    return mach_absolute_time() * __hostTicksToSeconds;
}

AEHostTicks AEHostTicksFromSeconds(AESeconds seconds) {
    if ( !__secondsToHostTicks ) AETimeInit();
    assert(seconds >= 0);
    return seconds * __secondsToHostTicks;
}

AESeconds AESecondsFromHostTicks(AEHostTicks ticks) {
    if ( !__hostTicksToSeconds ) AETimeInit();
    return ticks * __hostTicksToSeconds;
}

AudioTimeStamp AETimeStampWithHostTicks(AEHostTicks ticks) {
    if ( !ticks ) return AETimeStampNone;
    return (AudioTimeStamp) { .mFlags = kAudioTimeStampHostTimeValid, .mHostTime = ticks };
}

AudioTimeStamp AETimeStampWithSamples(Float64 samples) {
    return (AudioTimeStamp) { .mFlags = kAudioTimeStampSampleTimeValid, .mSampleTime = samples };
}



#pragma mark - AEUtilities.h (may be modified)

BOOL AERateLimit(void) {
    static double lastMessage = 0;
    static int messageCount=0;
    double now = AECurrentTimeInSeconds();
    if ( now-lastMessage > 1 ) {
        messageCount = 0;
        lastMessage = now;
    }
    if ( ++messageCount >= 10 ) {
        if ( messageCount == 10 ) {
            NSLog(@"TAAE: Suppressing some messages");
        }
        return NO;
    }
    return YES;
}

void AEError(OSStatus result, const char * _Nonnull operation, const char * _Nonnull file, int line) {
    if ( AERateLimit() ) {
        int fourCC = CFSwapInt32HostToBig(result);
        if ( isascii(((char*)&fourCC)[0]) && isascii(((char*)&fourCC)[1]) && isascii(((char*)&fourCC)[2]) ) {
            NSLog(@"%s:%d: %s: '%4.4s' (%d)", file, line, operation, (char*)&fourCC, (int)result);
        } else {
            NSLog(@"%s:%d: %s: %d", file, line, operation, (int)result);
        }
    }
}



