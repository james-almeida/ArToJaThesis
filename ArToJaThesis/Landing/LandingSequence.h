//
//  LandingSequence.h
//  ArToJaThesis
//
//  Created by Tony Jin on 3/27/17.
//  Copyright © 2017 James Almeida. All rights reserved.
//

#import <DJISDK/DJISDK.h>

#ifndef LandingSequence_h
#define LandingSequence_h


@class DJICameraViewController;

@protocol LandingSequenceDelegate <NSObject>
@optional
+ (void) setSnapshot:(UIImage *)snapshot;
+ (void) landingStep:(UIImage*) snapshot;
@end

@interface LandingSequence : NSObject

+ (void) landDrone:(DJIFlightControllerCurrentState*) droneState drone:(DJIAircraft*) drone;
+ (bool) isLanded: (DJIFlightControllerCurrentState*) droneState ;
+ (void) moveGimbal:(DJIAircraft*) drone;
+ (UIImage*) takeSnapshot:(DJICameraViewController*) vc;

    
@end

#endif /* LandingSequence_h */
