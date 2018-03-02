//
//  RMIntroViewController.m
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 19/01/14.
//
//

#import "RMGeometry.h"

#import "RMIntroViewController.h"
#import "RMIntroPageView.h"

#include "animations.h"
#include "objects.h"
#include "texture_helper.h"

#import <SSignalKit/SSignalKit.h>

#import <LegacyComponents/LegacyComponents.h>

#define TGLog NSLog
#define TGLocalized(x) NSLocalizedString(x, @"")

static void TGDispatchOnMainThread(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@interface UIScrollView (CurrentPage)
- (int)currentPage;
- (void)setPage:(NSInteger)page;
- (int)currentPageMin;
- (int)currentPageMax;

@end

@implementation UIScrollView (CurrentPage)

- (int)currentPage
{
    CGFloat pageWidth = self.frame.size.width;
    return (int)floor((self.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
}

- (int)currentPageMin
{
    CGFloat pageWidth = self.frame.size.width;
    return (int)floor((self.contentOffset.x - pageWidth / 2 - pageWidth / 2) / pageWidth) + 1;
}

- (int)currentPageMax
{
    CGFloat pageWidth = self.frame.size.width;
    return (int)floor((self.contentOffset.x - pageWidth / 2 + pageWidth / 2 ) / pageWidth) + 1;
}

- (void)setPage:(NSInteger)page
{
    self.contentOffset = CGPointMake(self.frame.size.width*page, 0);
}
@end


@interface RMIntroViewController () <UIGestureRecognizerDelegate>
{
    id _didEnterBackgroundObserver;
    id _willEnterBackgroundObserver;
    
    UIImageView *_stillLogoView;
    bool _displayedStillLogo;
    
    UIColor *_backgroundColor;
    UIColor *_primaryColor;
    UIColor *_accentColor;
    UIColor *_regularDotColor;
    UIColor *_highlightedDotColor;
    
    UIButton *_startButton;
    TGModernButton *_alternativeLanguageButton;
    
    SMetaDisposable *_localizationsDisposable;
    NSDictionary *_alternativeLocalizationInfo;
    
    SVariable *_alternativeLocalization;
}
@end


@implementation RMIntroViewController

- (instancetype)initWithBackroundColor:(UIColor *)backgroundColor primaryColor:(UIColor *)primaryColor accentColor:(UIColor *)accentColor regularDotColor:(UIColor *)regularDotColor highlightedDotColor:(UIColor *)highlightedDotColor
{
    self = [super init];
    if (self != nil)
    {
        _backgroundColor = backgroundColor;
        _primaryColor = primaryColor;
        _accentColor = accentColor;
        _regularDotColor = regularDotColor;
        _highlightedDotColor = highlightedDotColor;
        
        self.automaticallyAdjustsScrollViewInsets = false;
        
        _headlines = @[ TGLocalized(@"Tour.Title1"), TGLocalized(@"Tour.Title2"),  TGLocalized(@"Tour.Title6"), TGLocalized(@"Tour.Title3"), TGLocalized(@"Tour.Title4"), TGLocalized(@"Tour.Title5")];
        _descriptions = @[TGLocalized(@"Tour.Text1"), TGLocalized(@"Tour.Text2"),  TGLocalized(@"Tour.Text6"), TGLocalized(@"Tour.Text3"), TGLocalized(@"Tour.Text4"), TGLocalized(@"Tour.Text5")];
        
        __weak RMIntroViewController *weakSelf = self;
        _didEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *notification)
        {
            __strong RMIntroViewController *strongSelf = weakSelf;
            [strongSelf stopTimer];
        }];
        
        _willEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *notification)
        {
            __strong RMIntroViewController *strongSelf = weakSelf;
            [strongSelf loadGL];
            [strongSelf startTimer];
        }];
        
        _alternativeLanguageButton = [[TGModernButton alloc] init];
        _alternativeLanguageButton.modernHighlight = true;
        [_alternativeLanguageButton setTitleColor:accentColor];
        
        _alternativeLanguageButton.titleLabel.font = [UIFont systemFontOfSize:18.0];
        _alternativeLanguageButton.hidden = true;
        [_alternativeLanguageButton addTarget:self action:@selector(alternativeLanguageButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _alternativeLocalization = [[SVariable alloc] init];
        
        /*SSignal *localizationSignal = [TGLocalizationSignals suggestedLocalization];
        
        _localizationsDisposable = [[localizationSignal deliverOn:[SQueue mainQueue]] startWithNext:^(TGSuggestedLocalization *next) {
            __strong RMIntroViewController *strongSelf = weakSelf;
            if (strongSelf != nil && next != nil) {
                if (strongSelf->_alternativeLocalizationInfo == nil) {
                    _alternativeLocalizationInfo = next;
                    
                    [strongSelf->_alternativeLanguageButton setTitle:next.continueWithLanguageString forState:UIControlStateNormal];
                    strongSelf->_alternativeLanguageButton.hidden = false;
                    [strongSelf->_alternativeLanguageButton sizeToFit];
                    
                    if ([strongSelf isViewLoaded]) {
                        [strongSelf->_alternativeLanguageButton.layer animateAlphaFrom:0.0f to:1.0f duration:0.3f timingFunction:kCAMediaTimingFunctionEaseInEaseOut removeOnCompletion:true completion:nil];
                        [UIView animateWithDuration:0.3 animations:^{
                            [strongSelf viewWillLayoutSubviews];
                        }];
                    }
                }
            }
        }];*/
    }
    return self;
}

- (void)startTimer
{
    if (_updateAndRenderTimer == nil)
    {
        _updateAndRenderTimer = [NSTimer timerWithTimeInterval:1.0f / 60.0f target:self selector:@selector(updateAndRender) userInfo:nil repeats:true];
        [[NSRunLoop mainRunLoop] addTimer:_updateAndRenderTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)stopTimer
{
    if (_updateAndRenderTimer != nil)
    {
        [_updateAndRenderTimer invalidate];
        _updateAndRenderTimer = nil;
    }
}


- (void)loadView
{
    [super loadView];
}

- (void)loadGL
{
    if (/*[[UIApplication sharedApplication] applicationState] != UIApplicationStateBackground*/true && !_isOpenGLLoaded)
    {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!context)
            NSLog(@"Failed to create ES context");
        
        bool isIpad = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad);
        
        CGFloat size = 200;
        if (isIpad)
            size *= 1.2;
        
        int height = 50;
        if (isIpad)
            height += 138 / 2;
        
        _glkView = [[GLKView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width / 2 - size / 2, height, size, size) context:context];
        _glkView.backgroundColor = _backgroundColor;
        _glkView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _glkView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
        _glkView.drawableMultisample = GLKViewDrawableMultisample4X;
        _glkView.enableSetNeedsDisplay = false;
        _glkView.userInteractionEnabled = false;
        _glkView.delegate = self;
        
        int patchHalfWidth = 1;
        UIView *v1 = [[UIView alloc] initWithFrame:CGRectMake(-patchHalfWidth, -patchHalfWidth, _glkView.frame.size.width + patchHalfWidth * 2, patchHalfWidth * 2)];
        UIView *v2 = [[UIView alloc] initWithFrame:CGRectMake(-patchHalfWidth, -patchHalfWidth, patchHalfWidth * 2, _glkView.frame.size.height + patchHalfWidth * 2)];
        UIView *v3 = [[UIView alloc] initWithFrame:CGRectMake(-patchHalfWidth, -patchHalfWidth + _glkView.frame.size.height, _glkView.frame.size.width + patchHalfWidth * 2, patchHalfWidth * 2)];
        UIView *v4 = [[UIView alloc] initWithFrame:CGRectMake(-patchHalfWidth + _glkView.frame.size.width, -patchHalfWidth, patchHalfWidth * 2, _glkView.frame.size.height + patchHalfWidth * 2)];
        
        v1.backgroundColor = v2.backgroundColor = v3.backgroundColor = v4.backgroundColor = _backgroundColor;
        
        [_glkView addSubview:v1];
        [_glkView addSubview:v2];
        [_glkView addSubview:v3];
        [_glkView addSubview:v4];
        
        [self setupGL];
        [self.view addSubview:_glkView];
        
        [self startTimer];
        _isOpenGLLoaded = true;
    }
}

- (void)freeGL
{
    if (!_isOpenGLLoaded)
        return;

    [self stopTimer];
    
    if ([EAGLContext currentContext] == _glkView.context)
        [EAGLContext setCurrentContext:nil];

    _glkView.context = nil;
    context = nil;
    [_glkView removeFromSuperview];
    _glkView = nil;
    _isOpenGLLoaded = false;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = _backgroundColor;
    
    [self loadGL];
    
    bool isIpad = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad);
    
    _pageScrollView = [[UIScrollView alloc]initWithFrame:self.view.bounds];
    _pageScrollView.clipsToBounds = true;
    _pageScrollView.opaque = true;
    _pageScrollView.clearsContextBeforeDrawing = false;
    [_pageScrollView setShowsHorizontalScrollIndicator:false];
    [_pageScrollView setShowsVerticalScrollIndicator:false];
    _pageScrollView.pagingEnabled = true;
    _pageScrollView.contentSize = CGSizeMake(_headlines.count * self.view.bounds.size.width, self.view.bounds.size.height);
    _pageScrollView.delegate = self;
    [self.view addSubview:_pageScrollView];
    
    _pageViews = [NSMutableArray array];
    
    for (NSUInteger i = 0; i < _headlines.count; i++)
    {
        RMIntroPageView *p = [[RMIntroPageView alloc]initWithFrame:CGRectMake(i * self.view.bounds.size.width, 0, self.view.bounds.size.width, 0) headline:[_headlines objectAtIndex:i] description:[_descriptions objectAtIndex:i] color:_primaryColor];
        p.opaque = true;
        p.clearsContextBeforeDrawing = false;
        [_pageViews addObject:p];
        [_pageScrollView addSubview:p];
    }
    [_pageScrollView setPage:0];
    
    _startButton = [[UIButton alloc] init];
    _startButton.adjustsImageWhenDisabled = false;
    [_startButton setTitle:TGLocalized(@"Tour.StartButton") forState:UIControlStateNormal];
    [_startButton.titleLabel setFont:TGMediumSystemFontOfSize(20.0f)];
    [_startButton setTitleColor:_backgroundColor forState:UIControlStateNormal];
    static UIImage *buttonBackgroundImage = nil;
    static UIImage *buttonHighlightedBackgroundImage = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(48.0, 48.0), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, [_accentColor CGColor]);
            CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 48.0f, 48.0f));
            buttonBackgroundImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:24 topCapHeight:24];
            UIGraphicsEndImageContext();
        }
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(48.0, 48.0), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGFloat hue = 0.0f;
            CGFloat sat = 0.0f;
            CGFloat bri = 0.0f;
            [_accentColor getHue:&hue saturation:&sat brightness:&bri alpha:nil];
            UIColor *color = [[UIColor alloc] initWithHue:hue saturation:sat brightness:bri * 0.7 alpha:1.0];
            CGContextSetFillColorWithColor(context, [color CGColor]);
            CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 48.0f, 48.0f));
            buttonHighlightedBackgroundImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:24 topCapHeight:24];
            UIGraphicsEndImageContext();
        }
    });
    [_startButton setContentEdgeInsets:UIEdgeInsetsMake(0.0f, 20.0f, 0.0f, 20.0f)];
    [_startButton setBackgroundImage:buttonBackgroundImage forState:UIControlStateNormal];
    [_startButton setBackgroundImage:buttonHighlightedBackgroundImage forState:UIControlStateHighlighted];
    [self.view addSubview:_startButton];
    
    _pageControl = [[UIPageControl alloc] init];
    _pageControl.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
    _pageControl.userInteractionEnabled = false;
    [_pageControl setNumberOfPages:6];
    _pageControl.pageIndicatorTintColor = _regularDotColor;
    _pageControl.currentPageIndicatorTintColor = _highlightedDotColor;
    [self.view addSubview:_pageControl];
}

- (BOOL)shouldAutorotate
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        return true;
    
    return false;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        return UIInterfaceOrientationMaskAll;
    
    return UIInterfaceOrientationMaskPortrait;
}

- (DeviceScreen)deviceScreen
{
    CGSize viewSize = self.view.frame.size;
    int max = (int)MAX(viewSize.width, viewSize.height);
    
    DeviceScreen deviceScreen = Inch55;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        switch (max)
        {
            case 1366:
                deviceScreen = iPadPro;
                break;
                
            default:
                deviceScreen = iPad;
                break;
        }
    }
    else
    {
        switch (max)
        {
            case 480:
                deviceScreen = Inch35;
                break;
            case 568:
                deviceScreen = Inch4;
                break;
            case 667:
                deviceScreen = Inch47;
                break;
            default:
                deviceScreen = Inch55;
                break;
        }
    }
    
    return deviceScreen;
}

- (void)viewWillLayoutSubviews
{
    UIInterfaceOrientation isVertical = (self.view.bounds.size.height / self.view.bounds.size.width > 1.0f);
    
    CGFloat statusBarHeight = 0;
    
    CGFloat pageControlY = 0;
    CGFloat glViewY = 0;
    CGFloat startButtonY = 0;
    CGFloat pageY = 0;
    
    CGFloat languageButtonSpread = 60.0f;
    CGFloat languageButtonOffset = 26.0f;
    
    DeviceScreen deviceScreen = [self deviceScreen];
    switch (deviceScreen)
    {
        case iPad:
            glViewY = isVertical ? 121 + 90 : 121;
            startButtonY = 120;
            pageY = isVertical ? 485 : 335;
            pageControlY = pageY + 200.0f;
            break;
            
        case iPadPro:
            glViewY = isVertical ? 221 + 110 : 221;
            startButtonY = 120;
            pageY = isVertical ? 605 : 435;
            pageControlY = pageY + 200.0f;
            break;
            
        case Inch35:
            pageControlY = 162 / 2;
            glViewY = 62 - 20;
            startButtonY = 75;
            pageY = 215;
            pageControlY = pageY + 160.0f;
            if (!_alternativeLanguageButton.isHidden) {
                glViewY -= 40.0f;
                pageY -= 40.0f;
                pageControlY -= 40.0f;
                startButtonY -= 30.0f;
            }
            languageButtonSpread = 65.0f;
            languageButtonOffset = 15.0f;
            break;
            
        case Inch4:
            glViewY = 62;
            startButtonY = 75;
            pageY = 245;
            pageControlY = pageY + 160.0f;
            languageButtonSpread = 50.0f;
            languageButtonOffset = 20.0f;
            break;
            
        case Inch47:
            pageControlY = 162 / 2 + 10;
            glViewY = 62 + 25;
            startButtonY = 75 + 5;
            pageY = 245 + 50;
            pageControlY = pageY + 160.0f;
            break;
            
        case Inch55:
            glViewY = 62 + 45;
            startButtonY = 75 + 20;
            pageY = 245 + 85;
            pageControlY = pageY + 160.0f;
            break;
            
        default:
            break;
    }
    
    if (!_alternativeLanguageButton.isHidden) {
        startButtonY += languageButtonSpread;
    }
    
    _pageControl.frame = CGRectMake(0, pageControlY, self.view.bounds.size.width, 7);
    _glkView.frame = CGRectChangedOriginY(_glkView.frame, glViewY - statusBarHeight);
    
    [_startButton sizeToFit];
    _startButton.frame = CGRectMake(floor((self.view.bounds.size.width - _startButton.frame.size.width) / 2.0f), self.view.bounds.size.height - startButtonY - statusBarHeight, _startButton.frame.size.width, 48.0f);
    [_startButton addTarget:self action:@selector(startButtonPress) forControlEvents:UIControlEventTouchUpInside];
    
    _alternativeLanguageButton.frame = CGRectMake(floor((self.view.bounds.size.width - _alternativeLanguageButton.frame.size.width) / 2.0f), CGRectGetMaxY(_startButton.frame) + languageButtonOffset, _alternativeLanguageButton.frame.size.width, _alternativeLanguageButton.frame.size.height);
    
    _pageScrollView.frame=CGRectMake(0, 20, self.view.bounds.size.width, self.view.bounds.size.height - 20);
    _pageScrollView.contentSize=CGSizeMake(_headlines.count * self.view.bounds.size.width, 150);
    _pageScrollView.contentOffset = CGPointMake(_currentPage * self.view.bounds.size.width, 0);
    
    [_pageViews enumerateObjectsUsingBlock:^(UIView *pageView, NSUInteger index, __unused BOOL *stop)
     {
         pageView.frame = CGRectMake(index * self.view.bounds.size.width, (pageY - statusBarHeight), self.view.bounds.size.width, 150);
     }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self loadGL];
    
    if (_stillLogoView == nil && !_displayedStillLogo)
    {
        _displayedStillLogo = true;
        
        _stillLogoView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"telegram_logo_still.png"]];
        _stillLogoView.contentMode = UIViewContentModeCenter;
        _stillLogoView.bounds = CGRectMake(0, 0, 200, 200);
        
        UIInterfaceOrientation isVertical = (self.view.bounds.size.height / self.view.bounds.size.width > 1.0f);
        
        CGFloat statusBarHeight = 0.0f;
        
        CGFloat glViewY = 0;
        DeviceScreen deviceScreen = [self deviceScreen];
        switch (deviceScreen)
        {
            case iPad:
                glViewY = isVertical ? 121 + 90 : 121;
                break;
                
            case iPadPro:
                glViewY = isVertical ? 221 + 110 : 221;
                break;
                
            case Inch35:
                glViewY = 62 - 20;
                break;
                
            case Inch4:
                glViewY = 62;
                break;
                
            case Inch47:
                glViewY = 62 + 25;
                break;
                
            case Inch55:
                glViewY = 62 + 45;
                break;
                
            default:
                break;
        }
        
        _stillLogoView.frame = CGRectChangedOriginY(_glkView.frame, glViewY - statusBarHeight);
        [self.view addSubview:_stillLogoView];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (_stillLogoView != nil)
    {
        [_stillLogoView removeFromSuperview];
        _stillLogoView = nil;
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self freeGL];
    
    [_stillLogoView removeFromSuperview];
    _stillLogoView = nil;
    _displayedStillLogo = false;
}

- (void)startButtonPress
{
    if (_startMessaging) {
        _startMessaging();
    }
}

- (void)updateAndRender
{
    [_glkView display];
    
    TGDispatchOnMainThread(^
    {
        if (_stillLogoView != nil)
        {
            [_stillLogoView removeFromSuperview];
            _stillLogoView = nil;
        }
    });
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_didEnterBackgroundObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:_willEnterBackgroundObserver];
    
    [self freeGL];
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:_glkView.context];
    
    
    set_telegram_textures(setup_texture(@"telegram_sphere.png"), setup_texture(@"telegram_plane.png"));
    
    set_ic_textures(setup_texture(@"ic_bubble_dot.png"), setup_texture(@"ic_bubble.png"), setup_texture(@"ic_cam_lens.png"), setup_texture(@"ic_cam.png"), setup_texture(@"ic_pencil.png"), setup_texture(@"ic_pin.png"), setup_texture(@"ic_smile_eye.png"), setup_texture(@"ic_smile.png"), setup_texture(@"ic_videocam.png"));
    
    set_fast_textures(setup_texture(@"fast_body.png"), setup_texture(@"fast_spiral.png"), setup_texture(@"fast_arrow.png"), setup_texture(@"fast_arrow_shadow.png"));
    
    set_free_textures(setup_texture(@"knot_up.png"), setup_texture(@"knot_down.png"));
    
    set_powerful_textures(setup_texture(@"powerful_mask.png"), setup_texture(@"powerful_star.png"), setup_texture(@"powerful_infinity.png"), setup_texture(@"powerful_infinity_white.png"));
    
     set_private_textures(setup_texture(@"private_door.png"), setup_texture(@"private_screw.png"));
    
    
    set_need_pages(0);
    
    
    on_surface_created();
    on_surface_changed(200, 200, 1, 0,0,0,0,0);
}

#pragma mark - GLKView delegate methods

- (void)glkView:(GLKView *)__unused view drawInRect:(CGRect)__unused rect
{
    double time = CFAbsoluteTimeGetCurrent();
    
    set_page((int)_currentPage);
    set_date(time);
    
    on_draw_frame();
}

static CGFloat x;
static bool justEndDragging;

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)__unused decelerate
{
    x = scrollView.contentOffset.x;
    justEndDragging = true;
}

NSInteger _current_page_end;

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat offset = (scrollView.contentOffset.x - _currentPage * scrollView.frame.size.width) / self.view.frame.size.width;
    
    set_scroll_offset((float)offset);
    
    if (justEndDragging)
    {
        justEndDragging = false;
        
        CGFloat page = scrollView.contentOffset.x / scrollView.frame.size.width;
        CGFloat sign = scrollView.contentOffset.x - x;
        
        if (sign > 0)
        {
            if (page > _currentPage)
                _currentPage++;
        }
        
        if (sign < 0)
        {
            if (page < _currentPage)
                _currentPage--;
        }
        
        _currentPage = MAX(0, MIN(5, _currentPage));
        _current_page_end = _currentPage;
    }
    else
    {
        if (_pageScrollView.contentOffset.x > _current_page_end*_pageScrollView.frame.size.width)
        {
            if (_pageScrollView.currentPageMin > _current_page_end) {
                _currentPage = [_pageScrollView currentPage];
                _current_page_end = _currentPage;
            }
        }
        else
        {
            if (_pageScrollView.currentPageMax < _current_page_end)
            {
                _currentPage = [_pageScrollView currentPage];
                _current_page_end = _currentPage;
            }
        }
    }
    
    [_pageControl setCurrentPage:_currentPage];
}

- (void)alternativeLanguageButtonPressed {
    
}

@end