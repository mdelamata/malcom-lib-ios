//
//  MCMCampaignsManager.m
//  MalcomLib
//
//  Created by Alfonso Miranda Castro on 25/01/13.
//  Copyright (c) 2013 Malcom. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "MCMCampaignsManager.h"
#import "MCMCoreSingleton.h"
#import "MCMASIHTTPRequest.h"
#import "MCMASIDownloadCache.h"
#import "MCMStatsLocatorService.h"
#import "MCMCoreUtils.h"
#import "MCMCoreAPIRequest.h"
#import "MCMCoreManager.h"
#import "MCMCore.h"
#import "MCMCampaignDTO.h"
#import "MCMCampaignBannerViewController.h"
#import "MCMCoreUtils.h"
#import "MCMCampaignsHelper.h"
#import "MCMCampaignsDefines.h"

typedef void(^CompletionBlock)(NSArray* campaignBannersVC);
typedef void(^ErrorBlock)(NSString* errorMessage);

@interface MCMCampaignsManager () <MCMCampaignBannerViewControllerDelegate>

- (void)requestCampaign;
- (void)processCampaignResponse:(NSArray *)items;
- (void)displayCampaign:(MCMCampaignDTO *)campaign;
- (void)showBanner:(MCMCampaignBannerViewController *)bannerViewController;
- (void)appDidBecomeActiveNotification:(NSNotification *)notification;
- (void)hideCampaignView;
- (void)finishCampaignView;
- (void)notifyErrorLoadingCampaign:(NSString *)errorMessage;
- (UIView *)getContainerViewForCurrentBanner;


@property (nonatomic, retain) UIView *campaignContainerView;    //view that contains the banner.
@property (nonatomic, retain) UIView *appstoreContainerView;    //view that contains the appstore.
@property (nonatomic, assign) BOOL campaignsEnabled;            //boolean indicating the campaigns enabling.

@property (nonatomic, retain) MCMCampaignBannerViewController *currentBanner;
@property (nonatomic, retain) NSTimer *durationTimer;                       //campaign duration
@property (nonatomic, retain) MCMCampaignDTO *currentCampaignModel;       //current campaign selected
@property (nonatomic, assign) CampaignType type;            //type of campaign: cross-selling, etc

@property (nonatomic, assign) BOOL deletedView;

@property (nonatomic, copy) CompletionBlock completionBlock;
@property (nonatomic, copy) ErrorBlock errorBlock;

@end

@implementation MCMCampaignsManager SYNTHESIZE_SINGLETON_FOR_CLASS(MCMCampaignsManager)

@synthesize campaignContainerView = _campaignContainerView;
@synthesize appstoreContainerView = _appstoreContainerView;
@synthesize campaignsEnabled = _campaignsEnabled;
@synthesize delegate = _delegate;


#pragma mark - public methods

- (void)addBannerType:(CampaignType)type inView:(UIView*)view {
    [self addBannerType:type inView:view withAppstoreView:nil];
}

- (void)addBannerType:(CampaignType)type inView:(UIView *)view withAppstoreView:(UIView *)appstoreView{
    
    [self hideCampaignView];
    
    self.type = type;
    
    if(self.durationTimer && [self.durationTimer isValid]){
        [self.durationTimer invalidate];
        self.durationTimer = nil;
    }

    //time by default
    self.duration = DEFAULT_DURATION;

    //specifies the container view for the banner
    _campaignContainerView = view;
    
    //specifies the container view for the appstore
    _appstoreContainerView = appstoreView;
    
    //There is no completionBlock
    self.completionBlock = nil;
    self.errorBlock = nil;
    
    //request a campaign to the server. this has to be called everytime it's needed to show it.
    [self requestCampaign];
    
    _campaignsEnabled = YES;
}

- (void)removeCurrentBanner{
    
    //removes the current one
    if(self.currentBanner){
        [self hideCampaignView];
    }

    _campaignsEnabled = NO;
    self.currentBanner = nil;

}

- (void)requestBannersType:(CampaignType)type completion:(void (^)(NSArray * campaignBannersVC))completion error:(void (^)(NSString *))error{
    
    self.type = type;
    _campaignContainerView = nil;
    self.completionBlock = completion;
    self.errorBlock = error;
    
    //Get the json and parse it to get the banners
    [self requestCampaign];
    
    //filtro el array con las campañas del tipo type
    
    //creo un array de banners
    
    //ejecuto el bloque con el array de banners
    
}

- (void)dealloc{
        
    if(self.durationTimer && [self.durationTimer isValid]){
        [self.durationTimer invalidate];
        self.durationTimer = nil;
    }
    
    [super dealloc];
}


#pragma mark - private methods

/**
 Method that request the banner to the server.
 @since 2.0.0
 */
- (void)requestCampaign{
    
    [[MCMStatsLocatorService sharedInstance] updateLocation:^(CLLocation *location, NSError *error) {
        
        NSString *url = [NSString stringWithFormat:MCMCAMPAIGN_URL, [[MCMCoreManager sharedInstance] valueForKey:kMCMCoreKeyMalcomAppId], [MCMCoreUtils uniqueIdentifier]];
        IF_IOS7_OR_GREATER(
                           url = [NSString stringWithFormat:MCMCAMPAIGN_URL_IOS7, [[MCMCoreManager sharedInstance] valueForKey:kMCMCoreKeyMalcomAppId], [MCMCoreUtils deviceIdentifier]];
                           )
        url = [[MCMCoreManager sharedInstance] malcomUrlForPath:url];
        
        if (location != nil) {
            //Add the location to the request
            url = [NSString stringWithFormat:@"%@?lat=%.6f&lng=%.6f",url,location.coordinate.latitude,location.coordinate.longitude];
        }
        
        MCMLog(@"url: %@", url);
        
        MCMASIHTTPRequest *request = [MCMASIHTTPRequest requestWithURL:[NSURL URLWithString:url]];
        [request setDownloadCache:[MCMASIDownloadCache sharedCache]];
        [request setCachePolicy:ASIAskServerIfModifiedCachePolicy];
        [request setCacheStoragePolicy:ASICacheForSessionDurationCacheStoragePolicy];
        [request setTimeOutSeconds:8];
        [request setDelegate:self];
        [request setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"jsonDownloaded", @"type",nil]];
        [request startAsynchronous];
        
    }];
    
}

/**
 Processes the information from response of campaign's request
 @since 2.0.1
 */
- (void)processCampaignResponse:(NSArray *)items{
    
    NSMutableArray *campaignsArray = [[NSMutableArray alloc] initWithCapacity:1];
    
    //parses all the campaigns
    for(int i=0; i<[items count];i++){
        
        //gets the first element of the dictionary
        NSDictionary *dict = [items objectAtIndex:i];
        
        MCMCampaignDTO *campaignModel = [[MCMCampaignDTO alloc] initWithDictionary:dict];
        [campaignsArray addObject:campaignModel];
        
    }
    
    if ([campaignsArray count] > 0) {
        
        //If there is no completitionBlock the library should show the campaign
        if (self.completionBlock == nil) {
            
            //Get the campaign selected for the current CampaignType
            MCMCampaignDTO *selectedCampaign = [MCMCampaignsHelper selectCampaign:campaignsArray forType:self.type];
            
            //notifies it will be shown
            if (self.delegate && [self.delegate respondsToSelector:@selector(campaignViewWillLoad)]){
                [self.delegate campaignViewWillLoad];
            }
            //shows the campaign
            [self displayCampaign:selectedCampaign];
            
        } else {
            
            //Otherwise, the developer is who should show
            NSArray *selectionCampaignsArray = [MCMCampaignsHelper getCampaignsArray:campaignsArray forType:self.type];
            
            // execute the completion block
            NSArray *bannersArray = [MCMCampaignsHelper createBannersForCampaigns:selectionCampaignsArray inView:nil];
            self.completionBlock(bannersArray);
            
        }
    } else {
        MCMLog(@"There is no campaign to show");
        
        [self notifyErrorLoadingCampaign:@"There is no campaign to show"];
        
        //Calls the error block
        if (self.errorBlock != nil) {
            self.errorBlock(@"There is no campaign to show");
        }
    }
    
}

/**
 Method that shows the selected campaign in the screen.
 @since 2.0.0
 */
- (void)displayCampaign:(MCMCampaignDTO *)campaign{
    
    if (campaign) {
        
        //if previously there is some banner it will be removed in order to be replaced.
        if(self.currentBanner){
            [self hideCampaignView];
        }
        
        //Create the banner
        self.currentBanner = [[MCMCampaignBannerViewController alloc] initInView:_campaignContainerView andCampaign:campaign];
        
        //Configure banner
        [self.currentBanner setDelegate:self];
        if (self.type == IN_APP_CROSS_SELLING){
            //Specifies the appstore container view (only for in_app_cross_selling)
            [self.currentBanner setAppstoreContainerView:_appstoreContainerView];
        }
        
        //Show banner
        UIView *containerView = [self getContainerViewForCurrentBanner];
        MCMLog(@"ContainerView frame: %@",NSStringFromCGRect(containerView.frame));
        MCMLog(@"currentBannerView frame: %@",NSStringFromCGRect(self.currentBanner.view.frame));
        
        [containerView addSubview:self.currentBanner.view];
        
        MCMLog(@"Start display %@",campaign);
        
    } else {
        [self notifyErrorLoadingCampaign:@"There is no campaign to show"];
    }
    
}

- (void)showBanner:(MCMCampaignBannerViewController *)bannerViewController {
    
    //shows the banner
    [bannerViewController showCampaignBannerAnimated];
    
    //clears the timer
    if(self.durationTimer && [self.durationTimer isValid]){
        [self.durationTimer invalidate];
        self.durationTimer = nil;
    }
    
    
    //if duration is not 0 it will create a timer in order to remove and finish the campaign
    if(self.duration != 0){
        self.durationTimer = [NSTimer scheduledTimerWithTimeInterval:self.duration
                                                              target:self
                                                            selector:@selector(finishCampaignView)
                                                            userInfo:nil
                                                             repeats:NO];
    }
    
}


/**
 Method that detects the app did becoming to active and displays another campaign
 @since 2.0.0
 */
- (void)appDidBecomeActiveNotification:(NSNotification *)notification{

    if(_campaignsEnabled){
        [self requestCampaign];
    }
}

/**
 Method that finishes the campaign
 @since 2.0.0
 */
- (void)hideCampaignView{
    
    if(self.currentBanner.view.superview){
        [self.currentBanner.view removeFromSuperview];
    }

    self.currentBanner = nil;
}

- (void)finishCampaignView{
  
    if (self.currentBanner && self.currentBanner.view.window) {
        [self hideCampaignView];
        
        //notifies by the delegate that the campaign has been finished
        if(self.delegate && [self.delegate respondsToSelector:@selector(campaignViewDidFinish)]){
            [self.delegate campaignViewDidFinish];
        }
    }
    
}

- (void)notifyErrorLoadingCampaign:(NSString *)errorMessage{
    
    //Reports the error
    if (self.delegate && [self.delegate respondsToSelector:@selector(campaignViewDidFailRequest)]){
        [self.delegate campaignViewDidFailRequest:errorMessage];
    }
}

- (UIView *)getContainerViewForCurrentBanner{
    
    UIView *containerView;
    
    //depending on the situation it will show it in window or in the container view.
    if([self.currentBanner.currentCampaignDTO showOnWindow] || _campaignContainerView == nil ){ //adds it to the window
        
        UIWindow* window = [UIApplication sharedApplication].keyWindow;
        if (!window)
            window = [[UIApplication sharedApplication].windows objectAtIndex:0];
        
        containerView = [[window subviews] objectAtIndex:0];
        
        containerView = [[[UIApplication sharedApplication] delegate] window];
        
    }else{ //adds to the specified view
        containerView = _campaignContainerView;
        
    }
    
    MCMLog(@"Screen size %@",NSStringFromCGSize([UIScreen mainScreen].bounds.size));
    
    return containerView;
}

#pragma mark ----
#pragma mark ASIHTTPRequest delegate methods
#pragma mark ----

- (void)requestFinished:(MCMASIHTTPRequest *)request {
    MCMLog(@"HTTP CODE: %d", [request responseStatusCode]);
    
    BOOL error = true;

    if ([request responseStatusCode] < 400) {
        
        //parses the response
        if ([[request.userInfo objectForKey:@"type"] isEqualToString:@"jsonDownloaded"]) {
            
            NSData *data = [request responseData];
            NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:kNilOptions
                                                                   error:nil];
            
            //Check if the response contains campaigns
            if ([json objectForKey:@"campaigns"]){
                NSArray *items = [json objectForKey:@"campaigns"];
                
                [self processCampaignResponse:items];
                
                //if everything was ok return
                error = false;
            }
            
        }
        
    }
    
    if (error) {
        //Try to gets the error message
        NSString *errorMessage;
        NSDictionary* json = [NSJSONSerialization JSONObjectWithData:[request responseData]
                                                             options:kNilOptions
                                                               error:nil];
        if (json!=nil && [json objectForKey:@"description"]) {
            errorMessage = (NSString *)[json objectForKey:@"description"];
        } else {
            errorMessage = [NSString stringWithFormat:@"Response code: %d", [request responseStatusCode]];
        }
        
        
        //Notifies delegate fail
        if(self.delegate && [self.delegate respondsToSelector:@selector(campaignViewDidFailRequest)]){
            [self.delegate campaignViewDidFailRequest:errorMessage];
        }
        
        //Calls the error block
        if (self.errorBlock != nil) {
            self.errorBlock(errorMessage);
        }
    }
    
}

- (void)requestFailed:(MCMASIHTTPRequest *)request {
    
    NSError *err = [request error];
    
    MCMLog(@"Error receiving campaing file: %@", [err description]);
    
}



#pragma mark - MCMIntersitialBannerViewControllerDelegate Methods

- (void)mediaFinishLoading:(MCMCampaignDTO *)campaign{
    
    if (self.type == IN_APP_CROSS_SELLING || self.type == IN_APP_PROMOTION) {
        
        [self showBanner:self.currentBanner];
        
    }

    //notifies it is being shown
    if(self.delegate && [self.delegate respondsToSelector:@selector(campaignViewDidLoad)]){
        [self.delegate campaignViewDidLoad];
    }
    
    MCMLog(@"Displaying a campaign...");
    
}

- (void)mediaFailedLoading:(MCMCampaignDTO *)campaign{
    
    NSString* errorMessage = [NSString stringWithFormat:@"Failed displaying campaign: %@",[campaign name]];
    
    //This is to show the message removing the warning
    MCMLog(@"%@",errorMessage);
 
    //notifies delegate fail
    if(self.delegate && [self.delegate respondsToSelector:@selector(campaignViewDidFailRequest:)]){
        [self.delegate campaignViewDidFailRequest:errorMessage];
    }
    
    
}

- (void)mediaClosed{
    
    [self finishCampaignView];
    
}

- (void)bannerPressed:(MCMCampaignDTO *)campaign{
    
    MCMLog(@"Pressed %@",campaign);
    
    //notifies it is being shown
    if(self.delegate && [self.delegate respondsToSelector:@selector(campaignPressed:)]){
        
        [self.delegate campaignPressed:campaign];
    }

}

@end
