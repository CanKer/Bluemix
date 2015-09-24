//
//  Principal.m
//  bluelist-objective-c
//
//  Created by Jorge Arturo César Martínez on 23/09/15.
//  Copyright © 2015 IBM. All rights reserved.
//

#import "Principal.h"
#import "SWRevealViewController.h"

@interface Principal()

@end
@implementation Principal

-(void)viewDidLoad	{
    [super viewDidLoad];
    _barButtonL.target = self.revealViewController;
    _barButtonL.action = @selector(revealToggle:);
    
    [self.view addGestureRecognizer:self.revealViewController.panGestureRecognizer];
}

-(void)didReceiveMemoryWarning  {
    [super didReceiveMemoryWarning];
}

@end
