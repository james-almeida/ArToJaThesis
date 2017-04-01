//
//  LandingSequence.m
//  
//
//  Created by Tony Jin on 3/27/17.
//
//

#import <Foundation/Foundation.h>
#import "LandingSequence.h"
#import "Stitching.h"

#define TRUE_X 1000.0 // need to be calibrated
#define TRUE_Y 1000.0

#define weakSelf(__TARGET__) __weak typeof(self) __TARGET__=self
#define weakReturn(__TARGET__) if(__TARGET__==nil)return;


@implementation LandingSequence

//- (void)showAlertViewWithTitle:(NSString *)title withMessage:(NSString *)message
//{
//    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
//    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
//    [alert addAction:okAction];
//    [self presentViewController:alert animated:YES completion:nil];
//}


+ (double) getScale: (double) height {
    return height / 2; // some magic equation
}

+ (void) moveGimbal:(DJIAircraft*) drone {
    // set gimbal to point straight downwards
    DJIGimbal* gimbal = drone.gimbal;
    
    gimbal.completionTimeForControlAngleAction = 0.1;
    
    
    DJIGimbalAngleRotation pitchRotation = {YES, 89.9, DJIGimbalRotateDirectionCounterClockwise};
    DJIGimbalAngleRotation rollRotation = {NO, 0, DJIGimbalRotateDirectionClockwise};
    DJIGimbalAngleRotation yawRotation = {NO, 0, DJIGimbalRotateDirectionClockwise};
    [gimbal rotateGimbalWithAngleMode:DJIGimbalAngleModeAbsoluteAngle pitch:pitchRotation roll:rollRotation yaw:yawRotation withCompletion:nil];
}

+ (UIImage*) takeSnapshot: (DJICamera*)camera {
    
    __block NSMutableData* downloadedFileData;
    __block UIImage* output;
    
    DJIPlaybackManager* playback = camera.playbackManager;
    
    // remove previous images
//    [camera setCameraMode:DJICameraModePlayback withCompletion:nil];
//    [playback selectAllFiles];
//    [playback deleteAllSelectedFiles];

    // align gimbal
    
    
    
    // take picture
    [camera setCameraMode:DJICameraModeShootPhoto withCompletion:nil];
    [camera startShootPhoto:DJICameraShootPhotoModeSingle withCompletion:nil];
    
    // download picture
    [camera setCameraMode:DJICameraModePlayback withCompletion:nil];
    [playback selectAllFiles]; // there should only be one
    
    weakSelf(target);
    
    [playback downloadSelectedFilesWithPreparation:
        ^(NSString * _Nullable fileName, DJIDownloadFileType fileType, NSUInteger fileSize, BOOL * _Nonnull skip) {
            downloadedFileData = [NSMutableData new];
            
        } process:^(NSData * _Nullable data, NSError * _Nullable error) {
            weakReturn(target);
            [downloadedFileData appendData:data];
            
        } fileCompletion:^{
            weakReturn(target);
            output = [UIImage imageWithData:downloadedFileData];
            
        } overallCompletion:^(NSError * _Nullable error) { /* do nothing */ }];
    
    
    return output;
}


+ (void) landingStep:(DJIFlightControllerCurrentState*) droneState snapshot:(UIImage*) snapshot{
    
    // find center on image
    NSArray* coords = [Stitching findTargetCoordinates: snapshot];
    
    // check rotation
    // rotate appropriate
    
    // calculate error
    NSInteger errX = [[coords objectAtIndex:0] integerValue] - TRUE_X;
    NSInteger errY = [[coords objectAtIndex:1] integerValue] - TRUE_Y;
    
    // get scale
    double height;
    if (droneState.isUltrasonicBeingUsed)
        height = droneState.ultrasonicHeight;
    else
        height = droneState.altitude; // very inaccurate
    
    double getScale = [self getScale:height];
    
    // move drone
    double moveX = errX * getScale;
    double moveY = errY * getScale;
    
    // decrease height
    // drop 2 meters
}


+ (void) landDrone:(DJIFlightControllerCurrentState*) droneState drone:(DJIAircraft*) drone {
    UIImage* snapshot;
    
    // point gimbal straight downwards
    [self moveGimbal:drone];
    
    // take pictures while landing
    while (![self isLanded:droneState]) {
        snapshot =  [self takeSnapshot:drone.camera];
        [self landingStep: droneState snapshot:snapshot];
    }
}

+ (bool) isLanded: (DJIFlightControllerCurrentState*) droneState{
    return !droneState.isFlying;
}

@end
