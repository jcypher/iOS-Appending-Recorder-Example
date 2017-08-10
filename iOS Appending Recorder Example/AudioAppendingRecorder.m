//
//  AudioAppendingRecorder.m
//  iOS Appending Recorder Example
//
//  Created by Leo Thiessen on 2017-08-09.
//  Copyright © 2017 Leo Thiessen. All rights reserved.
//

#import "AudioAppendingRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "TAAE2Utils.h"



#pragma mark - Constants/Globals

const double kAudRecordingSampleRate = 44100.0;



#pragma mark - Utilities

/// Makes an NSError object a little more consisely
static inline NSError *_Nonnull AudErrMake(NSInteger code,
                                           NSString *_Nonnull msg) {
    return [NSError errorWithDomain:@"AudioError"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey:msg}];
}

/// Conditionally sets the **error
static inline void AudErrSet(NSError *_Nullable *_Nullable error,
                             NSInteger code,
                             NSString *_Nonnull msg) {
    if ( error ) {
        *error = AudErrMake(code, msg);
    }
}



#pragma mark - Interface

@interface AudioAppendingRecorder () {
    
    NSURL *_fileURL;
    
    AudioFileID _fileID;      // the file we'll write data into
    UInt64 _inStartingPacket; // starting point for appending new audio
    SInt64 _frames;            // total recorded frames
    
    AVAudioFormat *_format;
}

@property (nonatomic, strong, readwrite) NSError *_Nullable lastError;
@property (nonatomic, readwrite) NSTimeInterval duration;
@property (nonatomic, strong, readwrite) AVAudioEngine *engine;

@end



#pragma mark - Implementation

@implementation AudioAppendingRecorder

- (instancetype)initWithDestinationFile:(NSURL *)fileURL
                                  error:(NSError *__autoreleasing  _Nullable *)error {
    
    if ( !(self=[super init]) ) {
        AudErrSet(error, -1, @"Couldn't initialize super.");
        return nil;
    }
    
    _fileURL = fileURL;
    
    _format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:kAudRecordingSampleRate channels:1];
    
    if ( ![self _setup:error] ) {
        return nil;
    }
    
    return self;
}

- (NSTimeInterval)duration {
    return (double)_frames / kAudRecordingSampleRate;
}

- (void)record {
    // Setup for current iOS state (start audio session, user record permission and everything...)
    NSError *error;
    if ( ![self _setup:&error] ) {
        printf("%s:ERROR: %s\n", __func__, error.localizedDescription.UTF8String);
        self.lastError = error;
        [self _messageDelegate:AudRecorderEventError];
        return;
    }
    
    // Check record permission!
    __typeof__(self) __weak weakSelf = self;
    [AVAudioSession.sharedInstance requestRecordPermission:^(BOOL granted) {
        if ( granted ) {
            [weakSelf _startRecordingWithGrantedPermission];
        } else {
            NSError *error = AudErrMake(-1, @"Record permission was denied. This can be changed in Settings > Privacy > Microphone");
            weakSelf.lastError = error;
            [weakSelf _messageDelegate:AudRecorderEventError];
        }
    }];
}

- (void)stop {
    BOOL wasRecording = (self.engine);
    if ( wasRecording ) {
        [self.engine stop];
        [self.engine reset];
    }
    self.engine = nil;
    if ( _fileID ) {
        // Optimize the file if necessary - this can take a while and in our case probably is never needed
        // because we only use core audio functions to read/write the caf's, but do just in case it's needed
        UInt32 isOptimized = 0;
        UInt32 propSize = sizeof(isOptimized);
        OSStatus result = AudioFileGetProperty(_fileID, kAudioFilePropertyIsOptimized, &propSize, &isOptimized);
        if ( !AECheckOSStatus(result, "AudioFileGetProperty(kAudioFilePropertyIsOptimized)") || !isOptimized ) {
            AudioFileOptimize(_fileID); // try to optimize it
        }
        AudioFileClose(_fileID);
        
        // Delete empty recording
        if ( _frames == 0 ) {
            [NSFileManager.defaultManager removeItemAtURL:_fileURL error:nil];
        }
    }
    _fileID = NULL;
    if ( wasRecording ) {
        [self _messageDelegate:AudRecorderEventStopped];
    }
}

/// Message delegate on main thread only
- (void)_messageDelegate:(AudRecorderEvent)event {
    id<AudioAppendingRecorderDelegate> __strong strongDelegate = self.delegate;
    if ( strongDelegate ) {
        if ( NSThread.isMainThread ) {
            [strongDelegate recorder:self event:event];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongDelegate recorder:self event:event];
            });
        }
    }
}

/// _setup{} is used so we can "auto-resume" recording if interrupted somehow
- (BOOL)_setup:(NSError**)error {
    
    // Open or Create Destination fileURL
    if ( !(_fileID) && !(_fileID=[self _openOrCreateFile:_fileURL error:error]) ) {
        return NO;
    }
    
    // Ensure our session is configured for recording
    AVAudioSession *session = AVAudioSession.sharedInstance;
    if ( [session setCategory:AVAudioSessionCategoryPlayAndRecord error:error] ) {
        [session setPreferredIOBufferDuration:4096.0/kAudRecordingSampleRate error:nil];
        if ( session.isInputGainSettable ) {
            [session setInputGain:1.0 error:nil]; // max, just want to hear it
        }
        printf("Activating audio session...\n");
        return [session setActive:YES error:error];
    }
    
    return NO;
}

- (AudioFileID)_openOrCreateFile:(NSURL *_Nonnull)fileURL error:(NSError**)error {
    NSLog(@"%s", __func__);
    
    // Re-usable iVars
    OSStatus result;
    UInt32 propSize;
    
    // If fileURL exists, we try to open it for appending (this is assumed behaviour)
    CFURLRef url = (__bridge CFURLRef _Nonnull)(fileURL);
    AudioFileID fileID;
    if ( noErr == AudioFileOpenURL(url, kAudioFileReadWritePermission, kAudioFileCAFType, &fileID) ) {
        
        // ASSUMPTION: format matches self->_format
        //   TODO: Check the actual file format here before proceeding (if ever using this in another project!)
        
        // Optimize the file if necessary - this can take a while and in our case probably is never needed
        // because we only use core audio functions to read/write the caf's, but do just in case it's needed
        UInt32 isOptimized = 0;
        propSize = sizeof(isOptimized);
        result = AudioFileGetProperty(fileID, kAudioFilePropertyIsOptimized, &propSize, &isOptimized);
        if ( !AECheckOSStatus(result, "AudioFileGetProperty(kAudioFilePropertyIsOptimized)") || !isOptimized ) {
            result = AudioFileOptimize(fileID);
            if ( !AECheckOSStatus(result, "AudioFileOptimize") ) {
                AudioFileClose(fileID);
                AudErrSet(error, result, @"Could not optimize the audio file, so it cannot be safely appended to.");
                return NULL;
            }
        }
        
        // Set the starting offset "position" (packet count)
        propSize = sizeof(_inStartingPacket);
        result = AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataPacketCount, &propSize, &_inStartingPacket);
        if ( !AECheckOSStatus(result, "AudioFileGetProperty(kAudioFilePropertyAudioDataPacketCount)") ) {
            AudioFileClose(fileID);
            AudErrSet(error, result, @"Couldn't read audio file packet count, so we can't append to it.");
            return NULL;
        }
        
        // Determine length in frames
        AudioFilePacketTableInfo packetInfo;
        propSize = sizeof(packetInfo);
        result = AudioFileGetProperty(fileID, kAudioFilePropertyPacketTableInfo, &propSize, &packetInfo);
        if ( AECheckOSStatus(result, "AudioFileGetProperty(kAudioFilePropertyPacketTableInfo)") ) {
            _frames = packetInfo.mNumberValidFrames;
        } else {
            // Get the file data format
            AudioStreamBasicDescription fileDescription;
            propSize = sizeof(fileDescription);
            result = AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &propSize, &fileDescription);
            if ( !AECheckOSStatus(result, "AudioFileGetProperty(kAudioFilePropertyDataFormat)") ) { // should always succeed!
                AudioFileClose(fileID);
                AudErrSet(error, result, @"Couldn't read the audio file.");
                return NULL;
            }
            _frames = _inStartingPacket * fileDescription.mFramesPerPacket; // will append in same sample rate
        }
        
    } else {
        // Create new file
        _inStartingPacket = 0;
        _frames = 0;
        const AudioStreamBasicDescription *asbd = _format.streamDescription;
        result = AudioFileCreateWithURL(url, kAudioFileCAFType, asbd, kAudioFileFlags_EraseFile, &fileID);
        if ( !AECheckOSStatus(result, "AudioFileCreateWithURL") ) {
            AudErrSet(error, result, @"Couldn't create the audio file.");
            return NULL;
        }
    }
    return fileID;
}

- (void)_startRecordingWithGrantedPermission {
    NSLog(@"%s", __func__);
    
    // Keep a reference to the old engine until the new one is fully running;
    // some kind of crash in notification handling (route change) if this gets
    // released too early
    __block AVAudioEngine *oldEngine = self.engine; // to be released later!
    if ( oldEngine ) {
        [oldEngine pause];
        [oldEngine stop];
        [oldEngine reset];
    }
    self.engine = nil;
    
    // Create engine & nodes
    AVAudioEngine *engine = [AVAudioEngine new];
    AVAudioMixerNode *mixer = [AVAudioMixerNode new]; // mix all inputs to mono
    
    // Attach nodes
    [engine attachNode:mixer];
    
    // Configure input
    AVAudioInputNode *inputNode = (engine) ? engine.inputNode : nil;
    if ( inputNode ) {
        AVAudioFormat *fmt;
        for (AVAudioChannelCount bus = 0; bus < inputNode.numberOfInputs; ++bus) {
            printf("Adding input bus %i\n", (int)bus);
            fmt = [inputNode inputFormatForBus:bus];
            [engine connect:inputNode to:mixer fromBus:bus toBus:bus format:fmt];
        }
    } else {
        printf("\nERROR: no input found?! Does your device have a mic?\n\n");
    }
    
    // Connect nodes
    AVAudioMixerNode *mainMixer = engine.mainMixerNode;
    [engine connect:mixer to:engine.mainMixerNode format:_format]; // causes mixer to down-mix to mono
    mainMixer.outputVolume = 0; // else it will "monitor" audio to speaker/headphones (and may cause feedback loop)
    
    // Install a mono tap
    // CAUTION: format is only respected IF POSSIBLE & no error thrown - tap
    // still works but buffer.format is INCORRECT. You can use a mixer to
    // mitigate the problem, specifically to convert sample rate OR channel
    // count, not both. Testing seemed to show that attempting to change both
    // sample rate & channel count at once (in 1 mixer node) didn't work.
    __typeof__(self) __weak weakSelf = self; // to prevent retain-cycle
    [mixer installTapOnBus:0
                bufferSize:4096 // this is most-likely ignored! (iOS <=10.2) - AVAudioSession IOBufferDuration determines it...
                    format:_format
                     block:
     ^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
         
         printf("•"); // show recording progress to console - not recommended for production!
         
         // Process the audio
         [weakSelf _audioTapCallback:buffer time:when];
         
         // Now we can release the old engine since new one is fully in place
         if ( oldEngine ) { oldEngine = nil; }
     }];
    
    // Start the engine
    self.engine = engine; // engine is now fully ready (though not started yet)
    NSError *error;
    if ( [self.engine startAndReturnError:&error] ) {
        printf("Recording engine started!\n");
    } else {
        printf("Recording engine failed to start: %s\n", error.localizedDescription.UTF8String);
        self.lastError = error;
        [self _messageDelegate:AudRecorderEventError];
    }
}


- (void)_audioTapCallback:(AVAudioPCMBuffer * _Nonnull)buffer
                     time:(AVAudioTime * _Nonnull)when {
    printf("."); // show recording-tap progress to console - not recommended for production!
    
    // Write to file (linear pcm)
    const AudioStreamBasicDescription *asbd = _format.streamDescription;
    UInt32 inNumBytes = buffer.frameLength * asbd->mBytesPerFrame;
    UInt32 ioNumPackets = buffer.frameLength / asbd->mFramesPerPacket;
    void * inBuffer = buffer.audioBufferList->mBuffers[0].mData;
    OSStatus result = AudioFileWritePackets(_fileID,
                                            false,
                                            inNumBytes,
                                            NULL,
                                            _inStartingPacket,
                                            &ioNumPackets,
                                            inBuffer);
    if ( !AECheckOSStatus(result, "AudioFileWritePackets") ) {
        self.lastError = AudErrMake(result, @"Couldn't write to file.");
        [self _messageDelegate:AudRecorderEventError];
        return;
    }
    
    // Update file write offset
    _inStartingPacket += ioNumPackets;
    _frames = _inStartingPacket * asbd->mFramesPerPacket;
    
    // Message the delegate
    [self _messageDelegate:AudRecorderEventProgress];
}

@end










