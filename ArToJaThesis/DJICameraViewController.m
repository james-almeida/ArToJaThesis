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
#import "Stitching.h"

#define weakSelf(__TARGET__) __weak typeof(self) __TARGET__=self
#define weakReturn(__TARGET__) if(__TARGET__==nil)return;


@interface DJICameraViewController ()<DJICameraDelegate, DJISDKManagerDelegate, DJIBaseProductDelegate, DJIFlightControllerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *captureBtn;
@property (weak, nonatomic) IBOutlet UIButton *recordBtn;
@property (weak, nonatomic) IBOutlet UIButton *processBtn;
@property (weak, nonatomic) IBOutlet UISegmentedControl *changeWorkModeSegmentControl;
@property (weak, nonatomic) IBOutlet UIView *fpvPreviewView;
@property (assign, nonatomic) BOOL isRecording;
@property (weak, nonatomic) IBOutlet UILabel *currentRecordTimeLabel;
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
- (IBAction) onStartButtonClicked:(id)sender;
@property (strong, nonatomic) IBOutlet UILabel *missionStatus;
@property (strong, nonatomic) IBOutlet UILabel *altitudeLabel;


@property(nonatomic, assign) DJIFlightControllerCurrentState* droneState;
@property(nonatomic, assign) DJIFlightController* flightController;
@property(nonatomic, assign) CLLocationCoordinate2D droneLocation;
@property(nonatomic, assign) DJIAircraftRemainingBatteryState batteryRemaining;
@property(nonatomic, assign) BOOL shouldElevate;
@property(nonatomic, assign) int flightLoopCount;
@property(nonatomic, assign) int counter;
@property(nonatomic, assign) NSTimeInterval SLEEP_TIME_BTWN_STICK_COMMANDS;

@end





@implementation DJICameraViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.SLEEP_TIME_BTWN_STICK_COMMANDS = 0.09;

    [[VideoPreviewer instance] setView: self.fpvPreviewView];
    [self registerApp];
}



- (void)viewDidLoad {
    [super viewDidLoad];
    [self.currentRecordTimeLabel setHidden:YES];
    
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


- (void)viewWillDisappear:(BOOL)animated
{
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
        fc.yawControlMode = DJIVirtualStickYawControlModeAngularVelocity;
        fc.rollPitchControlMode = DJIVirtualStickRollPitchControlModeVelocity;
        fc.verticalControlMode = DJIVirtualStickVerticalControlModeVelocity;
        
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
            [DemoUtility showAlertViewWithTitle:nil message:@"Enter Virtual Stick Mode:Succeeded, attempting takeoff." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            [self autoTakeoff:fc];
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
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    _shouldElevate = true;
    
    [fc takeoffWithCompletion:^(NSError *error) {
        if (error) {
            [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Takeoff: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            double delayInSeconds = 5.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self autoTakeoff:fc];
            });
                
        } else {
            [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Takeoff Success, beginning virtual flight with battery: %hhu", _droneState.remainingBattery] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            [self virtualPilot:fc];
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
    
    if (self.batteryRemaining == DJIAircraftRemainingBatteryStateLow) {
        // Begin landing sequence
        // [LandingSequence landDrone: drone:<#(DJIAircraft *)#>]
    }
    
    // Elevate drone for 6 seconds at a rate of ~10Hz
    if (_shouldElevate) {
        for (int i=0; i<60; i++) {
            [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
            [self leftStickUp:i withLimit:60];
        }
    }
    
    [self bothSticksNeutral];
    [NSThread sleepForTimeInterval:2];

    for (int i=0; i<60; i++) {
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
        [self rightStickUp:i withLimit:60];

    }
    
    [self bothSticksNeutral];
    [NSThread sleepForTimeInterval:2];
    
    for (int i=0; i<60; i++) {
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
        [self rightStickLeft:i withLimit:60];
    }
    
    [self bothSticksNeutral];
    [NSThread sleepForTimeInterval:2];
    
    for (int i=0; i<60; i++) {
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
        [self rightStickDown:i withLimit:60];
    }
    
    [self bothSticksNeutral];
    [NSThread sleepForTimeInterval:2];
    
    for (int i=0; i<60; i++) {
        [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
        [self rightStickRight:i withLimit:60];
    }

    [self bothSticksNeutral];
    
    [NSThread sleepForTimeInterval:5];
    
    _flightLoopCount += 1;
    if (_batteryRemaining == DJIAircraftRemainingBatteryStateLow) {
        for (int i=0; i<150; i++) {
            [NSThread sleepForTimeInterval:_SLEEP_TIME_BTWN_STICK_COMMANDS];
            [self leftStickDown:i withLimit:150];
        }
        
        [self bothSticksNeutral];
        
        // once landing is done, wait for battery to be > 0.75
        while (_droneState.remainingBattery != DJIAircraftRemainingBatteryStateNormal) {
            [NSThread sleepForTimeInterval:5.0];
            [DemoUtility showAlertViewWithTitle:nil message:@"Battery too low to fly." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
        }
        _shouldElevate = true;
        [self virtualPilot:fc];
    }
    
    else {
        _shouldElevate = false;
        [self virtualPilot:fc];
    }

}

/*
TODO:
    Clean up UI
    Access photos from onboard SDK to process
 */


- (void)bothSticksNeutral
{
    CGPoint dir;
    dir.x = 0;
    dir.y = 0;
    
    [self setThrottle:dir.y andYaw:dir.x];
    [self setXVelocity:-dir.y andYVelocity:dir.x];
}

- (void)leftStickUp:(int) prog withLimit:(int) total
{
    CGPoint dir;
    
    double scale = 2.0*(total/2.0 - abs(prog-(total/2))) / total;
    dir.x = 0;
    dir.y = (-0.4)*scale;

    [self setThrottle:dir.y andYaw:dir.x];
}

- (void)rightStickUp:(int) prog withLimit:(int) total
{
    CGPoint dir;
    
    double scale = 2.0*(total/2.0 - abs(prog-(total/2))) / total;
    dir.x = 0;
    dir.y = (-0.15)*scale;
    [self setXVelocity:-dir.y andYVelocity:dir.x];
}

- (void)leftStickDown:(int) prog withLimit:(int) total
{
    CGPoint dir;
    
    double scale = 2.0*(total/2.0 - abs(prog-(total/2))) / total;
    dir.x = 0;
    dir.y = (0.4)*scale;
    
    [self setThrottle:dir.y andYaw:dir.x];
}

- (void)rightStickDown:(int) prog withLimit:(int) total
{
    CGPoint dir;
    double scale = 2.0*(total/2.0 - abs(prog-(total/2))) / total;
    dir.x = 0;
    dir.y = (0.15)*scale;
    [self setXVelocity:-dir.y andYVelocity:dir.x];
}

- (void)leftStickRight:(int) prog withLimit:(int) total
{
    CGPoint dir;
    double scale = 2.0*(total/2.0 - abs(prog-(total/2))) / total;
    dir.x = (0.05)*scale;
    dir.y = 0;
    
    [self setThrottle:dir.y andYaw:dir.x];
}

- (void)rightStickRight:(int) prog withLimit:(int) total
{
    CGPoint dir;
    double scale = 2.0*(total/2.0 - abs(prog-(total/2))) / total;
    dir.x = (0.15)*scale;
    dir.y = 0;
    [self setXVelocity:-dir.y andYVelocity:dir.x];
}

- (void)leftStickLeft:(int) prog withLimit:(int) total
{
    CGPoint dir;
    double scale = 2.0*(total/2.0 - abs(prog-(total/2))) / total;
    dir.x = (-0.05)*scale;
    dir.y = 0;
    
    [self setThrottle:dir.y andYaw:dir.x];
}

- (void)rightStickLeft:(int) prog withLimit:(int) total
{
    CGPoint dir;
    double scale = 2.0*(total/2.0 - abs(prog-(total/2))) / total;
    dir.x = (-0.15)*scale;
    dir.y = 0;
    [self setXVelocity:-dir.y andYVelocity:dir.x];
}

-(void) setThrottle:(float)y andYaw:(float)x
{
    self.mThrottle = y * -2;
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
    
    [self.currentRecordTimeLabel setHidden:!self.isRecording];
    [self.currentRecordTimeLabel setText:[self formattingSeconds:systemState.currentVideoRecordingTimeInSeconds]];
    
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
    if (self.batteryRemaining == DJIAircraftRemainingBatteryStateLow) {
        self.altitudeLabel.text = @"LOW";
    }
    if (self.batteryRemaining == DJIAircraftRemainingBatteryStateNormal) {
        self.altitudeLabel.text = @"NORMAL";
    }
    if (self.batteryRemaining == DJIAircraftRemainingBatteryStateVeryLow) {
        self.altitudeLabel.text = @"VERY LOW";
    }
    
    self.missionStatus.text = [NSString stringWithFormat:@"Battery remaining: %hhu %d", self.batteryRemaining, self.counter];
    
}

#pragma mark - IBAction Methods

- (IBAction)captureAction:(id)sender {
    
    if (![self fetchCamera])
        return;
    
//    [LandingSequence moveGimbal:((DJIAircraft*)[DJISDKManager product])];
    
    self.imgView.image = [LandingSequence takeSnapshot];
    
    CGSize imgSize = self.imgView.image.size;
    NSString* text = [NSString stringWithFormat:@"HxW: %f %f", imgSize.height, imgSize.width];
    [self showAlertViewWithTitle:@"Image Dimensions" withMessage:text];
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
    NSArray* coords = [Stitching findTargetCoordinates:target viewController:self];
    
    // display result, with highlighted center
    UIImage* result = [Stitching getRedMask:target];
    result = [Stitching imageWithColor:result location:coords];
    self.imgView.image = result;
    
    // print coordinates
    self.coordTextView.text = [coords description];
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
