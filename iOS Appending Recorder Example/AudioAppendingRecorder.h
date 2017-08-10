//
//  AudioAppendingRecorder.h
//  iOS Appending Recorder Example
//
//  Created by Leo Thiessen on 2017-08-09.
//  Copyright © 2017 Leo Thiessen. All rights reserved.
//

#import <Foundation/Foundation.h>



extern const double kAudRecordingSampleRate;



typedef NS_ENUM(NSUInteger, AudRecorderEvent) {
    AudRecorderEventProgress, ///< see self.duration
    AudRecorderEventStopped,
    AudRecorderEventError, ///< see self.lastError
};



@class AudioAppendingRecorder;
@protocol AudioAppendingRecorderDelegate <NSObject>
@required
- (void)recorder:(AudioAppendingRecorder *_Nonnull)recorder event:(AudRecorderEvent)event;
@end



#pragma mark - Interface

@interface AudioAppendingRecorder : NSObject

/**
 Initialize this "appending recorder".

 @param cafFileURL where the file should be saved; use .caf file type only.
 @param error upon failure to initialize, this is populated with an NSError object
 @return an instance that is ready to start recording upon success, or nil upon failure.
 */
- (instancetype _Nullable)initWithDestinationFile:(NSURL *_Nonnull)cafFileURL
                                            error:(NSError *_Nullable *_Nullable)error NS_DESIGNATED_INITIALIZER;

- (instancetype _Nonnull)init NS_UNAVAILABLE;

- (void)record; ///< Start recording to new or appending to existing file
- (void)stop; ///< Stop recording


#pragma mark - Properties

@property (nonatomic, weak, readwrite) id<AudioAppendingRecorderDelegate> _Nullable delegate;
@property (nonatomic, strong, readonly) NSError *_Nullable lastError;
@property (nonatomic, readonly) NSTimeInterval duration; ///< seconds recorded

@end
