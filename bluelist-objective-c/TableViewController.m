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

#import "TableViewController.h"
#import "AppDelegate.h"
#import "TodoItem.h"
#import <CloudantToolkit/CloudantToolkit.h>
#import <CDTDatastore/CloudantSync.h>
#import <IMFData/IMFData.h>
#import <IMFCore/IMFCore.h>
#import <CloudantSyncEncryption.h>

@interface TableViewController () <UITextFieldDelegate, CDTReplicatorDelegate>

@property UIImage* highImage;
@property UIImage* mediumImage;
@property UIImage* lowImage;
@property (strong, nonatomic) IBOutlet UISegmentedControl *segmentFilter;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *settingsButton;
- (IBAction)filterTable:(UISegmentedControl *)sender;

// Items in list
@property NSMutableArray *itemList;
@property NSMutableArray* filteredListItems;

// Cloud sync properties
@property CDTStore *datastore;
@property CDTStore *remotedatastore;

@property CDTReplicatorFactory *replicatorFactory;

@property CDTPullReplication *pullReplication;
@property CDTReplicator *pullReplicator;

@property CDTPushReplication *pushReplication;
@property CDTReplicator *pushReplicator;

@property BOOL doingPullReplication;

//logger property
@property IMFLogger *logger;

@end

@implementation TableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *dbPrefix = @"todosdb_";
    NSString *dbName = [NSString stringWithFormat:@"%@%@", dbPrefix, self.userId];
    self.highImage = [UIImage imageNamed:@"priorityHigh.png"];
    self.mediumImage = [UIImage imageNamed:@"priorityMedium.png"];
    self.lowImage = [UIImage imageNamed:@"priorityLow.png"];

    
    self.itemList = [[NSMutableArray alloc]init];
    self.filteredListItems = [[NSMutableArray alloc]init];
    
    // Setting up the refresh control
    self.settingsButton.enabled = false;
    self.refreshControl = [[UIRefreshControl alloc]init];
    [self.refreshControl addTarget:self action:@selector(handleRefreshAction) forControlEvents:UIControlEventValueChanged];
    
    [self.refreshControl beginRefreshing];
    [self setupIMFDatabase:dbName];
    
    //logger
    self.logger = [IMFLogger loggerForName:@"BlueList"];
    [self.logger logInfoWithMessages:@"this is a info test log in ListTableViewController:viewDidLoad"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Data Management

- (void) setupIMFDatabase:(NSString *) dbname {
    BOOL encryptionEnabled = NO;
    //Read the bluelist.plist
    NSString *configurationPath = [[NSBundle mainBundle]pathForResource:@"bluelist" ofType:@"plist"];
    NSDictionary *configuration = [NSDictionary dictionaryWithContentsOfFile:configurationPath];
    NSString *encryptionPassword = configuration[@"encryptionPassword"];
    if(!encryptionPassword || [encryptionPassword isEqualToString:@""]){
        encryptionEnabled = NO;
    }
    else{
        encryptionEnabled = YES;
        dbname = [dbname stringByAppendingString:@"secure"];
    }

    //create CDTEncryptionKeyProvider
    id<CDTEncryptionKeyProvider> keyProvider=nil;
    IMFDataManager *manager = [IMFDataManager sharedInstance];
    NSError *error = nil;
    
    
    //create a local data store. Encrypt the local store if the setting is enabled
    if(encryptionEnabled){
        //Initalize the key provider
        keyProvider = [CDTEncryptionKeychainProvider providerWithPassword:encryptionPassword forIdentifier:@"bluelist"];
        NSLog(@"Attempting to create an ecrypted local data store");
        //Initialize an encrypted local store
        self.datastore = [manager localStore:dbname withEncryptionKeyProvider:keyProvider error:&error];
    }
    else{
         self.datastore = [manager localStore:dbname error: &error];
    }
   
    if (error) {
        NSLog(@"DBCreationFailure: Could not create DB with name %@.", dbname);
        if(encryptionEnabled){
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Could not create an encrypted local store with credentials provided. Check the encryptionPassword in the bluelist.plist file." delegate:self cancelButtonTitle:@"Okay" otherButtonTitles:nil, nil];
            [alert show];
        }
    }
    else{
            NSLog(@"Local data store created successfully");
    }

    
    
    //register the TodoItem class with the CDTDataObjectMapper
    [self.datastore.mapper setDataType:@"TodoItem" forClassName:NSStringFromClass([TodoItem class])];
    if(!IBM_SYNC_ENABLE){
        [self listItems:^{
            [self.refreshControl endRefreshing];
        }];
        return;
    }
    
    //create a remote data store
    [manager remoteStore:dbname completionHandler:^(CDTStore *store, NSError *error) {
        if (error) {
            [self.logger logErrorWithMessages:@"Error creating remote data store %@",error.description];
        } else {
            self.remotedatastore = store;
            [manager setCurrentUserPermissions:DB_ACCESS_GROUP_MEMBERS forStoreName:dbname completionHander:^(BOOL success, NSError *error) {
                if (error) {
                    [self.logger logErrorWithMessages:@"Error setting permissions for user with error %@",error.description];
                }
                self.replicatorFactory = [IMFDataManager sharedInstance].replicatorFactory;
                if(encryptionEnabled) {
                    self.pullReplication   = [[IMFDataManager sharedInstance] pullReplicationForStore:dbname withEncryptionKeyProvider:keyProvider];
                    self.pushReplication   = [[IMFDataManager sharedInstance] pushReplicationForStore:dbname withEncryptionKeyProvider:keyProvider];
                }
                else{
                    self.pullReplication   = [[IMFDataManager sharedInstance] pullReplicationForStore:dbname];
                    self.pushReplication   = [[IMFDataManager sharedInstance] pushReplicationForStore:dbname];
                }
                
                [self pullItems];
            }];
        }
    }];
}

- (void)listItems: (void(^)(void)) cb
{
    [self.logger logDebugWithMessages:@"listItems called"];
    CDTQuery* query = [[CDTCloudantQuery alloc] initDataType:@"TodoItem"];
    [self.datastore performQuery: query completionHandler:^(NSArray *results,
                                                            NSError *error) {
        if(error) {
            [self.logger logErrorWithMessages:@"listItems failed with error: %@", error];
        } else {
            self.itemList = [results mutableCopy];
            [self reloadLocalTableData];
        }
        if (cb) {
            cb();
        }
    }];
}

- (void) createItem: (TodoItem*) item
{
    //save will perform a create because the item object does not exist yet in the DB.
    [self.datastore save:item completionHandler:^(NSObject *object, NSError *error) {
        if (error) {
            [self.logger logErrorWithMessages:@"createItem failed with error: %@", error];
        } else {
            [self listItems:nil];
        }
        
    }];
}
- (void) updateItem: (TodoItem*) item
{
    //save will perform a create because the CDTDocumentRevision already exists.
    [self.datastore save:item completionHandler:^(NSObject *object, NSError *error) {
        if (error) {
            [self.logger logErrorWithMessages:@"update failed with error: %@", error];        } else {
            [self listItems:nil];
        }
        
    }];
}
-(void) deleteItem: (TodoItem*) item
{
    [self.datastore delete:item completionHandler:^(NSString *deletedObjectId, NSString *deletedRevisionId, NSError *error) {
        if (error != nil) {
            [self.logger logErrorWithMessages:@"deleteItem failed with error: %@", error];        } else {
            [self listItems:nil];
        }
    }];
}


#pragma mark - Cloud Sync
// Replicate from the remote to local datastore
- (void)pullItems
{
    NSError *error = nil;
    self.pullReplicator = [self.replicatorFactory oneWay:self.pullReplication error:&error];
    if(error != nil){
        [self.logger logErrorWithMessages:@"Error creating oneWay pullReplicator %@", error];
    }
    
    self.pullReplicator.delegate = self;
    self.doingPullReplication = YES;
    self.refreshControl.attributedTitle = [[NSAttributedString alloc]initWithString:@"Pulling Items from Cloudant"];
    
    error = nil;
    NSLog(@"Replicating data with NoSQL Database on the cloud");
    [self.pullReplicator startWithError:&error];
    if(error != nil){
        [self.logger logErrorWithMessages:@"error starting pull replicator: %@", error];
    }
    
}
// Replicate data & logs from the local to remote
- (void)pushItems
{
    NSError *error = nil;
    self.pushReplicator = [self.replicatorFactory oneWay:self.pushReplication error:&error];
    if(error != nil){
        [self.logger logErrorWithMessages:@"error creating one way push replicator: %@", error];
    }
    
    self.pushReplicator.delegate = self;
    
    self.doingPullReplication = NO;
   self.refreshControl.attributedTitle = [[NSAttributedString alloc]initWithString:@"Pushing Items from Cloudant"];
    
    error = nil;
    [self.pushReplicator startWithError:&error];
    if(error != nil){
        [self.logger logErrorWithMessages:@"error starting push replicator: %@", error];
    }
}
/**
 * Called when the replicator changes state.
 */
-(void) replicatorDidChangeState:(CDTReplicator*)replicator
{
    [self.logger logInfoWithMessages:@"replicatorDidChangeState %@",[CDTReplicator stringForReplicatorState:replicator.state]];
}

/**
 * Called whenever the replicator changes progress
 */
-(void) replicatorDidChangeProgress:(CDTReplicator*)replicator
{
    [self.logger logInfoWithMessages:@"replicatorDidChangeProgress %@",[CDTReplicator stringForReplicatorState:replicator.state]];
}

/**
 * Called when a state transition to COMPLETE or STOPPED is
 * completed.
 */
- (void)replicatorDidComplete:(CDTReplicator*)replicator
{
    [self.logger logInfoWithMessages:@"replicatorDidComplete %@",[CDTReplicator stringForReplicatorState:replicator.state]];
    if(self.doingPullReplication){
        //done doing pull, lets start push
        [self pushItems];
    } else {
        //doing push, push is done read items from local data store and end the refresh UI
        [self listItems:^{
            self.refreshControl.attributedTitle = [[NSAttributedString alloc]initWithString:@"  "];
            [self.logger logInfoWithMessages:@"Done refreshing table after replication"];
            [self.refreshControl performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:YES];
            self.settingsButton.enabled = true;
        }];
    }
    
}

/**
 * Called when a state transition to ERROR is completed.
 */
- (void)replicatorDidError:(CDTReplicator*)replicator info:(NSError*)info
{
    self.refreshControl.attributedTitle = [[NSAttributedString alloc]initWithString:@"Error replicating with Cloudant"];
    NSLog(@"replicatorDidError %@",replicator.error);
    [self listItems:^{
        [self.refreshControl performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:YES];
    }];
    
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
       return self.filteredListItems.count;
    } else {
        return 1;
    }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    if( indexPath.section == 0){
        cell = [tableView dequeueReusableCellWithIdentifier:@"ItemCell" forIndexPath:indexPath];
        TodoItem *item = (TodoItem*)self.filteredListItems[indexPath.row];
        for (UIView *view in [cell.contentView subviews]) {
            if([view isKindOfClass:[UITextField class]]){
                ((UITextField*)view).text = item.name;
                ((UITextField*)view).tag = indexPath.row;
            }
        }
        cell.imageView.image = [self getPriorityImageForPriority:[item.priority integerValue]];
        cell.contentView.tag = 0;
    } else {
        cell = [tableView dequeueReusableCellWithIdentifier:@"AddCell" forIndexPath:indexPath];
        //later use to check if it's add textField
        cell.contentView.tag = 1;
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [self deleteItem:self.filteredListItems[indexPath.row]];
        [self.filteredListItems removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.section == 0) {
        [self changePriorityForCell:[self.tableView cellForRowAtIndexPath:indexPath]];
    }
}

-(void) changePriorityForCell:(UITableViewCell *) cell{
    NSInteger selectedPriority;
    NSInteger newPriority = 0;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    TodoItem *item = self.filteredListItems[indexPath.row];
    selectedPriority = [item.priority integerValue];
    newPriority = [self getNextPriority:selectedPriority];
    item.priority = [NSNumber numberWithInteger:newPriority];
    cell.imageView.image = [self getPriorityImageForPriority:newPriority];
    [self updateItem:item];
}

-(NSInteger) getNextPriority:(NSInteger) currentPriority{
    NSInteger newPriority;
    switch (currentPriority) {
        case 2:
            newPriority = 0;
            break;
        case 1:
            newPriority = 2;
            break;
        default:
            newPriority = 1;
            break;
    }
    return newPriority;
}

-(UIImage*) getPriorityImageForPriority:(NSInteger)priority{
    
    UIImage* resultImage;
    
    switch (priority) {
        case 2:
            resultImage = self.highImage;
            break;
        case 1:
            resultImage = self.mediumImage;
            break;
            
        default:
            resultImage = self.lowImage;
            break;
    }
    return resultImage;
}

-(NSInteger) getPriorityForString:(NSString *) priorityString{
    NSInteger priority;
    if([priorityString isEqualToString:@"High"]){
        priority = 2;
    } else if ([priorityString isEqualToString:@"Medium"]){
        priority = 1;
    } else {
        priority = 0;
    }
    return priority;
}


-(void) filterContentForPriority:(NSString *)scope {
    NSInteger priority = [self getPriorityForString:scope];
    
    if(priority == 1 || priority == 2){
        //filter base on priority
        NSIndexSet *matchSet = [self.itemList indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [((TodoItem *)obj).priority integerValue] == priority;
        }];
        [self.filteredListItems removeAllObjects];
        self.filteredListItems = [NSMutableArray arrayWithArray:[self.itemList objectsAtIndexes:matchSet]];
    } else {
        //don't filter select all
        [self.filteredListItems removeAllObjects];
        self.filteredListItems = [NSMutableArray arrayWithArray:self.itemList];
    }
}

- (IBAction)filterTable:(UISegmentedControl *)sender {
    [self reloadLocalTableData];
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField{
    [self handleTextFields:textField];
    return YES;
}

- (void) handleTextFields:(UITextField *)textField{
    if (textField.superview.tag == 1 && textField.text.length > 0) {
        [self addItemFromtextField:textField];
    } else {
        [self updateItemFromtextField:textField];
    }
    [textField resignFirstResponder];
}

- (void) updateItemFromtextField:(UITextField *)textField{
    UITableViewCell *cell = (UITableViewCell *)textField.superview.superview;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    TodoItem *item = self.filteredListItems[indexPath.row];
    item.name = textField.text;
    [self updateItem:item];
}

- (void) addItemFromtextField:(UITextField *)textField{
    NSInteger priority = [self getPriorityForString:[self.segmentFilter titleForSegmentAtIndex:self.segmentFilter.selectedSegmentIndex]];
    NSString *name = textField.text;
    TodoItem *item = [TodoItem alloc];
    item.name = name;
    item.priority = [NSNumber numberWithInteger:priority];
    [self createItem:item];
     textField.text = @"";
}

-(void) reloadLocalTableData
{
    [self filterContentForPriority:[self.segmentFilter titleForSegmentAtIndex:self.segmentFilter.selectedSegmentIndex]];
    [self.filteredListItems sortUsingComparator:^NSComparisonResult(TodoItem* item1, TodoItem* item2) {
        return [item1.name caseInsensitiveCompare:item2.name];
    }];
    
    [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

-(void) handleRefreshAction
{
    if(IBM_SYNC_ENABLE){
        [self pullItems];
    } else {
        [self listItems:^{
            [self.refreshControl performSelectorOnMainThread:@selector(endRefreshing) withObject:nil waitUntilDone:NO];
        }];
    }
}

@end
