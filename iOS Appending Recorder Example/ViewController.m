//
//  ViewController.m
//  iOS Appending Recorder Example
//
//  Created by Leo Thiessen on 2017-08-09.
//  Copyright © 2017 Leo Thiessen. All rights reserved.
//

#import "ViewController.h"
#import "AudioAppendingRecorder.h"
#import <AVFoundation/AVFoundation.h>



@interface ViewController () <AudioAppendingRecorderDelegate, AVAudioPlayerDelegate>
@property (nonatomic, strong) AudioAppendingRecorder *recorder;
@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, strong) NSURL *fileURL;
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIButton *buttonRecord;
@end



@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.fileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"file.caf"]];
    [NSFileManager.defaultManager removeItemAtURL:self.fileURL error:nil];
}

- (IBAction)didTapButton:(UIButton *)sender {
    if ( self.recorder ) {
        [self.recorder stop];
    } else {
        NSError *error;
        AudioAppendingRecorder *recorder = [[AudioAppendingRecorder alloc] initWithDestinationFile:self.fileURL error:&error];
        if ( error ) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ERROR: init recorder"
                                                                           message:error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [alert dismissViewControllerAnimated:YES completion:NULL];
            }]];
            [self presentViewController:alert animated:YES completion:NULL];
        } else {
            self.recorder = recorder;
            recorder.delegate = self;
            [self.buttonRecord setTitle:@"Stop Recording" forState:UIControlStateNormal];
            [recorder record];
            printf("Started recording: %s\n", [self.recorder description].UTF8String);
        }
    }
}



#pragma mark - <AudioAppendingRecorderDelegate>

- (void)recorder:(AudioAppendingRecorder *)recorder event:(AudRecorderEvent)event {
    switch ( event ) {
        case AudRecorderEventProgress: {
            self.label.text = [NSString stringWithFormat:@"%.1f seconds", recorder.duration];
            break;
        }
        case AudRecorderEventStopped: {
            printf("Completed!\n");
            self.recorder = nil;
            NSError *error;
            self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:self.fileURL error:&error];
            if ( error ) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ERROR: play new file"
                                                                               message:error.localizedDescription
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                    [alert dismissViewControllerAnimated:YES completion:NULL];
                }]];
                [self presentViewController:alert animated:YES completion:NULL];
            } else {
                self.player.delegate = self;
                __typeof__(self) __weak weakSelf = self;
                NSString *msg = @"Playback has started (turn your mute off and volume up).";
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Completed!"
                                                                               message:msg
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss/Stop Playing" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [alert dismissViewControllerAnimated:YES completion:NULL];
                    [weakSelf.player stop];
                    weakSelf.player = nil;
                }]];
                [self presentViewController:alert animated:YES completion:^{
                    [weakSelf.player play];
                }];
            }
            [self _updateRecordButtonTitle];
            break;
        }
        case AudRecorderEventError: {
            NSString *errDesc = self.recorder.lastError.localizedDescription;
            printf("Failed! Error: %s\n", errDesc.UTF8String);
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ERROR: recording"
                                                                           message:errDesc
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [alert dismissViewControllerAnimated:YES completion:NULL];
            }]];
            [self presentViewController:alert animated:YES completion:NULL];
            self.recorder = nil;
            [self _updateRecordButtonTitle];
            break;
        }
    }
}

- (void)_updateRecordButtonTitle {
    if ( [NSFileManager.defaultManager fileExistsAtPath:self.fileURL.path] ) {
        [self.buttonRecord setTitle:@"Resume Recording" forState:UIControlStateNormal];
    } else {
        [self.buttonRecord setTitle:@"Record" forState:UIControlStateNormal];
    }
}



#pragma mark - <AVAudioPlayerDelegate>

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    self.player = nil;
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ERROR: player decode"
                                                                   message:error.localizedDescription
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [alert dismissViewControllerAnimated:YES completion:NULL];
    }]];
    [self presentViewController:alert animated:YES completion:NULL];
    self.player = nil;
}

@end
