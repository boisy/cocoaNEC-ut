//
//  ControlCard.h
//  cocoaNEC
//
//  Created by Kok Chen on 8/15/07.
//	-----------------------------------------------------------------------------
//  Copyright 2007-2016 Kok Chen, W7AY. 
//
//	Licensed under the Apache License, Version 2.0 (the "License");
//	you may not use this file except in compliance with the License.
//	You may obtain a copy of the License at
//
//		http://www.apache.org/licenses/LICENSE-2.0
//
//	Unless required by applicable law or agreed to in writing, software
//	distributed under the License is distributed on an "AS IS" BASIS,
//	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//	See the License for the specific language governing permissions and
//	limitations under the License.
//	-----------------------------------------------------------------------------

#import <Cocoa/Cocoa.h>
#import "Config.h"


@interface ControlCard : NSObject {
    NSString *hollerith, *comment ;
    Boolean ignore ;
}

- (NSString*)hollerith ;
- (void)setHollerith:(NSString*)name ;
- (NSString*)ignoreField ;
- (void)setIgnore:(NSString*)name ;
- (NSString*)comment ;
- (void)setComment:(NSString*)name ;

- (Boolean)ignoreCard ;

- (NSDictionary*)dictForCard ;
- (void)setCardFromDict:(NSDictionary*)dict ;


@end