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
#import "PushViewController.h"
#import <IMFPush/IMFPush.h>

@interface PushViewController ()
@end

@implementation PushViewController
NSArray *availableTags;
NSArray *subscribedTags;
UISwitch *theSwitch;
IMFPushClient *push;
IMFLogger *logger;


-(void) viewDidLoad {
    [super viewDidLoad];
    push = [IMFPushClient sharedInstance];
    [self getAvailableTags];
    //create a switch and add to accessory view
    theSwitch = [[UISwitch alloc] init];
    [theSwitch addTarget:self action:@selector(notificationsSwitchChanged:) forControlEvents:UIControlEventValueChanged];
}
- (IBAction)performDone:(id)sender {
    [[self presentingViewController] dismissViewControllerAnimated:true completion:^{
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    if (section == 0) {
        return 1;
    } else {
        return availableTags.count;
                
    }
}

-(UITableViewCell *) tableView:(UITableView *) tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    if (indexPath.section == 0) {
        //define cell
        cell = [self.tableView dequeueReusableCellWithIdentifier:@"PushCell" forIndexPath:indexPath];
        cell.accessoryView = theSwitch;
        //see if device is subscribed for all push notifications
        if ([self isPushEnabled]) {
            theSwitch.on = true;
        } else {
            theSwitch.on = false;
        }
    } else {
        //define cell
        cell = [self.tableView dequeueReusableCellWithIdentifier:@"TagCell" forIndexPath:indexPath];
        //add label to cell
        NSString *subscriptionTag = availableTags[indexPath.row];
        cell.textLabel.text = subscriptionTag;
        cell.accessoryView.hidden = false;
        //get checkmark value from user preference
        if ([self isTagSubscribed:subscriptionTag]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellSelectionStyleNone;
        }
    }
    return cell;
}

//if the push notifications switch changed, this gets called
-(void) notificationsSwitchChanged:(UISwitch *)sender {
    UIApplication *application = [UIApplication sharedApplication];
    if (sender.on) {
        [self registerForPushNotifications:application];
    } else {
        [self unregisterForPushNotifications:application];
    }
}

//on selection of subscription notifications
-(void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 0 && theSwitch.on) {
        [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:NO];
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        //toggle the checkmark, subscribe or unsubscribe from tags, set user defaults
        if (cell.accessoryType == UITableViewCellSelectionStyleNone) {
            [self subscribeTag:availableTags[indexPath.row]];
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            [self unsubscribeTag:availableTags[indexPath.row]];
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
}

- (void) subscribeTag: (NSString *) theTag {
    NSArray *tagArray = [NSArray arrayWithObject:theTag];
    [push subscribeToTags:tagArray completionHandler:^(IMFResponse *response, NSError *error) {
        if (error != nil) {
            [logger logErrorWithMessages:@"Error push subscribeToTags %@",error.description];
        }
    }];
}
- (void) unsubscribeTag:(NSString *) theTag {
    NSArray *tagArray = [NSArray arrayWithObject:theTag];
    [push unsubscribeFromTags:tagArray completionHandler:^(IMFResponse *response, NSError *error) {
        if (error != nil) {
            [logger logErrorWithMessages:@"Error in unsubscribing to tags %@",error.description];
        }
    }];
}

- (void) getAvailableTags {
    [push retrieveAvailableTagsWithCompletionHandler:^(IMFResponse *response, NSError *error) {
        if (error != nil) {
            [logger logErrorWithMessages:@"Error push retrieveAvailableTagsWithCompletionHandler %@",error.description];
        } else {
            availableTags = [response availableTags];
            [self getSubscribedTags];
        }
    }];
}

- (void) getSubscribedTags {
    [push retrieveSubscriptionsWithCompletionHandler:^(IMFResponse *response, NSError *error) {
        if (error != nil) {
            [logger logErrorWithMessages:@"Error push retrieveSubscriptionsWithCompletionHandler %@",error.description];
        } else {
            NSDictionary *subscriptions = [response subscriptions];
            subscribedTags = subscriptions[@"subscriptions"];
            [[self tableView] reloadData];
        }
    }];
}

- (BOOL) isTagSubscribed: (NSString *) tag {
    for (NSString *subscribedTag in subscribedTags) {
        if ([subscribedTag isEqualToString:tag]) {
            return true;
        }
    }
    return false;
}

- (BOOL) isPushEnabled {
    return [self isTagSubscribed:@"Push.ALL"];
}

- (void) registerForPushNotifications:(UIApplication *) application {
    //Registering for remote Notifications must be done after User is Authenticated
    //setup push with interactive notifications
    UIMutableUserNotificationAction *acceptAction = [[UIMutableUserNotificationAction alloc] init];
    acceptAction.identifier = @"ACCEPT_ACTION";
    acceptAction.title = @"Accept";
    acceptAction.activationMode = UIUserNotificationActivationModeForeground;
    
    UIMutableUserNotificationAction *declineAction = [[UIMutableUserNotificationAction alloc] init];
    declineAction.identifier = @"DECLINE_ACTION";
    declineAction.title = @"Decline";
    declineAction.destructive = YES;
    declineAction.activationMode = UIUserNotificationActivationModeBackground;
    
    UIMutableUserNotificationCategory *pushCategory = [[UIMutableUserNotificationCategory alloc] init];
    pushCategory.identifier = @"TODO_CATEGORY";
    [pushCategory setActions:@[acceptAction, declineAction] forContext:UIUserNotificationActionContextDefault];
    NSSet *categories = [NSSet setWithArray:@[pushCategory]];
    
    [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:categories]];
    
    if ([[UIDevice currentDevice].model hasPrefix:@"Simulator"]) {
        [logger logInfoWithMessages:@"Running on Simulator skiping remote push notifications"];
    } else {
        [logger logInfoWithMessages:@"Running on Device registering for push notifications"];
        [application registerForRemoteNotifications];
    }
}

- (void) unregisterForPushNotifications:(UIApplication *) application {
    //unregister the application for push notifications
    IMFPushClient *push = [IMFPushClient sharedInstance];
    [push unregisterDevice:^(IMFResponse *response, NSError *error) {
        if (error != nil) {
            [logger logInfoWithMessages:@"Error during device registration %@",error.description];
            return;
        }
        [logger logInfoWithMessages:@"Succesfully Unregistered Device"];
        [application unregisterForRemoteNotifications];
        [self getAvailableTags];
    }];
}

@end
