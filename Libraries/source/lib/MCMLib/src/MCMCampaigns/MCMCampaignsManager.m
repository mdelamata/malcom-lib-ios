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
- (void)displayCampaigns:(NSArray *)campaigns;
- (void)placePromotionBanners:(NSArray *)bannersArray inView:(UIView *)containerView;
- (void)placeCrossSellingBanner:(MCMCampaignBannerViewController *)bannerViewController inView:(UIView *)containerView;
- (void)appDidBecomeActiveNotification:(NSNotification *)notification;
- (void)hideCampaignView;
- (void)finishCampaignView;


@property (nonatomic, retain) UIView *campaignContainerView;    //view that contains the banner.
@property (nonatomic, retain) UIView *appstoreContainerView;    //view that contains the appstore.
@property (nonatomic, assign) BOOL campaignsEnabled;            //boolean indicating the campaigns enabling.

@property (nonatomic, retain) NSMutableArray *campaignsArray;
@property (nonatomic, retain) MCMCampaignBannerViewController *currentIntersitial;
@property (nonatomic, retain) NSTimer *durationTimer;                       //campaign duration
@property (nonatomic, retain) MCMCampaignDTO *currentCampaignModel;       //current campaign selected
@property (nonatomic, assign) CampaignType type;            //type of campaign: cross-selling, etc
@property (nonatomic, retain) NSArray *bannersArray;     //

@property (nonatomic, assign) BOOL deletedView;

@property (nonatomic, copy) CompletionBlock completionBlock;
@property (nonatomic, copy) ErrorBlock errorBlock;

@end

@implementation MCMCampaignsManager SYNTHESIZE_SINGLETON_FOR_CLASS(MCMCampaignsManager)

@synthesize campaignContainerView = _campaignContainerView;
@synthesize appstoreContainerView = _appstoreContainerView;
@synthesize campaignsEnabled = _campaignsEnabled;
@synthesize delegate = _delegate;

@synthesize bannersArray = _bannersArray;



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
    if(self.currentIntersitial){
        [self hideCampaignView];
    }

    _campaignsEnabled = NO;
    self.currentIntersitial = nil;

}

- (void)requestBannersType:(CampaignType)type completion:(void (^)(NSArray * campaignBannersVC))completion error:(void (^)(NSString *))error{
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
    
    NSString *url = [NSString stringWithFormat:MCMCAMPAIGN_URL, [[MCMCoreManager sharedInstance] valueForKey:kMCMCoreKeyMalcomAppId], [MCMCoreUtils uniqueIdentifier]];
    url = [[MCMCoreManager sharedInstance] malcomUrlForPath:url];
    
    [MCMLog log:[NSString stringWithFormat:@"Malcom Campaign - MCMCampaignManager url: %@", url]
         inLine:__LINE__ fromMethod:[NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSUTF8StringEncoding]];
    
    MCMASIHTTPRequest *request = [MCMASIHTTPRequest requestWithURL:[NSURL URLWithString:url]];
    [request setDownloadCache:[MCMASIDownloadCache sharedCache]];
    [request setCachePolicy:ASIAskServerIfModifiedCachePolicy];
    [request setCacheStoragePolicy:ASICacheForSessionDurationCacheStoragePolicy];
    [request setTimeOutSeconds:8];
    [request setDelegate:self];
    [request setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"jsonDownloaded", @"type",nil]];
    [request startAsynchronous];
    
}

/**
 Processes the information from response of campaign's request
 @since 2.0.1
 */
- (void)processCampaignResponse:(NSArray *)items{
    
    self.campaignsArray = [[NSMutableArray alloc] initWithCapacity:1];
    
    //parses all the campaigns
    for(int i=0; i<[items count];i++){
        
        //gets the first element of the dictionary
        NSDictionary *dict = [items objectAtIndex:i];
        
        MCMCampaignDTO *campaignModel = [[MCMCampaignDTO alloc] initWithDictionary:dict];
        [self.campaignsArray addObject:campaignModel];
        
    }
    
    //notifies it will be shown
    if(self.delegate && [self.delegate respondsToSelector:@selector(campaignViewWillLoad)]){
        [self.delegate campaignViewWillLoad];
    }
    
    //Get the campaigns for the current CampaignType
    NSArray *selectionCampaignsArray = [MCMCampaignsHelper filterCampaigns:self.campaignsArray forType:self.type];
    
    if (self.completionBlock == nil) {
        //shows a campaign
        [self displayCampaigns:selectionCampaignsArray];
    } else {
        // execute the completion block
        NSArray *bannersArray = [MCMCampaignsHelper createBannersForCampaigns:selectionCampaignsArray inView:nil];
        self.completionBlock(bannersArray);
    }
    
}

/**
 Method that shows the selected campaign in the screen.
 @since 2.0.0
 */
- (void)displayCampaigns:(NSArray *)campaigns{
    

    //if there are parsed campaigns
    if ([self.campaignsArray count] > 0) {
        
        //if previously there is some banner it will be removed in order to be replaced.
        if(self.currentIntersitial){
            [self hideCampaignView];
        }
        
        //Create the banners
        self.bannersArray = [MCMCampaignsHelper createBannersForCampaigns:campaigns inView:_campaignContainerView];
        
        for (MCMCampaignBannerViewController *bannerViewController in self.bannersArray) {
            [bannerViewController setDelegate:self];
            //Specifies the appstore container view (only for in_app_cross_selling)
            if (self.type == IN_APP_CROSS_SELLING)
                [bannerViewController setAppstoreContainerView:_appstoreContainerView];
        }

        [MCMLog log:@"Malcom Campaign - MCMCampaignManager Starting campaign displaying..."
             inLine:__LINE__ fromMethod:[NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSUTF8StringEncoding]];
        
    }
    
}

/**
 
 */
- (void)placePromotionBanners:(NSArray*)bannersArray inView:(UIView *)containerView {
    [MCMLog log:@"Malcom Campaign - MCMCampaignManager placeBanners" 
         inLine:__LINE__ fromMethod:[NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSUTF8StringEncoding]];
    
    int yOffset = 0;
    
    for (int i=0; i<[bannersArray count]; i++) {
        
        [MCMLog log:[NSString stringWithFormat:@"MCMCampaignManager placing banner %d - offset %d",i,yOffset]
             inLine:__LINE__ fromMethod:[NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSUTF8StringEncoding]];
        
        MCMCampaignBannerViewController *currentBanner = [bannersArray objectAtIndex:i];
        
        CGRect frame = currentBanner.view.frame;
        frame.origin.y = yOffset;
        [currentBanner.view setFrame:frame];
        
        yOffset += frame.size.height;
        
        //Remove the view from container
        [currentBanner.view removeFromSuperview];
        //Add current view in proper location
        [containerView addSubview:currentBanner.view];
        
    }
}

- (void)placeCrossSellingBanner:(MCMCampaignBannerViewController *)bannerViewController inView:(UIView *)containerView {
    //adds the banner to the view
    [containerView addSubview:bannerViewController.view];
    
    //shows the banner
    [bannerViewController showCrossCampaignBannerAnimated];
    
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
    
    if(self.currentIntersitial.view.superview){
        [self.currentIntersitial.view removeFromSuperview];
    }

    self.currentIntersitial = nil;
}

- (void)finishCampaignView{
  
    if (self.currentIntersitial && self.currentIntersitial.view.window) {
        [self hideCampaignView];
        
        //notifies by the delegate that the campaign has been finished
        if(self.delegate && [self.delegate respondsToSelector:@selector(campaignViewDidFinish)]){
            [self.delegate campaignViewDidFinish];
        }
    }
    
}

#pragma mark ----
#pragma mark ASIHTTPRequest delegate methods
#pragma mark ----

- (void)requestFinished:(MCMASIHTTPRequest *)request {
    
    [MCMLog log:[NSString stringWithFormat:@"Malcom Campaign - MCMCampaignManager HTTP CODE: %d", [request responseStatusCode]]
         inLine:__LINE__ fromMethod:[NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSUTF8StringEncoding]];

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
                return;
            }
            
        }
        
    }
        
    //if something was wrong notifies delegate fail
    if(self.delegate && [self.delegate respondsToSelector:@selector(campaignViewDidFailRequest)]){
        [self.delegate campaignViewDidFailRequest];
    }
    
    if (self.errorBlock != nil) {
        NSString *errorMessage;
        NSDictionary* json = [NSJSONSerialization JSONObjectWithData:[request responseData]
                                                                options:kNilOptions
                                                                  error:nil];
        if (json!=nil && [json objectForKey:@"description"]) {
            errorMessage = (NSString *)[json objectForKey:@"description"];
        } else {
            errorMessage = @"";
        }
        self.errorBlock(errorMessage);
    }
    
}

- (void)requestFailed:(MCMASIHTTPRequest *)request {
    
    NSError *err = [request error];
    
    [MCMLog log:[NSString stringWithFormat:@"Malcom Campaign - MCMCampaignManager Error receiving campaing file: %@", [err description]]
         inLine:__LINE__ fromMethod:[NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSUTF8StringEncoding]];
    
    
}



#pragma mark - MCMIntersitialBannerViewControllerDelegate Methods

- (void)mediaFinishLoading:(MCMCampaignDTO *)campaign{
    
    UIView *containerView;
    
    //depending on the situation it will show it in window or in the container view.
    if([self.currentIntersitial needsToDisplayOnWindow] || _campaignContainerView == nil ){ //adds it to the window
        
        UIWindow* window = [UIApplication sharedApplication].keyWindow;
        if (!window)
            window = [[UIApplication sharedApplication].windows objectAtIndex:0];
        
        containerView = [[window subviews] objectAtIndex:0];
        
        //        containerView = [[[UIApplication sharedApplication] delegate] window];
        
    }else{ //adds to the specified view
        containerView = _campaignContainerView;
        
    }
    
    if (self.type == IN_APP_CROSS_SELLING) {
        
        [self placeCrossSellingBanner:[self.bannersArray objectAtIndex:0] inView:containerView];
        
    } else if (self.type == IN_APP_PROMOTION) {
        
        [self placePromotionBanners:self.bannersArray inView:containerView];
    }

    //notifies it is being shown
    if(self.delegate && [self.delegate respondsToSelector:@selector(campaignViewDidLoad)]){
        [self.delegate campaignViewDidLoad];
    }
    
    [MCMLog log:@"Malcom Campaign - MCMCampaignManager Displaying a campaign..."
         inLine:__LINE__ fromMethod:[NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSUTF8StringEncoding]];
    
}

- (void)mediaFailedLoading{
 
    //notifies delegate fail
    if(self.delegate && [self.delegate respondsToSelector:@selector(campaignViewDidFailRequest)]){
        [self.delegate campaignViewDidFailRequest];
    }
    
    [MCMLog log:@"Malcom Campaign - MCMCampaignManager Failed campaign displaying..."
         inLine:__LINE__ fromMethod:[NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSUTF8StringEncoding]];
    
    
}

- (void)mediaClosed{
    
    [self finishCampaignView];
    
}

- (void)bannerPressed:(MCMCampaignDTO *)campaign{
    
    [MCMLog log:[NSString stringWithFormat:@"Malcom Campaign - MCMCampaignManager Pressed %@",campaign]
         inLine:__LINE__ fromMethod:[NSString stringWithCString:__PRETTY_FUNCTION__ encoding:NSUTF8StringEncoding]];
    
    //notifies it is being shown
    if(self.delegate && [self.delegate respondsToSelector:@selector(campaignPressed:)]){
        
        [self.delegate campaignPressed:campaign.promotionIdentifier];
    }

}

@end
