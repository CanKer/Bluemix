// Copyright 2014, 2015 IBM Corp. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "CustomAuth.h"


@interface CustomAuth ()
@property id<IMFAuthenticationContext> currentContext;
@end

@implementation CustomAuth

@synthesize currentContext;

- (void) authenticationContext:(id<IMFAuthenticationContext>)context didReceiveAuthenticationChallenge:(NSDictionary *)challenge {
    [self setCurrentContext:context];
    [self showLoginEntryAlert];
}

- (void) authenticationContext:(id<IMFAuthenticationContext>)context didReceiveAuthenticationFailure:(NSDictionary *)userInfo {
    NSLog(@"CustomAuth authenticationContext failure");
}

- (void) authenticationContext:(id<IMFAuthenticationContext>)context didReceiveAuthenticationSuccess:(NSDictionary *)userInfo {
    NSLog(@"CustomAuth authenticationContext sucess");
}

- (void)showLoginEntryAlert {
    UIWindow *window = UIApplication.sharedApplication.delegate.window;
    UIViewController *vc = [(UINavigationController *)window.rootViewController visibleViewController];
    
    NSString *title = NSLocalizedString(@"MobileFirst", nil);
    NSString *cancelButtonTitle = NSLocalizedString(@"Cancel", nil);
    NSString *otherButtonTitle = NSLocalizedString(@"OK", nil);
    
    __block UITextField *usernameTextField;
    __block UITextField *passwordTextField;
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    // Add the text field for username entry.
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        usernameTextField = textField;
        usernameTextField.placeholder = NSLocalizedString(@"username", nil);
        usernameTextField.secureTextEntry = NO;
    }];
    
    // Add the text field for password entry.
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        passwordTextField = textField;
        passwordTextField.placeholder = NSLocalizedString(@"password", nil);
        passwordTextField.secureTextEntry = YES;
    }];
    
    // Create the actions.
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:cancelButtonTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self showLoginEntryAlert];
    }];
    
    UIAlertAction *otherAction = [UIAlertAction actionWithTitle:otherButtonTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSLog(@"Submitting auth...");
         [currentContext submitAuthenticationChallengeAnswer:[NSDictionary dictionaryWithObjects:@[usernameTextField.text, passwordTextField.text] forKeys:@[@"userName", @"password"]]];
    }];
    
    // Add the actions.
    [alertController addAction:cancelAction];
    [alertController addAction:otherAction];
    
    [vc presentViewController:alertController animated:YES completion:nil];
}

@end