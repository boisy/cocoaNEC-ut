//
//  Pattern3dContainer.m
//  cocoaNEC
//
//  Created by Kok Chen on 6/21/11.
//	-----------------------------------------------------------------------------
//  Copyright 2011-2016 Kok Chen, W7AY. 
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

#import "Pattern3dContainer.h"
#import "NECOutput.h"
#import "Pattern3dView.h"

@implementation Pattern3dContainer

- (Boolean)setUpWithPrintInfo:(NSPrintInfo*)printInfo output:(NECOutput*)output
{
	Pattern3dView *base ;
	float viewOffset, auxHeight ;
	
	if ( view == nil || auxView == nil || footer == nil ) return NO ;
	
	base = [ output pattern3dView ] ;
	[ view setAngle:[ base angle ] ] ;
	[ view setContrast:[ base contrast ] ] ;
	[ view setGainScale:[ base gainScale ] ] ;
	[ view setPlotType:[ base plotType ] ] ;
	[ view setPattern:[ base pattern ] ] ; 
	
	if ( [ output drawFilenames ] ) {
		viewOffset = FILENAMEOFFSET ;
		[ self setOutput:output ] ;		//  to get printFooter callback from view's drawRect
	}
	else {
		viewOffset = 2 ;
		[ self setOutput:nil ] ;
	}
	auxHeight = 25 ;
	[ self setFrame:NSMakeRect( 0, 0, 600., 600.+( auxHeight+1 )+viewOffset ) ] ;
	[ view setFrame:NSMakeRect( 0, ( auxHeight+1 )+viewOffset, 600., 600. ) ] ;
	[ auxView setFrame:NSMakeRect( 0, viewOffset, 600., auxHeight ) ] ;
	[ footer setFrame:NSMakeRect( 0, 0, 600., viewOffset ) ] ;
	
	[ printInfo setHorizontalPagination:NSFitPagination ] ;
	[ printInfo setVerticalPagination:NSClipPagination ] ;
	return YES ;
}

- (Pattern3dView*)view
{
	return view ;
}

@end
