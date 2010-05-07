//
//  TwitterJsonParser.m
//  HelTweetica
//
//  Created by Lucius Kwok on 4/7/10.

/*
 Copyright (c) 2010, Felt Tip Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:  
 1.  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 2.  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 3.  Neither the name of the copyright holder(s) nor the names of any contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "TwitterMessageJSONParser.h"
#import "TwitterMessage.h"
#import "TwitterUser.h"


@implementation TwitterMessageJSONParser
@synthesize messages, users, currentMessage, currentUser, directMessage, receivedTimestamp;

- (id) init {
	if (self = [super init]) {
		messages = [[NSMutableArray alloc] init];
		users = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) dealloc {
	[messages release];
	[users release];
	
	[currentMessage release];
	[currentUser release];
	
	[receivedTimestamp release];
	[super dealloc];
}

- (void) parseJSONData:(NSData*)jsonData {
	LKJSONParser *parser = [[LKJSONParser alloc] initWithData:jsonData];
	parser.delegate = self;
	[parser parse];
	[parser release];
}

#pragma mark Keys

- (void) parserDidBeginDictionary:(LKJSONParser*)parser {
	NSString *key = parser.keyPath;
	if ([key isEqualToString:@"/retweeted_status/"]) {
		if (currentMessage) {
			currentMessage.retweetedMessage = [[[TwitterMessage alloc] init] autorelease];
			currentMessage.retweetedMessage.receivedDate = receivedTimestamp;
		}
	} else if ([key isEqualToString:@"/user/"] || [key isEqualToString:@"/retweeted_status/user/"] || [key isEqualToString:@"/sender/"]) {
		self.currentUser = [[[TwitterUser alloc] init] autorelease];
	} else if ([key isEqualToString:@"/"]) {
		self.currentMessage = [[[TwitterMessage alloc] init] autorelease];
		currentMessage.direct = directMessage;
		currentMessage.receivedDate = receivedTimestamp;
	}
}

- (void) parserDidEndDictionary:(LKJSONParser*)parser {
	NSString *key = parser.keyPath;
	if ([key isEqualToString:@"/"]) {
		if (currentMessage != nil) {
			[messages addObject: currentMessage];
			if (currentUser) {
				// Set the current user's receivedDate to the message.createdAt so that we know which user info is the latest
				currentUser.updatedAt = currentMessage.createdDate;
				// and copy certain fields from the user to the message.
				currentMessage.screenName = currentUser.screenName;
				currentMessage.avatar = currentUser.profileImageURL;
				currentMessage.locked = currentUser.protectedUser;
			}
			self.currentMessage = nil;
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	} else if ([key isEqualToString:@"/retweeted_status"]) {
		if (currentUser) {
			// Set the current user's receivedDate to the message.createdAt so that we know which user info is the latest
			currentUser.updatedAt = currentMessage.retweetedMessage.createdDate;
			// and copy certain fields from the user to the message.
			currentMessage.retweetedMessage.screenName = currentUser.screenName;
			currentMessage.retweetedMessage.avatar = currentUser.profileImageURL;
			currentMessage.retweetedMessage.locked = currentUser.protectedUser;
		}
	} else if ([key isEqualToString:@"/user"] || [key isEqualToString:@"/retweeted_status/user"] || [key isEqualToString:@"/sender"]) {
		if (currentUser != nil) {
			[users addObject: currentUser];
		} else {
			NSLog (@"Error while parsing JSON.");
		}
	}
}

#pragma mark Values

- (void) foundValue:(id)value forKeyPath:(NSString*)keyPath {
	if ([keyPath hasPrefix:@"/user/"] || [keyPath hasPrefix:@"/retweeted_status/user/"] || [keyPath hasPrefix:@"/sender/"]) {
		[self.currentUser setValue:value forTwitterKey:[keyPath lastPathComponent]];
	} else if ([keyPath hasPrefix:@"/retweeted_status/"]) {
		if (self.currentMessage) 
			[self.currentMessage.retweetedMessage setValue:value forTwitterKey:[keyPath lastPathComponent]];
	} else if ([keyPath hasPrefix:@"/"]) {
		[self.currentMessage setValue:value forTwitterKey:[keyPath lastPathComponent]];
	} 
	
}

- (void) parser:(LKJSONParser*)parser foundBoolValue:(BOOL)value {
	[self foundValue: [NSNumber numberWithBool:value] forKeyPath:parser.keyPath];
}

- (void) parser:(LKJSONParser*)parser foundStringValue:(NSString*)value {
	[self foundValue: value forKeyPath:parser.keyPath];
}

- (void) parser:(LKJSONParser*)parser foundNumberValue:(NSString*)value {
	[self foundValue: value forKeyPath:parser.keyPath];
}

@end
