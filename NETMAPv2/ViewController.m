//
//  ViewController.m
//  NETMAPv2
//
//  Created by Rod Matveev on 14/06/2016.
//  Copyright © 2016 Rod Matveev. All rights reserved.
//

#import "ViewController.h"
@import Firebase;

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    //Creating ref to NETMAP database
    self.dbRef = [[FIRDatabase database] reference];
    
    [self fetchTournamentData];
}

- (void)fetchTournamentData{
    [[self.dbRef child:@"Euro Data"] observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
        
        NSLog(@"2012 CZE:%@",snapshot.value[@"2012"][@"CZE"]);
        
    } withCancelBlock:^(NSError * _Nonnull error) {
        NSLog(@"%@", error.localizedDescription);
    }];
    
}


@end
