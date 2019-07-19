//
//  NCLine.m
//  cocoaNEC
//
//  Created by Kok Chen on 4/5/08.
//	-----------------------------------------------------------------------------
//  Copyright 2008-2016 Kok Chen, W7AY. 
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

#import "NCLine.h"


@implementation NCLine

//  override NCWire to keep the segments immutable
- (void)setSegments:(int)value
{
	segments = value ;
	feedSegment = ( segments+1 )/2 ;					//  v0.81
}

@end