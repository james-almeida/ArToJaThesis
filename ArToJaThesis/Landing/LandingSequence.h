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

@interface LandingSequence : NSObject

+ (void) landDrone:(DJIFlightControllerCurrentState*) droneState camera:(DJICamera*) camera;
+ (bool) isLanded: (DJIFlightControllerCurrentState*) droneState ; 
    
@end

#endif /* LandingSequence_h */
