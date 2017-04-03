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
#import "../Frameworks/VideoPreviewer/VideoPreviewer/VideoPreviewer.h"

#import "../DJICameraViewController.h" // for testing purposes


#define TRUE_X 240.0 // need to be calibrated
#define TRUE_Y 180.0

#define weakSelf(__TARGET__) __weak typeof(self) __TARGET__=self
#define weakReturn(__TARGET__) if(__TARGET__==nil)return;


@implementation LandingSequence

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

//+ (UIImage*) takeSnapshot {
//    __block UIImage* output;
//    
//    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
//        //Background Thread
//        dispatch_async(dispatch_get_main_queue(), ^(void){
//            //Run UI Updates
//        });
//    });
//    
//    [[VideoPreviewer instance] snapshotPreview:^(UIImage *snapshot) {
//        
//        dispatch_async(dispatch_get_main_queue(), ^(void){
//            //Run UI Updates
//            [DJICameraViewController setSnapshot:snapshot];
//        });
//        
//    }];
//    
//    
//    return nil;
//}

+ (UIImage*) takeSnapshot {
    __block UIImage* output;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    [[VideoPreviewer instance] snapshotPreview:^(UIImage *snapshot) {
        dispatch_semaphore_signal(sema);
        output = snapshot;
        
    }];
    
    
    while (dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    }
    
    return output; // hxw = 360x480
}


+ (void) landingStep:(DJIFlightControllerCurrentState*) droneState snapshot:(UIImage*) snapshot{
    /*
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
     
     */
}


+ (void) landDrone:(DJIFlightControllerCurrentState*) droneState drone:(DJIAircraft*) drone {
    UIImage* snapshot;
    
    // point gimbal straight downwards
    [self moveGimbal:drone];
    
    // take pictures while landing
    while (![self isLanded:droneState]) {
        snapshot =  [self takeSnapshot];
        [self landingStep: droneState snapshot:snapshot];
        sleep(2);
    }
}

+ (bool) isLanded: (DJIFlightControllerCurrentState*) droneState{
    return !droneState.isFlying;
}

@end
