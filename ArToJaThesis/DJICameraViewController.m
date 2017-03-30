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


@interface DJICameraViewController ()<DJICameraDelegate, DJISDKManagerDelegate, DJIBaseProductDelegate, DJISimulatorDelegate, DJIFlightControllerDelegate>

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

@property(nonatomic, weak) IBOutlet VirtualStickView *virtualStickLeft;
@property(nonatomic, weak) IBOutlet VirtualStickView *virtualStickRight;

@property (weak, nonatomic) IBOutlet UIButton *simulatorButton;
@property (weak, nonatomic) IBOutlet UILabel *simulatorStateLabel;
@property (assign, nonatomic) BOOL isSimulatorOn;
@property (assign, nonatomic) float mXVelocity;
@property (assign, nonatomic) float mYVelocity;
@property (assign, nonatomic) float mYaw;
@property (assign, nonatomic) float mThrottle;

- (IBAction) onEnterVirtualStickControlButtonClicked:(id)sender;
- (IBAction) onExitVirtualStickControlButtonClicked:(id)sender;
- (IBAction) onTakeoffButtonClicked:(id)sender;
- (IBAction) onSimulatorButtonClicked:(id)sender;
- (IBAction) onLandButtonClicked:(id)sender;

@property (weak, nonatomic) IBOutlet UIButton *startButton;
- (IBAction) onStartButtonClicked:(id)sender;

@property(nonatomic, assign) CLLocationCoordinate2D droneLocation;
@property(nonatomic, assign) double batteryRemaining;



@end





@implementation DJICameraViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
//    [[VideoPreviewer instance] setView:self.fpvPreviewView];
    [self registerApp];
}



- (void)viewDidLoad {
    [super viewDidLoad];
    [self.currentRecordTimeLabel setHidden:YES];
    
    self.title = @"DJISimulator Demo";
    
    self.imgView.image = [UIImage imageNamed: @"target"];

    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver: self
                           selector: @selector (onStickChanged:)
                               name: @"StickChanged"
                             object: nil];
    
}

-(void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    DJIFlightController* fc = [DemoUtility fetchFlightController];
    if (fc && fc.simulator) {
        self.isSimulatorOn = fc.simulator.isSimulatorStarted;
        [self updateSimulatorUI];
        
        [fc.simulator addObserver:self forKeyPath:@"isSimulatorStarted" options:NSKeyValueObservingOptionNew context:nil];
        [fc.simulator setDelegate:self];
    }
}


- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[VideoPreviewer instance] setView:nil];
    
    DJIFlightController* fc = [DemoUtility fetchFlightController];
    if (fc && fc.simulator) {
        [fc.simulator removeObserver:self forKeyPath:@"isSimulatorStarted"];
        [fc.simulator setDelegate:nil];
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

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"isSimulatorStarted"]) {
        self.isSimulatorOn = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        [self updateSimulatorUI];
    }
}

-(void) updateSimulatorUI {
    if (!self.isSimulatorOn) {
        [self.simulatorButton setTitle:@"Start Simulator" forState:UIControlStateNormal];
        [self.simulatorStateLabel setHidden:YES];
    }
    else {
        [self.simulatorButton setTitle:@"Stop Simulator" forState:UIControlStateNormal];
    }
}


/* Should perform the following upon tapping "START MISSION":
 * * * 1) Fetch flight controller without error
 * * * 2) Set the control modes for yaw, pitch, roll, and vertical control
 * * * 3) Put drone in virtual stick control mode
 */
- (IBAction)onStartButtonClicked:(id)sender {
    DJIFlightController* fc = [DemoUtility fetchFlightController];
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
            double delayInSeconds = 10.0;
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
    
    [fc takeoffWithCompletion:^(NSError *error) {
        if (error) {
            [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Takeoff: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            double delayInSeconds = 10.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self autoTakeoff:fc];
            });
                
        } else {
            [DemoUtility showAlertViewWithTitle:nil message:@"Takeoff Success, beginning virtual flight." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
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
 * * * 4) Begin flight loop --> While battery remains above 20%,
 * * *      -  Fly in each direction at 1/20 max speed for 10 seconds
 * * *      -  Fly in each direction at 1/20 max speed for 10 seconds
 * * *      -  Fly in each direction at 1/20 max speed for 10 seconds
 
 */
- (void) virtualPilot:(DJIFlightController*) fc {
    double commandDelayInSeconds = 10;
    double stickDelayInSeconds = 0.1;
    dispatch_time_t commandDelay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(commandDelayInSeconds * NSEC_PER_SEC));
    dispatch_time_t stickDelay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(stickDelayInSeconds * NSEC_PER_SEC));
    
    // no idea how to get the state
    // DJIFlightControllerCurrentState* state = fc.delegate
    if (self.batteryRemaining < 0.20) {
        // Begin landing sequence
        // [LandingSequence landDrone: drone:<#(DJIAircraft *)#>]
    }
    
    // Elevate drone for 3 seconds at a rate of 10Hz
    for (int i=0; i<30; i++) {
        dispatch_after(stickDelay, dispatch_get_main_queue(), ^(void){
            [self leftStickUp];
        });
    }
    
    // Wait for 10 seconds, then move forward for 3 seconds
    dispatch_after(commandDelay, dispatch_get_main_queue(), ^(void){
        for (int i=0; i<30; i++) {
            dispatch_after(stickDelay, dispatch_get_main_queue(), ^(void){
                [self rightStickUp];
            });
        }
    });
    
    // Immediately land in place
    for (int i=0; i<100; i++) {
        dispatch_after(stickDelay, dispatch_get_main_queue(), ^(void){
            [self leftStickDown];
        });
    }

}

/*
 
 Initial TODO:
    Test VirtualPilot v0.1 (figure out what directions/orientations mean and make notes
        --> Does frequency work? Is it choppy or smooth control? Is it too slow?
    Figure out how to get DJIFlightControllerCurrentState for Tony's methods
        --> This is probably as simple as understanding how delegates work
    With a firm understanding of directionality, write a more complex VirtualPilot
        --> Adjust times/speeds for direction sticks
        --> Make it fly in a square
    Decide if we even need the VirtualStickView class (probably not)
        --> Maybe salvage the timer out of it?
    Clean up UI
    Access photos from onboard SDK to process
 */



-(IBAction) onEnterVirtualStickControlButtonClicked:(id)sender
{
    DJIFlightController* fc = [DemoUtility fetchFlightController];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    
    if (fc) {
        fc.yawControlMode = DJIVirtualStickYawControlModeAngularVelocity;
        fc.rollPitchControlMode = DJIVirtualStickRollPitchControlModeVelocity;
        
        [fc enableVirtualStickControlModeWithCompletion:^(NSError *error) {
            if (error) {
                [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Enter Virtual Stick Mode: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            }
            else
            {
                [DemoUtility showAlertViewWithTitle:nil message:@"Enter Virtual Stick Mode:Succeeded" cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            }
        }];
    }
    else
    {
        [DemoUtility showAlertViewWithTitle:nil message:@"Component not exist." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
    }
}

-(IBAction) onExitVirtualStickControlButtonClicked:(id)sender
{
    DJIFlightController* fc = [DemoUtility fetchFlightController];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    
    if (fc) {
        [fc disableVirtualStickControlModeWithCompletion:^(NSError * _Nullable error) {
            if (error){
                [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Exit Virtual Stick Mode: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            } else{
                [DemoUtility showAlertViewWithTitle:nil message:@"Exit Virtual Stick Mode:Succeeded" cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            }
        }];
    }
    else
    {
        [DemoUtility showAlertViewWithTitle:nil message:@"Component not exist." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
        
    }
}

- (IBAction)onSimulatorButtonClicked:(id)sender {
    
    DJIFlightController* fc = [DemoUtility fetchFlightController];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    
    if (fc && fc.simulator) {
        if (!self.isSimulatorOn) {
            // The initial aircraft's position in the simulator.
            CLLocationCoordinate2D location = CLLocationCoordinate2DMake(22, 113);
            [fc.simulator startSimulatorWithLocation:location updateFrequency:20 GPSSatellitesNumber:10 withCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Start simulator error: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
                    
                } else {
                    [DemoUtility showAlertViewWithTitle:nil message:@"Start Simulator succeeded." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
                }
            }];
        }
        else {
            [fc.simulator stopSimulatorWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Stop simulator error: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
                    
                } else {
                    [DemoUtility showAlertViewWithTitle:nil message:@"Stop Simulator succeeded." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
                }
            }];
        }
    }
}

-(IBAction) onTakeoffButtonClicked:(id)sender
{
    DJIFlightController* fc = [DemoUtility fetchFlightController];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    
    if (fc) {
        [fc takeoffWithCompletion:^(NSError *error) {
            if (error) {
                [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"Takeoff: %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
                
            } else {
                [DemoUtility showAlertViewWithTitle:nil message:@"Takeoff Success." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
                
            }
        }];
    }
    else
    {
        [DemoUtility showAlertViewWithTitle:nil message:@"Component not exist." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
    }
}

- (IBAction)onLandButtonClicked:(id)sender {
    
    DJIFlightController* fc = [DemoUtility fetchFlightController];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    
    if (fc) {
        [fc autoLandingWithCompletion:^(NSError * _Nullable error) {
            if (error) {
                [DemoUtility showAlertViewWithTitle:nil message:[NSString stringWithFormat:@"AutoLand : %@", error.description] cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
                
            } else {
                [DemoUtility showAlertViewWithTitle:nil message:@"AutoLand Started." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
            }
        }];
    }
    else
    {
        [DemoUtility showAlertViewWithTitle:nil message:@"Component not exist." cancelAlertAction:cancelAction defaultAlertAction:nil viewController:self];
    }
}

- (void)onStickChanged:(NSNotification*)notification
{
    NSDictionary *dict = [notification userInfo];
    NSValue *vdir = [dict valueForKey:@"dir"];
    CGPoint dir = [vdir CGPointValue];
    
    VirtualStickView* virtualStick = (VirtualStickView*)notification.object;
    if (virtualStick) {
        if (virtualStick == self.virtualStickLeft) {
            [self setThrottle:dir.y andYaw:dir.x];
        }
        else
        {
            [self setXVelocity:-dir.y andYVelocity:dir.x];
        }
    }
}

- (void)leftStickUp
{
    CGPoint dir;
    dir.x = 0;
    dir.y = -0.05;
    
    [self setThrottle:dir.y andYaw:dir.x];
}

- (void)rightStickUp
{
    CGPoint dir;
    dir.x = 0;
    dir.y = -0.05;
    [self setXVelocity:-dir.y andYVelocity:dir.x];
}

- (void)leftStickRight
{
    CGPoint dir;
    dir.x = 0.05;
    dir.y = 0;
    
    [self setThrottle:dir.y andYaw:dir.x];
}

- (void)rightStickRight
{
    CGPoint dir;
    dir.x = 0.05;
    dir.y = 0;
    [self setXVelocity:-dir.y andYVelocity:dir.x];
}

- (void)leftStickDown
{
    CGPoint dir;
    dir.x = 0;
    dir.y = 0.05;
    
    [self setThrottle:dir.y andYaw:dir.x];
}

- (void)rightStickDown
{
    CGPoint dir;
    dir.x = 0;
    dir.y = 0.05;
    [self setXVelocity:-dir.y andYVelocity:dir.x];
}

- (void)leftStickLeft
{
    CGPoint dir;
    dir.x = -0.05;
    dir.y = 0;
    
    [self setThrottle:dir.y andYaw:dir.x];
}

- (void)rightStickLeft
{
    CGPoint dir;
    dir.x = -0.05;
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
    DJIFlightController* fc = [DemoUtility fetchFlightController];
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




#pragma mark -DJI Simulator Delegate

-(void)simulator:(DJISimulator *)simulator updateSimulatorState:(DJISimulatorState *)state {
    [self.simulatorStateLabel setHidden:NO];
    self.simulatorStateLabel.text = [NSString stringWithFormat:@"Yaw: %0.2f Pitch: %0.2f, Roll: %0.2f\n PosX: %0.2f PosY: %0.2f PosZ: %0.2f", state.yaw, state.pitch, state.roll, state.positionX, state.positionY, state.positionZ];
}


#pragma mark DJIFlightControllerDelegate

- (void)flightController:(DJIFlightController *)fc didUpdateSystemState:(DJIFlightControllerCurrentState *)state
{
    self.droneLocation = state.aircraftLocation;
    self.batteryRemaining = state.remainingBattery;
    
}


#pragma mark - IBAction Methods

- (IBAction)captureAction:(id)sender {
    
    __weak DJICameraViewController *weakSelf = self;
    __weak DJICamera* camera = [self fetchCamera];
    __block NSMutableData* downloadedFileData;
    __block UIImage* output;
    
//    self.imgView.image = [LandingSequence takeSnapshot:camera];
    
    if (camera) {
//        [camera setCameraMode:DJICameraModePlayback withCompletion:nil];
//        [camera.playbackManager selectAllFiles];
//        [camera.playbackManager deleteAllSelectedFiles];
        
//        [self showAlertViewWithTitle:@"Take Photo Error" withMessage:error.description]
        sleep(3);
        
        weakSelf(target);
        
        // take picture
        [camera setCameraMode:DJICameraModeShootPhoto withCompletion:nil];
        [camera startShootPhoto:DJICameraShootPhotoModeSingle withCompletion:^(NSError * _Nullable error) {
            weakReturn(target);
            if (error) {
                [weakSelf showAlertViewWithTitle:@"Take Photo Error" withMessage:error.description];
            }
        }];
        
        sleep(3);
        
        // download picture
        [camera setCameraMode:DJICameraModeMediaDownload withCompletion:^(NSError * _Nullable error) {
            weakReturn(target);
            if (error) {
                [weakSelf showAlertViewWithTitle:@"Playback Mode Error" withMessage:error.description];
            }
        }];
        
        sleep(3);
        
        DJIMediaManager* mediaManager = camera.mediaManager;
        [mediaManager fetchMediaListWithCompletion:^(NSArray<DJIMedia *> * _Nullable mediaList, NSError * _Nullable error) {
            WeakReturn(target);
            
            if (error) {
                [weakSelf showAlertViewWithTitle:@"FetchMediaList Error" withMessage:error.description];
            }
            else {
                for (DJIMedia *file in mediaList) {
                    [weakSelf showAlertViewWithTitle:file.fileName withMessage:file.timeCreated];
                    [file fetchMediaDataWithCompletion:^(NSData * _Nullable data, BOOL * _Nullable stop, NSError * _Nullable error) {
                        if (error) {
                            [weakSelf showAlertViewWithTitle:@"Download Image Error" withMessage:error.description];
                        }

                        output = [UIImage imageWithData:data];
                        NSString* dims = [NSString stringWithFormat:@"size: %lu, %f, %f", data.length, output.size.height, output.size.width];
                        // NSDATA too small? try deleting and taking new image
                        [weakSelf showAlertViewWithTitle:@"Parsing Output" withMessage:dims];

                        self.imgView.image = output;
                    }];
                };
            }
        }];
        
        
//        [camera.playbackManager selectAllFiles]; // there should only be one
//        [camera.playbackManager downloadSelectedFilesWithPreparation:
//         ^(NSString * _Nullable fileName, DJIDownloadFileType fileType, NSUInteger fileSize, BOOL * _Nonnull skip) {
//             downloadedFileData = [NSMutableData new];
//             
//         } process:^(NSData * _Nullable data, NSError * _Nullable error) {
//             weakReturn(target);
//             [downloadedFileData appendData:data];
//             if (error) {
//                 [weakSelf showAlertViewWithTitle:@"Download Data Error" withMessage:error.description];
//             }
//             
//         } fileCompletion:^{
//             weakReturn(target);
//             output = [UIImage imageWithData:downloadedFileData];
//             
//         } overallCompletion:^(NSError * _Nullable error) {
//             if (error) {
//                 [weakSelf showAlertViewWithTitle:@"Completion Error" withMessage:error.description];
//             }
//         }];
    }
    
    self.imgView.image = output;
    
}

//+ setImgView:(NSArray<DJIMedia *> * _Nullable) mediaList {
//    __weak DJICameraViewController *weakSelf = self;
//    
//    for (DJIMedia *file in mediaList) {
//        [weakSelf showAlertViewWithTitle:file.fileName withMessage:file.timeCreated];
//        [file fetchMediaDataWithCompletion:^(NSData * _Nullable data, BOOL * _Nullable stop, NSError * _Nullable error) {
//            weakSelf.imgView.image = [UIImage imageWithData:downloadedFileData];
//        }];
//    };
//}


- (IBAction)processAction:(id)sender {
//    __weak DJICameraViewController *weakSelf = self;
    
    // move gimbal
    [LandingSequence moveGimbal:((DJIAircraft*)[DJISDKManager product])];
    
    // process image and show results
    UIImage* target = [UIImage imageNamed: @"target"];
    NSArray* coords = [Stitching findTargetCoordinates:target];
    UIImage* result = [Stitching getRedMask:target];
    
    NSString * outputString = [coords description];
    self.coordTextView.text = outputString;
    
    self.imgView.image = result;
    
    
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
