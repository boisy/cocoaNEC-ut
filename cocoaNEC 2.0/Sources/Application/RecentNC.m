//
//  RecentNC.m
//  cocoaNEC
//
//  Created by Kok Chen on 9/15/07.
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

#import "RecentNC.h"

#import "ApplicationDelegate.h"
#import "plist.h"

@implementation RecentNC

- (id)init
{
	self = [ super init ] ;
	if ( self ) {
		plistKey = kRecentNC ;
	}
	return self ;
}

- (void)performOpen:(NSString*)path
{
	[ [ NSApp delegate ] openNCModelAtPath:path ] ;
}

@end
