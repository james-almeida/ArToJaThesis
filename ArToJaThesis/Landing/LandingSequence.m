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


@implementation LandingSequence

+ (double) getScale: (double) height {
    return height / 2; // some magic equation
}

+ (UIImage*) takeSnapshot: (DJICamera*) camera {
    // align gimbal
    
    // take picture
    [camera setCameraMode:DJICameraModeShootPhoto withCompletion:nil];
    [camera startShootPhoto:DJICameraShootPhotoModeSingle withCompletion:nil];
    
    // download picture
    
    return NULL;
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
}

+ (void) landDrone:(DJIFlightControllerCurrentState*) droneState camera:(DJICamera*) camera {
    UIImage* snapshot;
    
    while (![self isLanded:droneState]) {
        snapshot =  [self takeSnapshot:camera];
        [self landingStep: droneState snapshot:snapshot];
    }
}

+ (bool) isLanded: (DJIFlightControllerCurrentState*) droneState{
    return !droneState.isFlying;
}

@end
