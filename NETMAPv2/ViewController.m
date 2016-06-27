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
    NSMutableArray *weights1;
    NSMutableArray *weights2;
    NSArray *chosenData;
    NSNumber *output;
    NSNumber *trainingOutput;
    BEMSimpleLineGraphView *weightsGraph;
    PNBarChart *barChart;
    PNLineChart *lineChart;
    NSMutableArray *errorArray;
    NSMutableArray *errorArrayReverse;
    NSMutableArray *errorAverages;
    NSMutableArray *countArray;
    int trainingCount;
    NSArray *euro2016;
    int automatedCount;
    BOOL reverseAuto;
    NSTimer *automationTimer;
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
    
    //Try sigmoid
    float sig = [self SFwithDeriv:YES andVal:1.2];
    NSLog(@"Sig: %f",sig);
    
    errorArray = [[NSMutableArray alloc] init];
    errorAverages = [[NSMutableArray alloc] init];
    countArray = [[NSMutableArray alloc] init];
    
    trainingCount = 0;
    automatedCount = 0;
    reverseAuto = NO;
    
    //Check if weights are saved
    NSMutableArray *savedWeights1 = [[NSUserDefaults standardUserDefaults] objectForKey:@"Weights1"];
    NSMutableArray *savedWeights2 = [[NSUserDefaults standardUserDefaults] objectForKey:@"Weights2"];
    NSLog(@"Saved weights:\n%@\n%@",savedWeights1,savedWeights2);
    weights1 = [[NSMutableArray alloc] initWithArray:savedWeights1];
    weights2 = [[NSMutableArray alloc] initWithArray:savedWeights2];
    
    //Set up db for automated training
    [self create2016DatabaseForAutomatedTraining];
}

- (void)viewDidAppear:(BOOL)animated{
    [self setUpWeightChart];
    [self setUpErrorChart];
    barChart.alpha = 0;
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
    [barChart setXLabels:@[@"w1",@"w2",@"w3"]];
    [barChart setYValues:@[weights2[0],weights2[1],weights2[2]]];
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
    barChart.alpha = 0;
}

- (void)updateWeightChart{
    [barChart setXLabels:@[@"w1",@"w2",@"w3"]];
    [barChart setYValues:@[weights2[0],weights2[1],weights2[2]]];
    NSNumber* highestWeight;
    for (int i = 0; i < 3; i++) {
        if(i == 0){
            highestWeight = weights2[0];
        }else{
            NSNumber *weight = weights2[i];
            if([weight floatValue] > [highestWeight floatValue]){
                highestWeight = weight;
            }
        }
    }
    barChart.yMaxValue = [highestWeight floatValue] + 2;
}

- (void)setUpErrorChart{
    lineChart = [[PNLineChart alloc] initWithFrame:self.rightGraph.frame];
    [lineChart setXLabels:@[@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",@"",]];
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
    home.itemCount = [errorAverages count];
    //home.inflexionPointColor = [UIColor colorWithRed:1.000 green:0.373 blue:0.427 alpha:1.00];
    //home.inflexionPointStyle = PNLineChartPointStyleCircle;
    home.getData = ^(NSUInteger index){
        NSNumber *error = errorAverages[index];
        CGFloat yValue = [error floatValue];
        return [PNLineChartDataItem dataItemWithY:yValue];
    };
    
    NSNumber* highestError;
    for (int i = 0; i < [errorAverages count]; i++) {
        if(i == 0){
            highestError = errorAverages[0];
        }else{
            NSNumber *error = errorAverages[i];
            if([error floatValue] > [highestError floatValue]){
                highestError = error;
            }
        }
    }
    lineChart.yFixedValueMax = [highestError floatValue] +0.1;
    lineChart.chartData = @[home];
    [lineChart strokeChart];
    NSLog(@"Updated error chart");
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
    //For 2 Layer
    
    /*weightsArray = nil;
    weightsArray = [[NSMutableArray alloc]init];
    for (int i=0; i<6; i++) {
        float range = 0.6 + 0.6;
        float val = ((float)arc4random() / ARC4RANDOM_MAX) * range + 0.4;
        val -= 1.2;
        [weightsArray addObject:[NSNumber numberWithFloat:val]];
    }
    NSLog(@"Random weights: \n%@",weightsArray);*/
    
    //For 3 Layer
    
    NSArray * tempWeights1Array = @[
                     @[[self grv],[self grv],[self grv]],
                     @[[self grv],[self grv],[self grv]],
                     @[[self grv],[self grv],[self grv]],
                     @[[self grv],[self grv],[self grv]],
                     @[[self grv],[self grv],[self grv]],
                     @[[self grv],[self grv],[self grv]]
                     ];
    NSArray * tempWeights2Array = @[
                                    [self grv],
                                    [self grv],
                                    [self grv]
                                    ];
    
    NSLog(@"w1:\n%@\nw2:\n%@",tempWeights1Array,tempWeights2Array);
    weights1 = [[NSMutableArray alloc] initWithArray:tempWeights1Array];
    weights2 = [[NSMutableArray alloc] initWithArray:tempWeights2Array];
}

- (NSNumber*)grv{
    float range = 1.40 + 1.40;
    float val = ((float)arc4random() / ARC4RANDOM_MAX) * range + 1.40;
    val -= 2.8;
    return [NSNumber numberWithFloat:val];
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
        float weightChange;
        if(outputError < 0){
            outputError *= -1;
            weightChange = powf(((outputError * outputDeriv)+1), outputError);
            weightChange *= -1;
        }else{
            weightChange = powf(((outputError * outputDeriv)+1), outputError);
        }
        NSLog(@"Weight change: %f",weightChange);
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
    }
}

//3 Layers

- (IBAction)ready3Layer:(id)sender{
    if([mode isEqualToString:@"Prediction"]){
        [self predictResult];
    }else{
        output = [NSNumber numberWithFloat:0];
        chosenData = [self constructInitialArray:NO];
        //trainingOutput = [NSNumber numberWithInt:[self.homeGoals.text intValue]];
        trainingOutput = [NSNumber numberWithFloat:[self normaliseInput]];
        NSLog(@"Training output: %@",trainingOutput);
        
        //Calculate hidden layer output
        
        NSMutableArray *hiddenLayerOutput = [[NSMutableArray alloc] init];
        for (int i = 0; i < 3; i++) {
            float sum = 0;
            for (int j = 0; j < 6; j++) {
                NSNumber* inputVal = chosenData[j];
                NSNumber* hiddenLayerWeight = weights1[j][i];
                sum += ([inputVal floatValue] * [hiddenLayerWeight floatValue]);
            }
            [hiddenLayerOutput addObject:[NSNumber numberWithFloat:sum]];
        }
        NSLog(@"Hidden layer output:\n%@",hiddenLayerOutput);
        
        //Calculate final output
        
        NSNumber *finalOutput;
        float sum = 0;
        for (int i = 0; i < 3; i++) {
            NSNumber *hiddenLayerNum = hiddenLayerOutput[i];
            NSNumber *outputWeight = weights2[i];
            sum += [hiddenLayerNum floatValue] * [outputWeight floatValue];
        }
        finalOutput = [NSNumber numberWithFloat:sum];
        NSLog(@"Final output: %@",finalOutput);
        float reverseNormalisedOutput = [self reverseNormaliseOutputWithFloat:[finalOutput floatValue]];
        self.awayGoals.text = [NSString stringWithFormat:@"%f",reverseNormalisedOutput];
        
        //Calculate error of final output
        
        NSNumber *error = [NSNumber numberWithFloat:[trainingOutput floatValue] - [finalOutput floatValue]];
        NSLog(@"Error: %@",error);
        
        //Calculate weight change
        
        NSNumber *weightChangeLayer2 = [NSNumber numberWithFloat:[error floatValue] * [self SFwithDeriv:YES andVal:[finalOutput floatValue]]];
        NSLog(@"Weight change: %@",weightChangeLayer2);
        
        //Calculate error of 1st layer (contribution of layer 1 to final output error)
        
        NSNumber *weight2_1 = weights2[0];
        NSNumber *weight2_2 = weights2[1];
        NSNumber *weight2_3 = weights2[2];
        NSArray *errorLayer1 = @[[NSNumber numberWithFloat:([weightChangeLayer2 floatValue] * [weight2_1 floatValue])],[NSNumber numberWithFloat:([weightChangeLayer2 floatValue] * [weight2_2 floatValue])],[NSNumber numberWithFloat:([weightChangeLayer2 floatValue] * [weight2_3 floatValue])]];
        NSLog(@"Error 1st layer: %@", errorLayer1);
        
        //Calculate weight change for first weights
        
        NSMutableArray *weightChangeLayer1 = [[NSMutableArray alloc] init];
        for (int i = 0; i < 3; i++) {
            NSNumber *e = errorLayer1[i];
            NSNumber *hlo = hiddenLayerOutput[i];
            NSNumber *w = [NSNumber numberWithFloat:([e floatValue] * [self SFwithDeriv:YES andVal:[hlo floatValue]])];
            [weightChangeLayer1 addObject:w];
        }
        NSLog(@"Weight change layer 1:/n%@",weightChangeLayer1);
        
        // Adjust layer 2 weights
        
        NSNumber * hidden1 = hiddenLayerOutput[0];
        NSNumber * hidden2 = hiddenLayerOutput[1];
        NSNumber * hidden3 = hiddenLayerOutput[2];
        NSArray *change = @[[NSNumber numberWithFloat:([weightChangeLayer2 floatValue] * [hidden1 floatValue])],[NSNumber numberWithFloat:([weightChangeLayer2 floatValue] * [hidden2 floatValue])],[NSNumber numberWithFloat:([weightChangeLayer2 floatValue] * [hidden3 floatValue])]];
        for (int i = 0; i < 3; i++) {
            NSNumber *changeNum = change[i];
            NSNumber *weight2Num = weights2[i];
            [weights2 setObject:[NSNumber numberWithFloat:[changeNum floatValue]+[weight2Num floatValue]] atIndexedSubscript:i];
        }
        NSLog(@"Final hidden to output weights:\n%@",weights2);
        
        //Adjust layer 1 weights
        
        NSMutableArray *tempChange = [[NSMutableArray alloc] init];
        
        for (int j = 0; j < 6; j++) {
            NSNumber *input = chosenData[j];
            NSNumber *w1 = weightChangeLayer1[0];
            NSNumber *w2 = weightChangeLayer1[1];
            NSNumber *w3 = weightChangeLayer1[2];
            NSNumber *l1w_1 = weights1[j][0];
            NSNumber *l1w_2 = weights1[j][1];
            NSNumber *l1w_3 = weights1[j][2];
            NSArray *row = @[[NSNumber numberWithFloat:([input floatValue] * [w1 floatValue])+[l1w_1 floatValue]],[NSNumber numberWithFloat:([input floatValue] * [w2 floatValue])+[l1w_2 floatValue]],[NSNumber numberWithFloat:([input floatValue] * [w3 floatValue])+[l1w_3 floatValue]]];
            [tempChange addObject:row];
        }
        if([errorAverages count] > 50){
            [errorAverages removeObjectAtIndex:0];
        }
        weights1 = tempChange;
        NSLog(@"Final input to hidden weights:\n%@",weights1);
        
        //Display results & Save
        
        if ([error floatValue] < 0) {
            error = [NSNumber numberWithFloat:[error floatValue] * -1];
        }
        trainingCount++;
        self.trialCount.text = [NSString stringWithFormat:@"(%d)",trainingCount];
        if([errorArray count] > 75){
            [errorArray removeObjectAtIndex:0];
        }
        [countArray addObject:[NSNumber numberWithInt:trainingCount]];
        [errorArray addObject:error];
        if ([errorArray count] % 10 == 0) {
            float total;
            total = 0;
            for(NSNumber *value in errorArray){
                total+=[value floatValue];
            }
            [errorAverages addObject:[NSNumber numberWithFloat:total/10]];
            [self updateErrorChart];
            [errorArray removeAllObjects];
        }
        NSLog(@"Error averages array:\n%@",errorAverages);
        [self updateWeightChart];
        [self saveWeights];
    }
}

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
    NSLog(@"Home team: %@\nAway team: %@",self.homeTeam.text,self.awayTeam.text);
    int previousTournament = [chosenTournament intValue] - 4;
    double f1 = ([allData[chosenTournament][homeTeam][@"F1"] doubleValue]) - ([allData[chosenTournament][awayTeam][@"F1"] doubleValue]);
    f1 /= 10;
    double f2 = ([allData[chosenTournament][homeTeam][@"F2"] doubleValue]) - ([allData[chosenTournament][awayTeam][@"F2"] doubleValue]);
    f2 /= 10;
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
    fts /= 10;
    double mv = ([allData[chosenTournament][homeTeam][@"MV"] doubleValue]) - ([allData[chosenTournament][awayTeam][@"MV"] doubleValue]);
    mv /= 100;
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
    [[NSUserDefaults standardUserDefaults] setObject:weights1 forKey:@"Weights1"];
    [[NSUserDefaults standardUserDefaults] setObject:weights2 forKey:@"Weights2"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

//Prediction code

- (void)predictResult{
    output = [NSNumber numberWithFloat:0];
    chosenData = [self constructInitialArray:NO];
    NSMutableArray *trainedWeights1 = [[NSUserDefaults standardUserDefaults] objectForKey:@"Weights1"];
    NSMutableArray *trainedWeights2 = [[NSUserDefaults standardUserDefaults] objectForKey:@"Weights2"];
    
    //Calculate hidden layer output
    
    NSMutableArray *hiddenLayerOutput = [[NSMutableArray alloc] init];
    for (int i = 0; i < 3; i++) {
        float sum = 0;
        for (int j = 0; j < 6; j++) {
            NSNumber* inputVal = chosenData[j];
            NSNumber* hiddenLayerWeight = trainedWeights1[j][i];
            sum += ([inputVal floatValue] * [hiddenLayerWeight floatValue]);
        }
        [hiddenLayerOutput addObject:[NSNumber numberWithFloat:sum]];
    }
    NSLog(@"Hidden layer output:\n%@",hiddenLayerOutput);
    
    //Calculate final output
    
    NSNumber *finalOutput;
    float sum = 0;
    for (int i = 0; i < 3; i++) {
        NSNumber *hiddenLayerNum = hiddenLayerOutput[i];
        NSNumber *outputWeight = trainedWeights2[i];
        sum += [hiddenLayerNum floatValue] * [outputWeight floatValue];
    }
    finalOutput = [NSNumber numberWithFloat:sum];
    NSLog(@"Final predicted output: %@",finalOutput);
    float reverseNormalisedOutput = [self reverseNormaliseOutputWithFloat:[finalOutput floatValue]];
    self.homeGoals.text = [NSString stringWithFormat:@"%f",reverseNormalisedOutput];
    self.awayGoals.text = @"";
}

//Normalisation code

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
        /*float n = ([dataArray[i] floatValue] - ((xmax+xmin)/2))/((xmax-xmin)/2);
        [newArray addObject:[NSNumber numberWithFloat:n]];*/
        float n = ([dataArray[i] floatValue] - xmin)/(xmax - xmin);
        [newArray addObject:[NSNumber numberWithFloat:n]];
    }
    return newArray;
}

- (float)normaliseInput{
    float normalisedInput;
    float xmax = 3;
    float xmin = 0;
    //normalisedInput = ([self.homeGoals.text intValue] - ((xmax+xmin)/2))/((xmax-xmin)/2);
    normalisedInput = ([self.homeGoals.text intValue] - xmin)/(xmax - xmin);
    return normalisedInput;
}

- (float)reverseNormaliseOutputWithFloat:(float)outputVal{
    //float goals = (outputVal*(5) + 5)/2;
    float goals = (outputVal*(3));
    return goals;
}

//2016 data

- (void)create2016DatabaseForAutomatedTraining{
    euro2016 = @[@[@"FRA",@2,@"ROM",@1],@[@"ALB",@0,@"SWI",@1],@[@"ROM",@1,@"SWI",@2],@[@"FRA",@2,@"ALB",@0],@[@"ROM",@1,@"ALB",@1],@[@"FRA",@2,@"SWI",@1],@[@"WAL",@2,@"SLO",@1],@[@"ENG",@2,@"RUS",@1],@[@"RUS",@1,@"SLO",@2],@[@"ENG",@2,@"WAL",@1],@[@"RUS",@0,@"WAL",@3],@[@"SLO",@0,@"ENG",@1],@[@"POL",@1,@"NOR",@0],@[@"GER",@2,@"UKR",@0],@[@"UKR",@1,@"NOR",@1],@[@"GER",@1,@"POL",@0],@[@"NOR",@0,@"GER",@2],@[@"UKR",@0,@"POL",@1],@[@"TUR",@0,@"CRO",@1],@[@"SPA",@2,@"CZE",@0],@[@"CZE",@2,@"CRO",@2],@[@"SPA",@3,@"TUR",@0],@[@"CRO",@1,@"SPA",@2],@[@"CZE",@1,@"TUR",@2],@[@"REP",@1,@"SWE",@1],@[@"BEL",@2,@"ITA",@2],@[@"ITA",@2,@"SWE",@0],@[@"BEL",@3,@"REP",@0],@[@"ITA",@2,@"REP",@1],@[@"SWE",@0,@"BEL",@2],@[@"AUS",@2,@"HUN",@1],@[@"POR",@2,@"ICE",@1],@[@"ICE",@1,@"HUN",@1],@[@"POR",@1,@"AUS",@0],@[@"ICE",@1,@"AUS",@1]];
    NSLog(@"2016:\n%@",euro2016);
}

//Automated training code

- (IBAction)startAutomatedTraining:(id)sender{
    automationTimer = [NSTimer scheduledTimerWithTimeInterval:0.20
                                                       target:self
                                                     selector:@selector(inputData)
                                                     userInfo:nil
                                                      repeats:YES];
    
}

- (IBAction)pauseAutomatedTraining:(id)sender{
    [automationTimer invalidate];
}

- (void)inputData{
    if(automatedCount == ([euro2016 count] - 1)){
        automatedCount = 0;
    }
    if(reverseAuto == NO){
        self.homeTeam.text = euro2016[automatedCount][0];
        self.awayTeam.text = euro2016[automatedCount][2];
        NSNumber *home = euro2016[automatedCount][1];
        self.homeGoals.text = [NSString stringWithFormat:@"%d",[home intValue]];
        reverseAuto = YES;
        [self ready3Layer:self];
    }else{
        self.homeTeam.text = euro2016[automatedCount][2];
        self.awayTeam.text = euro2016[automatedCount][0];
        NSNumber *home = euro2016[automatedCount][3];
        self.homeGoals.text = [NSString stringWithFormat:@"%d",[home intValue]];
        reverseAuto = NO;
        automatedCount ++;
        [self ready3Layer:self];
    }
}


@end
