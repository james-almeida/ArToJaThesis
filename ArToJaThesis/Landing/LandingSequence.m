//
//  LandingSequence.m
//  
//
//  Created by Tony Jin on 3/27/17.
//
//

#import <Foundation/Foundation.h>
#import "LandingSequence.h"
#import "FindTarget.h"
#import "../Frameworks/VideoPreviewer/VideoPreviewer/VideoPreviewer.h"

#import "../DJICameraViewController.h" // for testing purposes


#define TRUE_X 240.0 // need to be calibrated
#define TRUE_Y 180.0

#define weakSelf(__TARGET__) __weak typeof(self) __TARGET__=self
#define weakReturn(__TARGET__) if(__TARGET__==nil)return;

@interface LandingSequence()

    @property(nonatomic, assign) DJICameraViewController* vc;

@end

@implementation LandingSequence

+ (double) getScale: (double) height {
    return height / 2;
}

// set gimbal to point straight downwards
+ (void) moveGimbal:(DJIAircraft*) drone {
    DJIGimbal* gimbal = drone.gimbal;
    
    gimbal.completionTimeForControlAngleAction = 0.1;
    
    DJIGimbalAngleRotation pitchRotation = {YES, 89.9, DJIGimbalRotateDirectionCounterClockwise};
    DJIGimbalAngleRotation rollRotation = {NO, 0, DJIGimbalRotateDirectionClockwise};
    DJIGimbalAngleRotation yawRotation = {NO, 0, DJIGimbalRotateDirectionClockwise};
    [gimbal rotateGimbalWithAngleMode:DJIGimbalAngleModeAbsoluteAngle pitch:pitchRotation roll:rollRotation yaw:yawRotation withCompletion:nil];
}

// testing code: takes a snapshot from the drone's camera
+ (UIImage*) takeSnapshot:(DJICameraViewController*) vc {

    [[VideoPreviewer instance] snapshotPreview:^(UIImage *snapshot) {
        [vc setSnapshot:snapshot];
    }];
    
    return nil;
}

// check to see if drone is currently in air
+ (bool) isLanded: (DJIFlightControllerCurrentState*) droneState {
    return !droneState.isFlying;
}

@end
