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


#import <Foundation/Foundation.h>
#import "AuthenticationViewController.h"
#import "AppDelegate.h"
#import "TableViewController.h"
#import <IMFCore/IMFCore.h>

@interface AuthenticationViewController() 

@property (strong, nonatomic) IBOutlet UILabel *progressLabel;
@property (strong, nonatomic) IBOutlet UITextView *errorTextView;
@property NSString *userId;
@property IMFLogger *logger;

@end

@implementation AuthenticationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self authenticateUser];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)authenticateUser {
    [self.logger logInfoWithMessages:@"Trying to authenticateUser"];
    self.progressLabel.text = @"Authenticating";
    if ([self checkIMFClient] && [self checkAuthenticationConfig]) {
        [self getAuthToken];
    }
}

- (void) getAuthToken {
    IMFAuthorizationManager *authManager = [IMFAuthorizationManager sharedInstance];
    [authManager obtainAuthorizationHeaderWithCompletionHandler:^(IMFResponse *response, NSError *error) {
        NSMutableString *errorMsg = [[NSMutableString alloc] init];
        if (error != nil) {
            [errorMsg appendString:@"Error obtaining Authentication Header.\nCheck Bundle Identifier and Bundle version string, short in Info.plist match exactly to the ones in AMA, or check the applicationId in bluelist.plist\n\n"];
            if (response != nil) {
                [errorMsg appendString:response.responseText];
            }
            if (error != nil && error.userInfo != nil) {
                [errorMsg appendString:error.userInfo.description];
            }
            [self invalidAuthentication:errorMsg];

        } else {
            //lets make sure we have an user id before transitioning, IMFDataManager needs this for permissions
            if (authManager.userIdentity != nil) {
                NSString *userId = [authManager.userIdentity valueForKey:@"id"];
                if (userId != nil) {
                    self.userId = userId;
                    [self.logger logInfoWithMessages:@"Authenticated user with id %@",userId];
                    //user is authenticated show main UI
                    [self showMainApplication];
                    UIApplication *mainApplication = [UIApplication sharedApplication];
                    if (mainApplication.delegate != nil) {
                        AppDelegate *delegate = mainApplication.delegate;
                        delegate.isUserAuthenticated = YES;
                    }
                } else {
                    [self invalidAuthentication:@"Valid Authentication Header and userIdentity, but id not found"];
                }
            } else {
                [self invalidAuthentication:@"Valid Authentication Header, but userIdentity not found. You have to configure one of the methods available in Advanced Mobile Service on Bluemix, such as Facebook, Google, or Custom "];
            }
        }
    }];
}

- (BOOL) checkIMFClient {
    IMFClient *imfclient = [IMFClient sharedInstance];
    NSString *route = imfclient.backendRoute;
    NSString *uid = imfclient.backendGUID;
    
    if (route == nil || route.length == 0) {
        [self invalidAuthentication:@"Invalid Route.\n Check applicationRoute in bluelist.plist"];
        return false;
    }
    if (uid == nil || uid.length == 0) {
        [self invalidAuthentication:@"Invalid UID.\n Check applicationId in bluelist.plist"];
        return false;
    }
    return true;
}

- (BOOL) checkAuthenticationConfig {
    if ([self isFacebookConfigured]) {
        self.progressLabel.text = @"Facebook Login";
        return true;
    }
    else if ([self isCustomConfigured]) {
        self.progressLabel.text = @"Custom Login";
        return true;
    }
    else if ([self isGoogleConfigured]) {
        self.progressLabel.text = @"Google Login";
        return true;
    }
    
    
    [self invalidAuthentication:@"Authentication is not configured in Info.plist. You have to configure Info.plist with the same Authentication method configured on Bluemix such as Facebook, Google, or Custom. Check the README.md file for more instructions"];
    return false;
}

-(BOOL) isFacebookConfigured {
    NSString *facebookAppId = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"FacebookAppID"];
    NSString *facebookDisplayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"FacebookDisplayName"];
    NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    NSDictionary *urlTypes0 = urlTypes[0];
    NSArray *urlSchemes = urlTypes0[@"CFBundleURLSchemes"];
    NSString *facebookURLScheme = urlSchemes[0];
    
    if (facebookAppId == nil || [facebookAppId isEqualToString:@""] || [facebookAppId isEqualToString:@"123456789"]) {
        return false;
    }
    if (facebookDisplayName == nil || [facebookDisplayName isEqualToString:@""]) {
        return false;
    }
    if (facebookURLScheme == nil || [facebookURLScheme isEqualToString:@""] || [facebookURLScheme isEqualToString:@"fb123456789"] || ![facebookURLScheme hasPrefix:@"fb"]) {
        return false;
    }
    [self.logger logInfoWithMessages:@"Facebook Authentication Configured:\nFacebookAppID %@\nFacebookDisplayName %@\nFacebookURLScheme %@",facebookAppId,facebookDisplayName,facebookURLScheme];
    return true;
}

-(BOOL) isGoogleConfigured {
    NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    NSDictionary *urlTypes1 = urlTypes[1];
    NSString *urlIdentifier = urlTypes1[@"CFBundleURLName"];
    NSArray *urlSchemes = urlTypes1[@"CFBundleURLSchemes"];
    NSString *googleURLScheme = urlSchemes[0];
    
    if (urlIdentifier == nil || [urlIdentifier isEqualToString:@""]) {
        return false;
    }
    if (googleURLScheme == nil || googleURLScheme.length == 0 || ![googleURLScheme isEqualToString:urlIdentifier]) {
        return false;
    }
    [self.logger logInfoWithMessages:@"Google Authentication Configured:\nURL Identifier %@\nURL Scheme %@",urlIdentifier,googleURLScheme];
    return true;
}

-(BOOL) isCustomConfigured {
    NSString *customAuthenticationRealm = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CustomAuthenticationRealm"];
    if (customAuthenticationRealm == nil || [customAuthenticationRealm isEqualToString:@""]) {
        return false;
    }
    [self.logger logInfoWithMessages:@"Custom Authentication Configured:\nCustomAuthenticationRealm %@",customAuthenticationRealm];
    return true;
}

-(void) invalidAuthentication:(NSString *)message {
    self.progressLabel.text = @"Error Authenticating";
    self.errorTextView.text = @"";
    self.errorTextView.text = [self.errorTextView.text stringByAppendingString:message];
    [self.logger logErrorWithMessages:message];
    
    if([[UIApplication sharedApplication] delegate] != nil) {
        AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
        [delegate clearKeychain];
    }
}

-(void) showMainApplication {
    [self performSegueWithIdentifier:@"authenticationSegue" sender:self];
}

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    UINavigationController *navVC = segue.destinationViewController;
    TableViewController *listTableVC = (TableViewController *) navVC.topViewController;
    listTableVC.userId = self.userId;
}

@end
