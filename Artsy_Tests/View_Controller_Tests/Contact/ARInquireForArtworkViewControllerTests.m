#import "ARInquireForArtworkViewController.h"
#import "ARUserManager+Stubs.h"


@interface ARInquireForArtworkViewController (Testing)

@property (nonatomic, strong) User *user;

@property (nonatomic, strong, readonly) UITextField *emailInput;
@property (nonatomic, strong, readonly) UITextField *nameInput;

@property (nonatomic, strong, readonly) UILabel *messageTitleLabel;
@property (nonatomic, strong, readonly) UILabel *messageBodyLabel;
@property (nonatomic, strong, readonly) UILabel *userSignature;

@property (nonatomic, strong, readonly) UIButton *failureDismissButton;
@property (nonatomic, strong, readonly) UIButton *failureTryAgainButton;
@property (nonatomic, strong, readonly) ARModalMenuButton *sendButton;

- (void)sendButtonTapped:(UIButton *)sender;
- (void)cancelButtonTapped:(UIButton *)sender;
- (void)emailInputHasChanged:(id)sender;
- (void)removeFromHostViewController;
- (void)sendInquiry;
@end

SpecBegin(ARInquireForArtworkViewController);

__block Artwork *galleryArtwork, *museumGallery;

beforeEach(^{
    galleryArtwork = [Artwork modelWithJSON:@{
        @"id" : @"cory-arcangel-photoshop-cs",
        @"title" : @"Photoshop CS",
        @"artist" : @{
               @"id": @"cory-arcangel",
               @"name": @"Cory Arcangel"
        },
        @"partner" : @{
               @"id" : @"partner_id",
               @"type" : @"Gallery",
               @"name" : @"Lisson Gallery"
        }
    }];
    
    museumGallery = [Artwork modelWithJSON:@{
        @"id" : @"cory-arcangel-photoshop-cs",
        @"title" : @"Photoshop CS",
        @"artist" : @{
             @"id": @"cory-arcangel",
             @"name": @"Cory Arcangel"
        },
        @"partner" : @{
             @"id" : @"partner_id",
             @"type" : @"Museum",
             @"name" : @"Guggenheim Museum"
        }
    }];

    [OHHTTPStubs stubJSONResponseAtPath:@"/api/v1/admins/available_representatives" withResponse:@[]];
});

afterEach(^{
    [OHHTTPStubs removeAllStubs];
});

describe(@"logged in", ^{
    beforeEach(^{
        [ARUserManager stubAndLoginWithUsername];
    });

    afterEach(^{
        [ARUserManager clearUserData];
    });

    itHasAsyncronousSnapshotsForDevicesWithName(@"displays Contact Gallery when seller is a gallery", ^{
        ARInquireForArtworkViewController *vc = [[ARInquireForArtworkViewController alloc] initWithPartnerInquiryForArtwork:galleryArtwork fair:nil];
        [vc ar_presentWithFrame:[[UIScreen mainScreen] bounds]];
        return vc;
    });

    itHasAsyncronousSnapshotsForDevicesWithName(@"displays Contact Seller when seller is not a gallery", ^{
        ARInquireForArtworkViewController *vc = [[ARInquireForArtworkViewController alloc] initWithPartnerInquiryForArtwork:museumGallery fair:nil];
        [vc ar_presentWithFrame:[[UIScreen mainScreen] bounds]];
        return vc;
    });

    itHasAsyncronousSnapshotsForDevicesWithName(@"logged out, displays artsy specialist", ^{
        ARInquireForArtworkViewController *vc = [[ARInquireForArtworkViewController alloc] initWithAdminInquiryForArtwork:museumGallery fair:nil];
        [vc ar_presentWithFrame:[[UIScreen mainScreen] bounds]];
        return vc;
    });
});

describe(@"as an admin", ^{
    it(@"shows a warning in the user signature about failing", ^{
        ARInquireForArtworkViewController *vc = [[ARInquireForArtworkViewController alloc] initWithPartnerInquiryForArtwork:museumGallery fair:nil];
        vc.user = [User modelWithJSON:@{ @"email" : @"orta@artsymail.net" }];
        [vc ar_presentWithFrame:[[UIScreen mainScreen] bounds]];
        expect(vc.userSignature.text).to.contain(@"will fail");
    });
});

describe(@"sending", ^{
    __block ARInquireForArtworkViewController *vc;
    __block id userMock;

    beforeEach(^{
        [ARUserManager clearUserData];
        [ARUserManager sharedManager].localTemporaryUserName = @"Trial User";
        [ARUserManager sharedManager].localTemporaryUserEmail = @"trial@example.com";
        userMock = [OCMockObject mockForClass:[User class]];
        [[[[userMock stub] classMethod] andReturnValue:OCMOCK_VALUE(YES)] isLocalTemporaryUser];

        vc = [[ARInquireForArtworkViewController alloc] initWithPartnerInquiryForArtwork:galleryArtwork fair:nil];
        [vc ar_presentWithFrame:[[UIScreen mainScreen] bounds]];
    });
    
    afterEach(^{
        [userMock stopMocking];
        [ARUserManager sharedManager].localTemporaryUserName = nil;
        [ARUserManager sharedManager].localTemporaryUserEmail = nil;
    });

    it(@"displays sending message", ^{
        [OHHTTPStubs stubJSONResponseAtPath:@"/api/v1/me/artwork_inquiry_request" withResponse:@{}];
        id partialVC = [OCMockObject partialMockForObject:vc];
        [[partialVC stub] sendInquiry];
        [vc sendButtonTapped:vc.sendButton];

        expect(vc.messageTitleLabel.hidden).to.beFalsy();
        expect(vc.messageTitleLabel.text).to.equal(@"SENDING…");
        expect(vc.messageBodyLabel.hidden).to.beFalsy();
        expect(vc.messageBodyLabel.text).to.equal(@"");
        expect(vc.failureTryAgainButton.hidden).to.beTruthy();
        expect(vc.failureDismissButton.hidden).to.beTruthy();

        [partialVC stopMocking];
    });


    it(@"displays success message", ^{
        [OHHTTPStubs stubJSONResponseAtPath:@"/api/v1/me/artwork_inquiry_request" withResponse:@{}];
        [vc sendButtonTapped:vc.sendButton];
        expect(vc.messageTitleLabel.hidden).to.beFalsy();
        expect(vc.messageTitleLabel.text).to.equal(@"THANK YOU");
        expect(vc.messageBodyLabel.hidden).to.beFalsy();
        expect(vc.messageBodyLabel.text).to.equal(@"Your message has been sent");
        expect(vc.failureTryAgainButton.hidden).to.beTruthy();
        expect(vc.failureDismissButton.hidden).to.beTruthy();
    });

    describe(@"general failure", ^{
        before(^{
            [OHHTTPStubs stubJSONResponseAtPath:@"/api/v1/me/artwork_inquiry_request" withResponse:@{} andStatusCode:400];
            [vc ar_presentWithFrame:CGRectMake(0, 0, 360, 720)];
            [vc sendButtonTapped:vc.sendButton];
        });

        it(@"displays failure message", ^{
            expect(vc.messageTitleLabel.hidden).to.beFalsy();
            expect(vc.messageTitleLabel.text).to.equal(@"ERROR SENDING MESSAGE");
            expect(vc.messageBodyLabel.hidden).to.beFalsy();
            expect(vc.messageBodyLabel.text).to.equal(@"Please try again or email\nsupport@artsy.net if the issue persists");
            expect(vc.failureTryAgainButton.hidden).to.beFalsy();
            expect(vc.failureDismissButton.hidden).to.beFalsy();
        });

        it(@"can be dismissed", ^{
            id vcMock = [OCMockObject partialMockForObject:vc];
            [[vcMock expect] removeFromHostViewController];
            [[vcMock reject] sendInquiry];
            [vc cancelButtonTapped:vc.failureDismissButton];
            [vcMock verify];
            [vcMock stopMocking];
        });

        it(@"can resend request", ^{
            id vcMock = [OCMockObject partialMockForObject:vc];
            [[vcMock reject] removeFromHostViewController];
            [[vcMock expect] sendInquiry];
            [vc sendButtonTapped:vc.failureTryAgainButton];
            [vcMock verify];
            [vcMock stopMocking];
        });
    });
});

SpecEnd;
