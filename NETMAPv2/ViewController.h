//
//  ViewController.h
//  NETMAPv2
//
//  Created by Rod Matveev on 14/06/2016.
//  Copyright © 2016 Rod Matveev. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BEMSimpleLineGraphView.h"
#import "PNChart.h"
@import Firebase;

@interface ViewController : UIViewController <BEMSimpleLineGraphDataSource, BEMSimpleLineGraphDelegate,PNChartDelegate>

@property (weak,nonatomic) FIRDatabaseReference *dbRef;
@property (weak,nonatomic) IBOutlet UISegmentedControl *modeSwitch;
@property (weak,nonatomic) IBOutlet UITextField *homeTeam;
@property (weak,nonatomic) IBOutlet UITextField *awayTeam;
@property (weak,nonatomic) IBOutlet UITextField *homeGoals;
@property (weak,nonatomic) IBOutlet UITextField *awayGoals;
@property (weak,nonatomic) IBOutlet UISegmentedControl *tournamentSwitch;
@property (weak,nonatomic) IBOutlet UIButton *readyButton;
@property (weak,nonatomic) IBOutlet UIView *scoreView;
@property (weak,nonatomic) IBOutlet UIView *leftGraph;
@property (weak,nonatomic) IBOutlet UIView *rightGraph;

@end