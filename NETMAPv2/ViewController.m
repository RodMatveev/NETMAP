//
//  ViewController.m
//  NETMAPv2
//
//  Created by Rod Matveev on 14/06/2016.
//  Copyright © 2016 Rod Matveev. All rights reserved.
//

#import "ViewController.h"
@import Firebase;

@interface ViewController (){
    NSDictionary *allData;
    NSString *chosenTournament;
    NSString *mode;
    NSMutableArray *weightsArray;
    NSArray *chosenData;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //Creating ref to NETMAP database
    self.dbRef = [[FIRDatabase database] reference];
    chosenTournament = @"2016";
    [self fetchTournamentData];
}

- (void)fetchTournamentData{
    [[self.dbRef child:@"Euro Data"] observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
        
        NSLog(@"2012 CZE:%@",snapshot.value[@"2012"][@"CZE"]);
        allData = snapshot.value;
        
    } withCancelBlock:^(NSError * _Nonnull error) {
        NSLog(@"%@", error.localizedDescription);
    }];
    
}

//Delegate Methods

- (IBAction)segmentSwitch:(id)sender {
    if(sender == self.tournamentSwitch){
        UISegmentedControl *segmentedControl = (UISegmentedControl *) sender;
        NSInteger selectedSegment = segmentedControl.selectedSegmentIndex;
        if (selectedSegment == 0) {
            chosenTournament = @"2016";
        }else if(selectedSegment == 1){
            chosenTournament = @"2012";
        }else if (selectedSegment == 2){
            chosenTournament = @"2008";
        }else{
            chosenTournament = @"2004";
        }
    }else{
        UISegmentedControl *segmentedControl = (UISegmentedControl *) sender;
        NSInteger selectedSegment = segmentedControl.selectedSegmentIndex;
        if (selectedSegment == 0) {
            mode = @"Training";
        }else{
            mode = @"Prediction";
        }
    }
}

//Pre-training

- (void)generateRandomWeights{
    weightsArray = nil;
    weightsArray = [[NSMutableArray alloc]init];
    for (int i=0; i<4; i++) {
        float rand = arc4random();
        [weightsArray addObject:[NSNumber numberWithFloat:rand]];
    }
}

//2 Layers

- (IBAction)ready:(id)sender{
    chosenData = [self constructInitialArray];
    NSLog(@"Chosen Data: \n%@",chosenData);
}

//Construct final array with chosen data, flip values

- (NSArray*)constructInitialArray{
    int previousTournament = [chosenTournament intValue] - 4;
    double f1 = ([allData[chosenTournament][self.homeTeam.text][@"F1"] doubleValue]) - ([allData[chosenTournament][self.awayTeam.text][@"F1"] doubleValue]);
    double f2 = ([allData[chosenTournament][self.homeTeam.text][@"F2"] doubleValue]) - ([allData[chosenTournament][self.awayTeam.text][@"F2"] doubleValue]);
    double ftsHome;
    double ftsAway;
    if([allData[[NSString stringWithFormat:@"%d", previousTournament]][self.homeTeam.text][@"FTS"] doubleValue]){
        ftsHome = [allData[[NSString stringWithFormat:@"%d", previousTournament]][self.homeTeam.text][@"FTS"] doubleValue];
    }else{
        ftsHome = 8;
    }
    if([allData[[NSString stringWithFormat:@"%d", previousTournament]][self.awayTeam.text][@"FTS"] doubleValue]){
        ftsAway = [allData[[NSString stringWithFormat:@"%d", previousTournament]][self.awayTeam.text][@"FTS"] doubleValue];
    }else{
        ftsAway = 8;
    }
    double fts = ftsHome - ftsAway;
    double mv = ([allData[chosenTournament][self.homeTeam.text][@"MV"] doubleValue]) - ([allData[chosenTournament][self.awayTeam.text][@"MV"] doubleValue]);
    double qg = ([allData[chosenTournament][self.homeTeam.text][@"QG"] doubleValue]) - ([allData[chosenTournament][self.awayTeam.text][@"QG"] doubleValue]);
    double qp = ([allData[chosenTournament][self.homeTeam.text][@"QP"] doubleValue]) - ([allData[chosenTournament][self.awayTeam.text][@"QP"] doubleValue]);
    NSArray *finalData = [[NSArray alloc] initWithObjects:[NSNumber numberWithDouble:f1], [NSNumber numberWithDouble:f2], [NSNumber numberWithDouble:fts], [NSNumber numberWithDouble:mv], [NSNumber numberWithDouble:qg], [NSNumber numberWithDouble:qp], nil];
    return finalData;
}


@end
