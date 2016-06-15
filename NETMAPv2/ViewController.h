//
//  ViewController.h
//  NETMAPv2
//
//  Created by Rod Matveev on 14/06/2016.
//  Copyright © 2016 Rod Matveev. All rights reserved.
//

#import <UIKit/UIKit.h>
@import Firebase;

@interface ViewController : UIViewController

@property (weak,nonatomic) FIRDatabaseReference *dbRef;

@end

