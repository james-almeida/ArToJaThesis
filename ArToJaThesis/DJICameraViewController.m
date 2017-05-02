//
//  DJICameraViewController.m
//  ArToJaThesis
//
//  Created by James Almeida on 3/25/17.
//  Copyright © 2017 James Almeida. All rights reserved.
//

#import "DJICameraViewController.h"
#import "VirtualStickView.h"
#import "DemoUtility.h"
#import <DJISDK/DJISDK.h>
#import "Frameworks/VideoPreviewer/VideoPreviewer/VideoPreviewer.h"
#import "LandingSequence.h"
#import "FindTarget.h"

#define weakSelf(__TARGET__) __weak typeof(self) __TARGET__=self
#define weakReturn(__TARGET__) if(__TARGET__==nil)return;


@interface DJICameraViewController ()<DJICameraDelegate, DJISDKManagerDelegate, DJIBaseProductDelegate, DJIFlightControllerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *captureBtn;
@property (weak, nonatomic) IBOutlet UIButton *recordBtn;
@property (weak, nonatomic) IBOutlet UIButton *processBtn;
@property (weak, nonatomic) IBOutlet UISegmentedControl *changeWorkModeSegmentControl;
@property (weak, nonatomic) IBOutlet UIView *fpvPreviewView;
@property (assign, nonatomic) BOOL isRecording;
@property (weak, nonatomic) IBOutlet UIImageView* imgView;
@property (weak, nonatomic) IBOutlet UITextView* coordTextView;



- (IBAction)captureAction:(id)sender;
- (IBAction)recordAction:(id)sender;
- (IBAction)changeWorkModeAction:(id)sender;

@property (assign, nonatomic) float mXVelocity;
@property (assign, nonatomic) float mYVelocity;
@property (assign, nonatomic) float mYaw;
@property (assign, nonatomic) float mThrottle;


@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *endButton;
- (IBAction) onStartButtonClicked:(id)sender;
@property (strong, nonatomic) IBOutlet UILabel *missionStatus;
@property (strong, nonatomic) IBOutlet UILabel *homeCoordLabel;
@property (strong, nonatomic) IBOutlet UILabel *droneCoordLabel;


@property(nonatomic, assign) DJIFlightControllerCurrentState* droneState;
@property(nonatomic, assign) DJIFlightController* flightController;
@property(nonatomic, assign) CLLocationCoordinate2D droneLocation;
@property(nonatomic, assign) DJIAircraftRemainingBatteryState batteryRemaining;
@property(nonatomic, assign) BOOL shouldElevate;
@property(nonatomic, assign) BOOL shouldLand;
@property(nonatomic, assign) int flightLoopCount;
@property(nonatomic, assign) int counter;
@property(nonatomic, assign) NSTimeInterval SLEEP_TIME_BTWN_STICK_COMMANDS;

@end


@implementation DJICameraViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.SLEEP_TIME_BTWN_STICK_COMMANDS = 0.06;

    [[VideoPreviewer instance] setView: self.fpvPreviewView];
    [self registerApp];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"DJISimulator Demo";
    
    self.imgView.image = nil;
}

-(void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    DJIFlightController* fc = self.flightController; //[DemoUtility fetchFlightController];
    if (fc) {
        fc.delegate = self;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[VideoPreviewer instance] setView:nil];
    
    DJIFlightController* fc = self.flightController; //[DemoUtility fetchFlightController];
    if (fc) {
        fc.delegate = self;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}






#pragma mark Custom Camera Methods
- (DJICamera*) fetchCamera {
    
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).camera;
    }else if ([[DJISDKManager product] isKindOfClass:[DJIHandheld class]]){
        return ((DJIHandheld *)[DJISDKManager product]).camera;
    }
    
    return nil;
}

- (void)showAlertViewWithTitle:(NSString *)title withMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)registerApp
{
    NSString *appKey = @"25ee96bfb87e51821f2fede1";
    [DJISDKManager registerApp:appKey withDelegate:self];
}

- (NSString *)formattingSeconds:(int)seconds
{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:seconds];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"mm:ss"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSString *formattedTimeString = [formatter stringFromDate:date];
    return formattedTimeString;
}



#pragma mark - Custom exit/ending methods

- (void) autoLeaveVirtualStickControl:(DJIFlightController*) fc {
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    self.imgView.image = nil;
    [fc disableVirtualStickControlModeWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Leave Virtual Stick Mode Failed: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            double delayInSeconds = 5.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self autoLeaveVirtualStickControl:fc];
            });
        } else {
            [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Leave Virtual Stick Mode Succeeded: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
        }
    }];
}

- (IBAction)onEndButtonClicked:(id)sender {
    DJIFlightController* fc = self.flightController; //[DemoUtility fetchFlightController];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    
    if (fc) {
        [self autoLeaveVirtualStickControl:fc];
        
    }
    else
    {
        [DemoUtility showAlertViewWithTitle:nil message:@"Component not exist." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
    }
}



#pragma mark - Custom Methods

/* Should perform the following upon tapping "START MISSION":
 * * * 1) Fetch flight controller without error
 * * * 2) Set the control modes for yaw, pitch, roll, and vertical control
 * * * 3) Put drone in virtual stick control mode
 */
- (IBAction)onStartButtonClicked:(id)sender {
    DJIFlightController* fc = self.flightController; //[DemoUtility fetchFlightController];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];

    if (fc) {
        [self autoEnterVirtualStickControl:fc];
        
    }
    else
    {
        [DemoUtility showAlertViewWithTitle:nil message:@"Component not exist." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
    }
    
}


/* This method is called initially when "START MISSION" is tapped. Additionally, every time the drone turns off and on again (signaled by battery charge drastically increasing). 
 * Should perform the following upon being called:
 * * * 1) Enable virtual stick control mode without failure
 * * *      -> If there is error, continue to call self until success
 * * * 2) Begin takeoff/flight sequence
 */
- (void) autoEnterVirtualStickControl:(DJIFlightController*) fc {
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    
    fc.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystemBody;
    fc.yawControlMode = DJIVirtualStickYawControlModeAngularVelocity;
    fc.rollPitchControlMode = DJIVirtualStickRollPitchControlModeVelocity;
    fc.verticalControlMode = DJIVirtualStickVerticalControlModeVelocity;
    //[fc setVirtualStickAdvancedModeEnabled:TRUE];
    
    [fc enableVirtualStickControlModeWithCompletion:^(NSError *error) {
        if (error) {
            [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Enter Virtual Stick Mode Failed: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            double delayInSeconds = 5.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self autoEnterVirtualStickControl:fc];
            });
        }
        else
        {
            [self autoTakeoff:fc];
//            [DemoUtility showAlertViewWithTitle:nil message:@"Enter Virtual Stick Mode:Succeeded, attempting takeoff." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];

            //[self landDrone:_droneState drone:((DJIAircraft *)[DJISDKManager product])];
        }
    }];

}

/* Will be called automatically by autoEnterVirtualStickControl().
 * Should perform the following upon being called:
 * * * 1) Attempt to take off
 * * *      -> If there is error, continue to call self until success
 * * * 2) Call the virtualPilot method
 */
- (void) autoTakeoff:(DJIFlightController*) fc {
    _shouldElevate = true;
    _shouldLand = false;
    
    [fc takeoffWithCompletion:^(NSError *error) {
        if (error) {
            double delayInSeconds = 5.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self autoTakeoff:fc];
            });
                
        } else {
            [self virtualPilot:fc];
//            [NSThread sleepForTimeInterval:3];
//            [self landDrone:_droneState drone:((DJIAircraft *)[DJISDKManager product])];
        }
    }];

}


/* Will be called automatically after a successful takeoff.
 * Should perform the following upon being called:
 * * * 1) Check battery level
 * * *      -> If less than 20%, begin landing sequence
 * * * 2) Fly to designated height
 * * * 3) Set self to correct orientation (TESTING REQUIRED)
 * * * 4) Begin flight loop --> While battery remains above "LOW",
 * * *      -  Fly in each direction a slow speed for 6 seconds
 
 */
- (void) virtualPilot:(DJIFlightController*) fc {
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    
    // Elevate drone for 6 seconds at a rate of ~10Hz
    if (_shouldElevate) {
        [self leftStickUp:200];
    }
    
    [self bothSticksNeutral];
    [NSThread sleepForTimeInterval:2];
    
    [self rightStickUp:100];
    
    [self bothSticksNeutral];
    [NSThread sleepForTimeInterval:2];
    
    [self rightStickDown:120];
    
    [self bothSticksNeutral];
    [NSThread sleepForTimeInterval:2];
    
//    [self rightStickLeft:100];
//    
//    [self bothSticksNeutral];
//    [NSThread sleepForTimeInterval:2];
//    
//    
//    [self rightStickRight:120];
//
//
//    [self bothSticksNeutral];
//    [NSThread sleepForTimeInterval:2];
    
    _flightLoopCount += 1;
    self.missionStatus.text = @"About to begin landing";
    
    if (_batteryRemaining == DJIAircraftRemainingBatteryStateNormal) {
        // Begin landing sequence
        fc.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystemGround;
        [NSThread sleepForTimeInterval:1];
        self.missionStatus.text = @"Moving Home";
        [self moveBackToHome];
        [NSThread sleepForTimeInterval:10];
        fc.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystemBody;
        [LandingSequence moveGimbal:((DJIAircraft*)[DJISDKManager product])];
//        [NSThread sleepForTimeInterval:15];
//        self.missionStatus.text = @"Landing";
//        [self landDrone:_droneState drone:((DJIAircraft *)[DJISDKManager product])];
//        
//        [self bothSticksNeutral];
//        
//        // once landing is done, wait for battery to be > 0.75
//        while (_droneState.remainingBattery != DJIAircraftRemainingBatteryStateLow) {
//            [NSThread sleepForTimeInterval:5.0];
//            [DemoUtility showAlertViewWithTitle:nil message:@"Battery too low to fly." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
//        }
//        _shouldElevate = true;
//        [self virtualPilot:fc];
    }
    
    else {
        _shouldElevate = false;
        [self virtualPilot:fc];
    }
}

/*
TODO:
    Clean up UI
 */

- (void) moveInDirection:(double) x withY:(double) y
{
    CGPoint dir;
    
    double xVal = fabs(x);
    double yVal = fabs(y);
    float total = MAX(xVal, yVal);
    
    for (int i=0; i<total; i++) {
        if (i < xVal)
            dir.x = (0.03) * [self getStickScale:i withLimit:(xVal)] * (x / xVal);
        if (i < yVal)
            dir.y = (0.03) * [self getStickScale:i withLimit:(yVal)] * (y / yVal);
        [self setXVelocity:dir.y andYVelocity:dir.x];
        
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
    }
}

/*
 * Gets the coordinate of the drone and where it took off from, 
 *
 */
- (void) moveBackToHome
{
    CLLocationCoordinate2D homeCoord = _droneState.homeLocation;
    CLLocationCoordinate2D droneCoord = _droneState.aircraftLocation;
    
    MKMapPoint point1 = MKMapPointForCoordinate(homeCoord);
    MKMapPoint point2 = MKMapPointForCoordinate(droneCoord);
    CLLocationDistance distance = MKMetersBetweenMapPoints(point1, point2);
    double longDiff = _droneState.aircraftLocation.longitude - _droneState.homeLocation.longitude;
    double latDiff = _droneState.aircraftLocation.latitude - _droneState.homeLocation.latitude;
    BOOL shouldFlyEast = ((longDiff) <= 0);
    BOOL shouldFlySouth = ((latDiff) >= 0);
    double longProp = (fabs(longDiff))/(fabs(longDiff) + fabs(latDiff));
    double latProp = (fabs(latDiff))/(fabs(longDiff) + fabs(latDiff));
    
    if (shouldFlyEast) {
        [self rightStickRight:(int) (500*longProp*distance)];
    }
    else {
        [self rightStickLeft:(int) (500*longProp*distance)];
    }
    if (shouldFlySouth) {
        [self rightStickDown:(int) (500*latProp*distance)];
    }
    else {
        [self rightStickUp:(int) (500*latProp*distance)];
    }
    return;
    
}

- (void)bothSticksNeutral
{
    CGPoint dir;
    
    dir.x = 0;
    dir.y = 0;
    
    [self setThrottle:dir.y andYaw:dir.x];
    [self setXVelocity:-dir.y andYVelocity:dir.x];
}

- (double) getStickScale:(int) prog withLimit:(double) total {
    return 2.0 * (total/2.0 - fabs(prog-(total/2))) / total;
}


- (void)rightStickUp:(int) total
{
    CGPoint dir;
    
    for (int i=0; i<total; i++) {
    
        dir.x = 0;
        dir.y = (-0.2) * [self getStickScale:i withLimit:total];
        [self setXVelocity:-dir.y andYVelocity:dir.x];
        
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
    }
}


- (void)rightStickDown:(int) total
{
    CGPoint dir;
    
    for (int i=0; i<total; i++) {
        
        dir.x = 0;
        dir.y = (0.2) * [self getStickScale:i withLimit:total];
        [self setXVelocity:-dir.y andYVelocity:dir.x];
        
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
    }
}

- (void)rightStickRight:(int) total
{
    CGPoint dir;
    
    for (int i=0; i<total; i++) {
        
        dir.x = (0.2) * [self getStickScale:i withLimit:total];
        dir.y = 0;
        [self setXVelocity:-dir.y andYVelocity:dir.x];
        
        
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
    }
}

- (void)rightStickLeft:(int) total
{
    CGPoint dir;
    
    for (int i=0; i<total; i++) {
        dir.x = (-0.2) * [self getStickScale:i withLimit:total];
        dir.y = 0;
        [self setXVelocity:-dir.y andYVelocity:dir.x];
        
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
    }
}

- (void)leftStickUp:(int) total
{
    CGPoint dir;
    for (int i=0; i<total; i++) {
        
        dir.x = 0;
        dir.y = (0.4) * [self getStickScale:i withLimit:total];
        [self setThrottle:dir.y andYaw:dir.x];
        
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
    }
}

- (void)leftStickDown:(int) total
{
    CGPoint dir;
    for (int i=0; i<total; i++) {
        
        dir.x = 0;
        dir.y = (-0.4) * [self getStickScale:i withLimit:total];
        [self setThrottle:dir.y andYaw:dir.x];
        
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
    }
}


- (void)leftStickDownGentle:(int) total
{
    CGPoint dir;
    for (int i=0; i<total; i++) {
        // 2.0 * (total/2.0 - fabs(prog-(total/2))) / total;
        dir.x = 0;
        dir.y = (-0.8*i*1.0/total); //* [self getStickScale:i withLimit:total];
        [self setThrottle:dir.y andYaw:dir.x];
        
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
    }
}

- (void)leftStickRight:(int) total
{
    CGPoint dir;
    
    for (int i=0; i<total; i++) {
        
        dir.x = (0.05) * [self getStickScale:i withLimit:total];
        dir.y = 0;
        [self setThrottle:dir.y andYaw:dir.x];
        
        
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
    }
}

- (void)leftStickLeft:(int) total
{
    CGPoint dir;
    for (int i=0; i<total; i++) {
        
        dir.x = (-0.05) * [self getStickScale:i withLimit:total];
        dir.y = 0;
        [self setThrottle:dir.y andYaw:dir.x];
        
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
    }
}

-(void) setThrottle:(float)y andYaw:(float)x
{
    self.mThrottle = y * 2;
    self.mYaw = x * 30;
    
    [self updateVirtualStick];
}

-(void) setXVelocity:(float)x andYVelocity:(float)y {
    self.mXVelocity = x * DJIVirtualStickRollPitchControlMaxVelocity;
    self.mYVelocity = y * DJIVirtualStickRollPitchControlMaxVelocity;
    [self updateVirtualStick];
}

-(void) updateVirtualStick
{
    DJIVirtualStickFlightControlData ctrlData = {0};
    ctrlData.pitch = self.mYVelocity;
    ctrlData.roll = self.mXVelocity;
    ctrlData.yaw = self.mYaw;
    ctrlData.verticalThrottle = self.mThrottle;
    DJIFlightController* fc = self.flightController; //[DemoUtility fetchFlightController];
    if (fc && fc.isVirtualStickControlModeAvailable) {
        [fc sendVirtualStickFlightControlData:ctrlData withCompletion:nil];
    }
}

- (double) landingStep:(UIImage*) snapshot andScale:(int)count{
    
    NSInteger TRUE_X = 240;
    NSInteger TRUE_Y = 160; // camera is not perfectly centered
    DJIFlightControllerCurrentState* droneState = _droneState;
    
    // find center on image
    NSArray* coords = [FindTarget findTargetCoordinates: snapshot viewController:nil];
    
    int rx = (int) [[coords objectAtIndex:0] integerValue];
    int ry = (int) [[coords objectAtIndex:1] integerValue];
    
    // did not find pixel
    if (rx == 0 && ry == 0)
        return 100.0;
     
     // calculate error
     NSInteger errX = TRUE_X - rx;
     NSInteger errY = TRUE_Y - ry;
    
     // get scale
     double height;
     if (droneState.isUltrasonicBeingUsed)
         height = droneState.ultrasonicHeight;
     else
         height = droneState.altitude; // very inaccurate

    
    double scale = 0.25*(count/50.0); //[self getScale:height];
    
    // check rotation
//    double angle = [self getAngle:coords] * 0.1;
//    if (angle > 0)
//        [self leftStickLeft:angle];
//    else
//        [self leftStickRight:angle];

    // move drone
    double moveX = errX*scale*-1; // these work when drone faces ELE Lab Door
    double moveY = errY*scale;

    if (fabs(moveX) <= 3)
        moveX = 0.0;
    if (fabs(moveY) <= 3)
        moveY = 0.0;
    
    if (height < 0.65) {
        errX = 0;
        errY = 0;
    }
    else if (fabs(moveX) > 0.1 || fabs(moveY) > 0.1)
        [self moveInDirection:moveX withY:moveY];
    
    
    NSString* output = [NSString stringWithFormat:@"Location: (%f, %f)\n Height: %f",moveX, moveY, height];
    self.coordTextView.text = output;
    
    if (height >= 0.6)
        [self bothSticksNeutral];
    return sqrt((errX * errX) + (errY * errY));
}

-(double) getAngle:(NSArray*) coords
{
    int rx = (int) [[coords objectAtIndex:0] integerValue];
    int ry = (int) [[coords objectAtIndex:1] integerValue];
    
    int bx = (int) [[coords objectAtIndex:2] integerValue];
    int by = (int) [[coords objectAtIndex:3] integerValue];
    
    double dx = bx - rx + 0.01;
    double dy = by - ry + 0.01;
    
    double angle = atan2(dy, dx) * 180 / 3.14;  // current angle in degrees
    
    if (dx > dy)
        angle = 180 - angle;                    // atan limit betwen (-90, 90)
    
    return (90 - angle);                        // get angle away from 90 degrees
}


- (void) landDrone:(DJIFlightControllerCurrentState*) droneState drone:(DJIAircraft*) drone {
    
    // point gimbal straight downwards
    [LandingSequence moveGimbal:drone];
    [NSThread sleepForTimeInterval:0.1];
    
    [self landDroneRecursive:droneState count:50];
}

-(void) landDroneRecursive:(DJIFlightControllerCurrentState*) droneState count:(int) count {
    if (count == 0) {
        return;
    }
    
    [[VideoPreviewer instance] snapshotPreview:^(UIImage *snapshot) {
        self.missionStatus.text = [NSString stringWithFormat:@"%d", count];
        double error = [self landingStep:snapshot andScale:count];
        [NSThread sleepForTimeInterval:0.75];
        // If we're within 16 pixels of the target, we can lower
        if (error < 1.0) {
            [self leftStickDownGentle:60];
            [NSThread sleepForTimeInterval:2];
            [self landDroneRecursive:droneState count:0];
        }
        else if (error < 30.0) {
            [self leftStickDown:10*(50.0/count)];
            [NSThread sleepForTimeInterval:.2];
            [self landDroneRecursive:droneState count:count-5];
        }
        else {
            [self landDroneRecursive:droneState count:count-1];
        }
    }];
    
}

#pragma mark DJISDKManagerDelegate Method

-(void) sdkManagerProductDidChangeFrom:(DJIBaseProduct* _Nullable) oldProduct to:(DJIBaseProduct* _Nullable) newProduct
{
    if (newProduct) {
        [newProduct setDelegate:self];
        DJICamera* camera = [self fetchCamera];
        if (camera != nil) {
            camera.delegate = self;
        }
        
        self.flightController = [DemoUtility fetchFlightController];
        if (self.flightController) {
            self.flightController.delegate = self;
        }
    }
}

- (void)sdkManagerDidRegisterAppWithError:(NSError *)error
{
    NSString* message = @"Register App Successed!";
    if (error) {
        message = @"Register App Failed! Please enter your App Key and check the network.";
    }else
    {
        NSLog(@"registerAppSuccess");
        
        [DJISDKManager startConnectionToProduct];
        [[VideoPreviewer instance] start];
    }
    
    [self showAlertViewWithTitle:@"Register App" withMessage:message];
}



#pragma mark - DJIBaseProductDelegate Method

-(void) componentWithKey:(NSString *)key changedFrom:(DJIBaseComponent *)oldComponent to:(DJIBaseComponent *)newComponent {
    
    if ([key isEqualToString:DJICameraComponent] && newComponent != nil) {
        __weak DJICamera* camera = [self fetchCamera];
        if (camera) {
            [camera setDelegate:self];
        }
    }
}


#pragma mark - DJICameraDelegate
-(void)camera:(DJICamera *)camera didReceiveVideoData:(uint8_t *)videoBuffer length:(size_t)size
{
    [[VideoPreviewer instance] push:videoBuffer length:(int)size];
}

-(void) camera:(DJICamera*)camera didUpdateSystemState:(DJICameraSystemState*)systemState
{
    self.isRecording = systemState.isRecording;
    
    if (self.isRecording) {
        [self.recordBtn setTitle:@"Stop Record" forState:UIControlStateNormal];
    }else
    {
        [self.recordBtn setTitle:@"Start Record" forState:UIControlStateNormal];
    }
    
    //Update UISegmented Control's state
    if (systemState.mode == DJICameraModeShootPhoto) {
        [self.changeWorkModeSegmentControl setSelectedSegmentIndex:0];
    }else if (systemState.mode == DJICameraModeRecordVideo){
        [self.changeWorkModeSegmentControl setSelectedSegmentIndex:1];
    }
    
}



#pragma mark DJIFlightControllerDelegate

- (void)flightController:(DJIFlightController *)fc didUpdateSystemState:(DJIFlightControllerCurrentState *)state
{
    self.counter += 1;
    self.droneLocation = state.aircraftLocation;
    self.batteryRemaining = state.remainingBattery;
    self.droneState = state;
    self.homeCoordLabel.text = [NSString stringWithFormat:@"HOME: lat %f, long %f", state.homeLocation.latitude, state.homeLocation.longitude];
    self.droneCoordLabel.text = [NSString stringWithFormat:@"DRONE: lat %f, long %f", self.droneLocation.latitude, self.droneLocation.longitude];
}

#pragma mark - IBAction Methods

- (IBAction)captureAction:(id)sender {
    
    if (![self fetchCamera]) {
        [self setSnapshot:[UIImage imageNamed:@"target"]];
        return;
    }
    
    [LandingSequence moveGimbal:((DJIAircraft*)[DJISDKManager product])];
    
    
    [LandingSequence takeSnapshot:self];

}

- (void)setSnapshot:(UIImage*) image {
    self.imgView.image = image;
}


- (IBAction)processAction:(id)sender {
    
    // get captured image
    UIImage* target = self.imgView.image;
    
    // use test image otherwise
    if (target == nil)
        target = [UIImage imageNamed: @"target"];
    
    // get coordinates
    NSArray* coords = [FindTarget findTargetCoordinates:target viewController:self];
    
    // display result, with highlighted center
    UIImage* result = [FindTarget getImageMask:target];
    result = [FindTarget imageWithColor:result location:coords];
    self.imgView.image = result;
    
    // print coordinates
    NSString* output = [NSString stringWithFormat:@"Location: (%ld, %ld)\n",[coords[0] integerValue], [coords[1] integerValue]];
    self.coordTextView.text = output;
}

- (IBAction)recordAction:(id)sender {
    
    __weak DJICameraViewController *weakSelf = self;
    
    __weak DJICamera* camera = [self fetchCamera];
    if (camera) {
        
        if (self.isRecording) {
            
            [camera stopRecordVideoWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [weakSelf showAlertViewWithTitle:@"Stop Record Video Error" withMessage:error.description];
                }
            }];
            
        }else
        {
            [camera startRecordVideoWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [weakSelf showAlertViewWithTitle:@"Start Record Video Error" withMessage:error.description];
                }
            }];
        }
        
    }
}

- (IBAction)changeWorkModeAction:(id)sender {
    
    __weak DJICameraViewController *weakSelf = self;
    UISegmentedControl *segmentControl = (UISegmentedControl *)sender;
    
    __weak DJICamera* camera = [self fetchCamera];
    
    if (camera) {
        
        if (segmentControl.selectedSegmentIndex == 0) { //Take photo
            
            [camera setCameraMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [weakSelf showAlertViewWithTitle:@"Set DJICameraModeShootPhoto Failed" withMessage:error.description];
                }
                
            }];
            
        }else if (segmentControl.selectedSegmentIndex == 1){ //Record video
            
            [camera setCameraMode:DJICameraModeRecordVideo withCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [weakSelf showAlertViewWithTitle:@"Set DJICameraModeRecordVideo Failed" withMessage:error.description];
                }
                
            }];
            
        }
    }
    
}

@end
