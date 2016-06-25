//
//  ViewController.m
//  NETMAPv2
//
//  Created by Rod Matveev on 14/06/2016.
//  Copyright © 2016 Rod Matveev. All rights reserved.
//

#import "ViewController.h"
#import <PNChart.h>
#import "BEMSimpleLineGraphView.h"
@import Firebase;

#define ARC4RANDOM_MAX      0x100000000

@interface ViewController (){
    NSDictionary *allData;
    NSString *chosenTournament;
    NSString *mode;
    NSMutableArray *weightsArray;
    NSArray *chosenData;
    NSNumber *output;
    NSNumber *trainingOutput;
    BEMSimpleLineGraphView *weightsGraph;
    PNBarChart *barChart;
    PNLineChart *lineChart;
    NSMutableArray *errorArray;
    NSMutableArray *errorArrayReverse;
    NSMutableArray *countArray;
    int trainingCount;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //Creating ref to NETMAP database
    self.dbRef = [[FIRDatabase database] reference];
    chosenTournament = @"2016";
    [self fetchTournamentData];
    
    //Generate new weights (don't touch)
    [self generateRandomWeights];
    //weightsArray = [[NSMutableArray alloc] initWithObjects:[NSNumber numberWithFloat:-1.097777],[NSNumber numberWithFloat:-1.2106181],[NSNumber numberWithFloat:-0.7997253], [NSNumber numberWithFloat:0.2663461], [NSNumber numberWithFloat:0.2180073], [NSNumber numberWithFloat:0.0588236], nil];
    //
    
    //Try sigmoid
    float sig = [self SFwithDeriv:YES andVal:1.2];
    NSLog(@"Sig: %f",sig);
    //
    
    //weightsGraph = [[BEMSimpleLineGraphView alloc]initWithFrame:self.leftGraph.frame];
    //weightsGraph.delegate = self;
    //weightsGraph.dataSource = self;
    //[self.view addSubview:weightsGraph];
    
    errorArray = [[NSMutableArray alloc] init];
    countArray = [[NSMutableArray alloc] init];
    //errorArrayReverse = [[NSMutableArray alloc]init];

    trainingCount = 0;
}

- (void)viewDidAppear:(BOOL)animated{
    [self setUpWeightChart];
    [self setUpErrorChart];
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

//Set up graphs

- (void)setUpWeightChart{
    barChart = [[PNBarChart alloc] initWithFrame:self.leftGraph.frame];
    [barChart setXLabels:@[@"F1",@"F2",@"FTS",@"MV",@"QG",@"QP"]];
    [barChart setYValues:@[weightsArray[0],weightsArray[1],weightsArray[2],weightsArray[3],weightsArray[4],weightsArray[5]]];
    barChart.layer.masksToBounds = YES;
    barChart.layer.cornerRadius = 8;
    barChart.chartMarginTop = 10;
    barChart.chartMarginBottom = 0;
    barChart.labelTextColor = [UIColor darkGrayColor];
    barChart.isShowNumbers = NO;
    barChart.isGradientShow = NO;
    [barChart setStrokeColor:[UIColor colorWithRed:1.000 green:0.765 blue:0.443 alpha:1.00]];
    [barChart setBarBackgroundColor:[UIColor colorWithRed:0.965 green:0.965 blue:0.965 alpha:1.00]];
    [barChart setBarRadius:8];
    [barChart strokeChart];
    [self.view addSubview:barChart];
}

- (void)updateWeightChart{
    [barChart setXLabels:@[@"F1",@"F2",@"FTS",@"MV",@"QG",@"QP"]];
    [barChart updateChartData:@[weightsArray[0],weightsArray[1],weightsArray[2],weightsArray[3],weightsArray[4],weightsArray[5]]];
    NSNumber* highestWeight;
    for (int i = 0; i < 6; i++) {
        if(i == 0){
            highestWeight = weightsArray[0];
        }else{
            NSNumber *weight = weightsArray[i];
            if([weight floatValue] > [highestWeight floatValue]){
                highestWeight = weight;
            }
        }
    }
    barChart.yMaxValue = [highestWeight floatValue] + 2;
}

- (void)setUpErrorChart{
    lineChart = [[PNLineChart alloc] initWithFrame:self.rightGraph.frame];
    [lineChart setXLabels:@[@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@""]];
    lineChart.showSmoothLines = YES;
    [lineChart strokeChart];
    lineChart.delegate = self;
    lineChart.chartMarginLeft = 10;
    lineChart.chartMarginTop = 10;
    lineChart.chartMarginBottom = 5;
    lineChart.showCoordinateAxis = NO;
    lineChart.layer.masksToBounds = YES;
    lineChart.layer.cornerRadius = 8;
    [self.view addSubview:lineChart];
}

- (void)updateErrorChart{
    PNLineChartData *home = [PNLineChartData new];
    home.color = [UIColor colorWithRed:1.000 green:0.373 blue:0.427 alpha:1.00];
    home.itemCount = [errorArray count];
    //home.inflexionPointColor = [UIColor colorWithRed:1.000 green:0.373 blue:0.427 alpha:1.00];
    //home.inflexionPointStyle = PNLineChartPointStyleCircle;
    home.getData = ^(NSUInteger index){
        NSNumber *error = errorArray[index];
        CGFloat yValue = [error floatValue];
        return [PNLineChartDataItem dataItemWithY:yValue];
    };
    
    /*PNLineChartData *away = [PNLineChartData new];
    away.color = [UIColor colorWithRed:1.000 green:0.765 blue:0.443 alpha:1.00];
    away.itemCount = [errorArrayReverse count];
    away.inflexionPointColor = [UIColor colorWithRed:1.000 green:0.765 blue:0.443 alpha:1.00];
    away.inflexionPointStyle = PNLineChartPointStyleTriangle;
    away.getData = ^(NSUInteger index){
        NSNumber *error = errorArrayReverse[index];
        CGFloat yValue = [error floatValue];
        return [PNLineChartDataItem dataItemWithY:yValue];
    };*/
    NSNumber* highestError;
    for (int i = 0; i < [errorArray count]; i++) {
        if(i == 0){
            highestError = errorArray[0];
        }else{
            NSNumber *error = errorArray[i];
            if([error floatValue] > [highestError floatValue]){
                highestError = error;
            }
        }
    }
    lineChart.yFixedValueMax = [highestError floatValue] +0.5;
    lineChart.chartData = @[home];
    [lineChart strokeChart];
}

//Chart delegates

- (NSInteger)numberOfPointsInLineGraph:(BEMSimpleLineGraphView*)graph{
    return 6;
}

- (CGFloat)lineGraph:(BEMSimpleLineGraphView*)graph valueForPointAtIndex:(NSInteger)index{
    NSNumber *weight = weightsArray[(int)index];
    return [weight floatValue];
}

//Sigmoid function

- (float)SFwithDeriv:(BOOL)deriv andVal:(float)x{
    if(deriv == YES){
        float sig = 1/(1+(powf(M_E, -x)));
        return sig*(1-sig);
    }else{
        return 1/(1+(powf(M_E, -x)));
    }
}

//Pre-training

- (void)generateRandomWeights{
    weightsArray = nil;
    weightsArray = [[NSMutableArray alloc]init];
    for (int i=0; i<6; i++) {
        float range = 0.6 + 0.6;
        float val = ((float)arc4random() / ARC4RANDOM_MAX) * range + 0.4;
        val -= 1.2;
        [weightsArray addObject:[NSNumber numberWithFloat:val]];
    }
    NSLog(@"Random weights: \n%@",weightsArray);
}

//2 Layers

- (IBAction)ready:(id)sender{
    if([mode isEqualToString:@"Prediction"]){
        [self predictResult];
    }else{
        output = [NSNumber numberWithFloat:0];
        chosenData = [self constructInitialArray:NO];
        trainingOutput = [NSNumber numberWithInt:[self.homeGoals.text intValue]];
        for (int i = 0; i < 6; i++) {
            NSNumber *input = chosenData [i];
            NSNumber *weight = weightsArray[i];
            NSNumber *finalOutput = [NSNumber numberWithFloat:[self SFwithDeriv:NO andVal:([input floatValue]*[weight floatValue])]];
            float addedOutput = [finalOutput floatValue]+[output floatValue];
            output = [NSNumber numberWithFloat: addedOutput];
        }
        NSLog(@"Forward prop result: %f", [output floatValue]);
        float outputError = [trainingOutput floatValue] - [output floatValue];
        NSLog(@"Error: %f", outputError);
        float outputDeriv = [self SFwithDeriv:YES andVal:[output floatValue]];
        NSLog(@"Output Deriv: %f", outputDeriv);
        float weightChange = outputError * outputDeriv;
        NSMutableArray *inputDotWeightChange = [[NSMutableArray alloc]init];
        for (int i =0; i < 6; i++){
            NSNumber *input = chosenData[i];
            NSNumber *IDWC = [NSNumber numberWithFloat:[input floatValue] * weightChange];
            [inputDotWeightChange setObject:IDWC atIndexedSubscript:i];
        }
        for (int i = 0; i < 6; i++) {
            NSNumber *weight = weightsArray[i];
            NSNumber *IDWC = inputDotWeightChange[i];
            [weightsArray setObject:[NSNumber numberWithFloat:([weight floatValue] + [IDWC floatValue])] atIndexedSubscript:i];
        }
        NSLog(@"Weights array first cycle: \n%@",weightsArray);
        [self updateWeightChart];
        if (outputError < 0) {
            outputError *= -1;
        }
        trainingCount++;
        self.trialCount.text = [NSString stringWithFormat:@"(%d)",trainingCount];
        if([errorArray count] > 75){
            [errorArray removeObjectAtIndex:0];
        }
        [countArray addObject:[NSNumber numberWithInt:trainingCount]];
        [errorArray addObject:[NSNumber numberWithFloat:outputError]];
        [self updateErrorChart];
        [self saveWeights];
        //NSLog(@"Error array: %@",errorArray);
    }
}

/*- (void)reverseFixture{
    output = [NSNumber numberWithFloat:0];
    chosenData = [self constructInitialArray:YES];
    trainingOutput = [NSNumber numberWithInt:[self.awayGoals.text intValue]];
    NSLog(@"Chosen Data: \n%@",chosenData);
    for (int i = 0; i < 6; i++) {
        NSNumber *input = chosenData [i];
        NSNumber *weight = weightsArray[i];
        NSNumber *finalOutput = [NSNumber numberWithFloat:[self SFwithDeriv:NO andVal:([input floatValue]*[weight floatValue])]];
        float addedOutput = [finalOutput floatValue]+[output floatValue];
        output = [NSNumber numberWithFloat: addedOutput];
    }
    NSLog(@"Forward prop result: %f", [output floatValue]);
    float outputError = [trainingOutput floatValue] - [output floatValue];
    NSLog(@"Error: %f", outputError);
    float outputDeriv = [self SFwithDeriv:YES andVal:[output floatValue]];
    NSLog(@"Output Deriv: %f", outputDeriv);
    float weightChange = outputError * outputDeriv;
    NSMutableArray *inputDotWeightChange = [[NSMutableArray alloc]init];
    for (int i =0; i < 6; i++){
        NSNumber *input = chosenData[i];
        NSNumber *IDWC = [NSNumber numberWithFloat:[input floatValue] * weightChange];
        [inputDotWeightChange setObject:IDWC atIndexedSubscript:i];
    }
    for (int i = 0; i < 6; i++) {
        NSNumber *weight = weightsArray[i];
        NSNumber *IDWC = inputDotWeightChange[i];
        [weightsArray setObject:[NSNumber numberWithFloat:([weight floatValue] + [IDWC floatValue])] atIndexedSubscript:i];
    }
    NSLog(@"Weights array: \n%@",weightsArray);
    [self updateWeightChart];
    if (outputError < 0) {
        outputError *= -1;
    }
    trainingCount++;
    if(trainingCount % 1 == 0){
        if([errorArray count] > 100){
            [errorArray removeObjectAtIndex:0];
        }
        [countArray addObject:[NSNumber numberWithInt:trainingCount]];
        [errorArrayReverse addObject:[NSNumber numberWithFloat:outputError]];
        [self updateErrorChart];
    }
    [self saveWeights];
    //NSLog(@"Error array: %@",errorArray);
}*/

//Construct final array with chosen data, flip values

- (NSArray*)constructInitialArray:(BOOL)reverse{
    NSString *homeTeam;
    NSString *awayTeam;
    if (reverse == YES) {
        homeTeam = self.awayTeam.text;
        awayTeam = self.homeTeam.text;
    }else{
        homeTeam = self.homeTeam.text;
        awayTeam = self.awayTeam.text;
    }
    int previousTournament = [chosenTournament intValue] - 4;
    double f1 = ([allData[chosenTournament][homeTeam][@"F1"] doubleValue]) - ([allData[chosenTournament][awayTeam][@"F1"] doubleValue]);
    //f1 /= 10;
    double f2 = ([allData[chosenTournament][homeTeam][@"F2"] doubleValue]) - ([allData[chosenTournament][awayTeam][@"F2"] doubleValue]);
    //f2 /= 10;
    double ftsHome;
    double ftsAway;
    if([allData[[NSString stringWithFormat:@"%d", previousTournament]][homeTeam][@"FTS"] doubleValue]){
        ftsHome = [allData[[NSString stringWithFormat:@"%d", previousTournament]][homeTeam][@"FTS"] doubleValue];
    }else{
        ftsHome = 8;
    }
    if([allData[[NSString stringWithFormat:@"%d", previousTournament]][awayTeam][@"FTS"] doubleValue]){
        ftsAway = [allData[[NSString stringWithFormat:@"%d", previousTournament]][awayTeam][@"FTS"] doubleValue];
    }else{
        ftsAway = 8;
    }
    double fts = ftsHome - ftsAway;
    //fts /= 10;
    double mv = ([allData[chosenTournament][homeTeam][@"MV"] doubleValue]) - ([allData[chosenTournament][awayTeam][@"MV"] doubleValue]);
    //mv /= 100;
    double qg = ([allData[chosenTournament][homeTeam][@"QG"] doubleValue]) - ([allData[chosenTournament][awayTeam][@"QG"] doubleValue]);
    double qp = ([allData[chosenTournament][homeTeam][@"QP"] doubleValue]) - ([allData[chosenTournament][awayTeam][@"QP"] doubleValue]);
    NSArray *finalData = [[NSArray alloc] initWithObjects:[NSNumber numberWithDouble:f1], [NSNumber numberWithDouble:f2], [NSNumber numberWithDouble:fts], [NSNumber numberWithDouble:mv], [NSNumber numberWithDouble:qg], [NSNumber numberWithDouble:qp], nil];
    NSLog(@"Before normalisation: \n%@",finalData);
    NSMutableArray *normalisedData = [self normaliseDataWithArray:finalData];
    NSLog(@"After normalisation: \n%@",normalisedData);
    NSArray *final = normalisedData;
    return final;
}

//Save weights after every cycle

- (void)saveWeights{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"NETMAP_weights"];
    [weightsArray writeToFile:filePath atomically:YES];
}

//Prediction code

- (void)predictResult{
    output = [NSNumber numberWithFloat:0];
    chosenData = [self constructInitialArray:NO];
    NSLog(@"Chosen Data: \n%@",chosenData);
    for (int i = 0; i < 6; i++) {
        NSNumber *input = chosenData [i];
        NSNumber *weight = weightsArray[i];
        NSNumber *finalOutput = [NSNumber numberWithFloat:[self SFwithDeriv:NO andVal:([input floatValue]*[weight floatValue])]];
        float addedOutput = [finalOutput floatValue]+[output floatValue];
        output = [NSNumber numberWithFloat: addedOutput];
    }
    NSLog(@"Forward prop result: %f", [output floatValue]);
    
    self.homeGoals.text = [NSString stringWithFormat:@"%f",[output floatValue]];
    
    //Reverse data
    
    output = [NSNumber numberWithFloat:0];
    chosenData = [self constructInitialArray:YES];
    trainingOutput = [NSNumber numberWithInt:[self.awayGoals.text intValue]];
    NSLog(@"Chosen Data: \n%@",chosenData);
    for (int i = 0; i < 6; i++) {
        NSNumber *input = chosenData [i];
        NSNumber *weight = weightsArray[i];
        NSNumber *finalOutput = [NSNumber numberWithFloat:[self SFwithDeriv:NO andVal:([input floatValue]*[weight floatValue])]];
        float addedOutput = [finalOutput floatValue]+[output floatValue];
        output = [NSNumber numberWithFloat: addedOutput];
    }
    NSLog(@"Forward prop result: %f", [output floatValue]);
    
    self.awayGoals.text = [NSString stringWithFormat:@"%f",[output floatValue]];
}

//Normalise data

- (NSMutableArray*)normaliseDataWithArray:(NSArray*)dataArray{
    float xmax = -MAXFLOAT;
    float xmin = MAXFLOAT;
    for (NSNumber *num in dataArray) {
        float x = num.floatValue;
        if (x < xmin) xmin = x;
        if (x > xmax) xmax = x;
    }
    NSMutableArray *newArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < [dataArray count]; i++) {
        float n = ([dataArray[i] floatValue] - ((xmax+xmin)/2))/((xmax-xmin)/2);
        [newArray addObject:[NSNumber numberWithFloat:n]];
    }
    return newArray;
}



@end
