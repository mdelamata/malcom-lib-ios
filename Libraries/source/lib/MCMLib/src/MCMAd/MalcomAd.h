//
//  MalcomAd.h
//  MalcomLib
//
//  Created by Alfonso Miranda Castro on 06/06/12.
//  Copyright (c) 2012 Malcom. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIViewController.h>

@interface MalcomAd : NSObject

//  ADS

/**
 Show ads at viewController
 @param vc viewController where ads is showing
 @param position position where ads is showing
 @param size size of ads view
 @since 2.0.0
 */
+ (void)presentAd:(UIViewController *)vc atPosition:(CGPoint)position withSize:(CGSize)size DEPRECATED_ATTRIBUTE;

/**
 Show ads at viewController
 @param vc viewController where ads is showing
 @param position position where ads is showing
 @since 2.0.0
 */
+ (void)presentAd:(UIViewController *)vc atPosition:(CGPoint)position DEPRECATED_ATTRIBUTE;

/**
 Relocate ads position
 @param position New position of ad
 @since 2.0.0
 */
+ (void)relocateAd:(CGPoint)position DEPRECATED_ATTRIBUTE;

/**
 Remove ads
 @param viewController where is ad
 @since 2.0.0
 */
+ (void)removeAd:(UIViewController *)viewController DEPRECATED_ATTRIBUTE;

/**
 Return ads banner
 @return ads banner
 @since 2.0.2
 */
+ (id)getAd DEPRECATED_ATTRIBUTE;

@end
