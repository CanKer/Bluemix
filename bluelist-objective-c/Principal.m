//
//  Principal.m
//  bluelist-objective-c
//
//  Created by Jorge Arturo César Martínez on 23/09/15.
//  Copyright © 2015 IBM. All rights reserved.
//

#import "Principal.h"
#import "SWRevealViewController.h"

@implementation Principal

-(void)viewDidLoad  {
    SWRevealViewController *revealViewController = self.revealViewController;
    if ( revealViewController )
    {
        [self.buttonL setTarget: self.revealViewController];
        [self.buttonL setAction: @selector( revealToggle: )];
        [self.view addGestureRecognizer:self.revealViewController.panGestureRecognizer];
        
        [self.buttonR setTarget: self.revealViewController];
        [self.buttonR setAction: @selector( rightRevealToggle: )];
        [self.view addGestureRecognizer:self.revealViewController.panGestureRecognizer];
    }
}


@end
