/****************************************************************************
 Copyright (c) 2014-2016 Chukong Technologies Inc.
 Copyright (c) 2017-2018 Xiamen Yaji Software Co., Ltd.

 http://www.cocos2d-x.org

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 ****************************************************************************/

#include "platform/CCPlatformConfig.h"

// Webview not available on tvOS
#if (CC_TARGET_PLATFORM == CC_PLATFORM_IOS) && !defined(CC_TARGET_OS_TVOS)

#import <WebKit/WKWebView.h>
#import <WebKit/WKUIDelegate.h>
#import <WebKit/WKNavigationDelegate.h>

#include "WebView-inl.h"
#include "platform/CCApplication.h"
#include "platform/ios/CCEAGLView-ios.h"
#include "platform/CCFileUtils.h"

@interface UIWebViewWrapper : NSObject
@property (nonatomic) std::function<bool(std::string url)> shouldStartLoading;
@property (nonatomic) std::function<void(std::string url)> didFinishLoading;
@property (nonatomic) std::function<void(std::string url)> didFailLoading;
@property (nonatomic) std::function<void(std::string url)> onJsCallback;
@property (nonatomic,assign) NSString* wechatPayUrl;

@property(nonatomic, readonly, getter=canGoBack) BOOL canGoBack;
@property(nonatomic, readonly, getter=canGoForward) BOOL canGoForward;

+ (instancetype)webViewWrapper;

- (void)setVisible:(bool)visible;

- (void)setBounces:(bool)bounces;

- (void)setFrameWithX:(float)x y:(float)y width:(float)width height:(float)height;

- (void)setJavascriptInterfaceScheme:(const std::string &)scheme;

- (void)loadData:(const std::string &)data MIMEType:(const std::string &)MIMEType textEncodingName:(const std::string &)encodingName baseURL:(const std::string &)baseURL;

- (void)loadHTMLString:(const std::string &)string baseURL:(const std::string &)baseURL;

- (void)loadUrl:(const std::string &)urlString;

- (void)loadFile:(const std::string &)filePath;

- (void)stopLoading;

- (void)reload;

- (void)evaluateJS:(const std::string &)js;

- (void)goBack;

- (void)goForward;

- (void)setScalesPageToFit:(const bool)scalesPageToFit;

- (void)setBackgroundTransparent:(const bool)isTransparent;
@end


@interface UIWebViewWrapper () <WKUIDelegate, WKNavigationDelegate>
@property(nonatomic, assign) WKWebView *uiWebView;
@property(nonatomic, copy) NSString *jsScheme;
@end

@implementation UIWebViewWrapper {

}

+ (instancetype)webViewWrapper {
    return [[[self alloc] init] autorelease];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.uiWebView = nil;
        self.shouldStartLoading = nullptr;
        self.didFinishLoading = nullptr;
        self.didFailLoading = nullptr;
    }
    return self;
}

- (void)dealloc {
    self.uiWebView.UIDelegate = nil;
    [self.uiWebView removeFromSuperview];
    [self.uiWebView release];
    self.jsScheme = nil;
    [super dealloc];
}

- (void)setupWebView {
    if (!self.uiWebView) {
        self.uiWebView = [[WKWebView alloc] init];
        self.uiWebView.UIDelegate = self;
        self.uiWebView.navigationDelegate = self;
    }
    if (!self.uiWebView.superview) {
        auto eaglview = (CCEAGLView*)cocos2d::Application::getInstance()->getView();
        [eaglview addSubview:self.uiWebView];
    }
    
    if(@available(iOS 11.0, *)){
        self.uiWebView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
}

- (void)setVisible:(bool)visible {
    self.uiWebView.hidden = !visible;
}

- (void)setBounces:(bool)bounces {
    self.uiWebView.scrollView.bounces = bounces;
}

- (void)setFrameWithX:(float)x y:(float)y width:(float)width height:(float)height {
    if (!self.uiWebView) {[self setupWebView];}
    CGRect newFrame = CGRectMake(x, y, width, height);
    if (!CGRectEqualToRect(self.uiWebView.frame, newFrame)) {
        self.uiWebView.frame = CGRectMake(x, y, width, height);
    }
}

- (void)setJavascriptInterfaceScheme:(const std::string &)scheme {
    self.jsScheme = @(scheme.c_str());
}

- (void)loadData:(const std::string &)data MIMEType:(const std::string &)MIMEType textEncodingName:(const std::string &)encodingName baseURL:(const std::string &)baseURL {
    auto path = [[NSBundle mainBundle] resourcePath];
    path = [path stringByAppendingPathComponent:@(baseURL.c_str() )];
    auto url = [NSURL fileURLWithPath:path];

    [self.uiWebView loadData:[NSData dataWithBytes:data.c_str() length:data.length()]
                    MIMEType:@(MIMEType.c_str())
       characterEncodingName:@(encodingName.c_str())
                     baseURL:url];
}

- (void)loadHTMLString:(const std::string &)string baseURL:(const std::string &)baseURL {
    if (!self.uiWebView) {[self setupWebView];}
    auto path = [[NSBundle mainBundle] resourcePath];
    path = [path stringByAppendingPathComponent:@(baseURL.c_str() )];
    auto url = [NSURL fileURLWithPath:path];
    [self.uiWebView loadHTMLString:@(string.c_str()) baseURL:url];
}

- (void)loadUrl:(const std::string &)urlString {
    if (!self.uiWebView) {[self setupWebView];}
    NSURL *url = [NSURL URLWithString:@(urlString.c_str())];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.uiWebView loadRequest:request];
}

- (void)loadFile:(const std::string &)filePath {
    if (!self.uiWebView) {[self setupWebView];}
    NSURL *url = [NSURL fileURLWithPath:@(filePath.c_str())];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.uiWebView loadRequest:request];
}

- (void)stopLoading {
    [self.uiWebView stopLoading];
}

- (void)reload {
    [self.uiWebView reload];
}

- (BOOL)canGoForward {
    return self.uiWebView.canGoForward;
}

- (BOOL)canGoBack {
    return self.uiWebView.canGoBack;
}

- (void)goBack {
    [self.uiWebView goBack];
}

- (void)goForward {
    [self.uiWebView goForward];
}

- (void)evaluateJS:(const std::string &)js {
    if (!self.uiWebView) {[self setupWebView];}
    [self.uiWebView evaluateJavaScript:@(js.c_str()) completionHandler:nil];
}

- (void)setScalesPageToFit:(const bool)scalesPageToFit {
    // TODO: there is not corresponding API in WK.
    // https://stackoverflow.com/questions/26295277/wkwebview-equivalent-for-uiwebviews-scalespagetofit/43048514 seems has a solution,
    // but it doesn't support setting it dynamically. If we want to set this feature dynamically, then it will be too complex.
}

- (void)setBackgroundTransparent:(const bool)isTransparent {
    if (!self.uiWebView) {[self setupWebView];}
    [self.uiWebView setOpaque:isTransparent ? NO : YES];
    [self.uiWebView setBackgroundColor:isTransparent ? [UIColor clearColor] : [UIColor whiteColor]];
}

#pragma mark - WKNavigationDelegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSString *url = [[navigationAction request].URL.absoluteString stringByRemovingPercentEncoding];
    NSString* scheme = [navigationAction request].URL.scheme;

    NSURL *URL = [navigationAction request].URL;
    NSString *myScheme = @"www.10fenkexue.com";
    if ([URL.host isEqualToString:@"wx.tenpay.com"]) {

        NSArray *array = [url componentsSeparatedByString:@"redirect_url="];
        if([array count] == 2){
            self.wechatPayUrl = [[NSString alloc] initWithString:[array objectAtIndex:1]];
        }
        
        decisionHandler(WKNavigationActionPolicyAllow);
        NSURLComponents *cmps = [[NSURLComponents alloc] initWithURL:URL resolvingAgainstBaseURL:YES];
        NSString *redirect_url = nil;
        for (NSURLQueryItem *item in cmps.queryItems) {
            if ([item.name isEqualToString:@"redirect_url"]) {
                redirect_url = item.value;
                break;
            }
        }
        if (redirect_url == nil) return;
        NSURL *redirect_URL = [NSURL URLWithString:redirect_url];
        if (redirect_URL == nil) return;
        NSString *replaceScheme = redirect_URL.scheme;
        // 如果replaceScheme已经被替换过了就不再替换了
        if (replaceScheme == nil || [replaceScheme isEqualToString:myScheme]) return;
        NSString *my_redirect_url = [redirect_url stringByReplacingOccurrencesOfString:replaceScheme withString:myScheme];
        NSString *urlAbsoluteString = [URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:(NSUTF8StringEncoding)];
        NSString *my_requestUrl = [urlAbsoluteString stringByReplacingOccurrencesOfString:redirect_url withString:my_redirect_url];
        NSURL *my_requestURL = [NSURL URLWithString:my_requestUrl];
        NSMutableURLRequest *my_request = [NSMutableURLRequest requestWithURL:my_requestURL];
        if (my_requestURL == nil) return;
        my_request.allHTTPHeaderFields = [navigationAction request].allHTTPHeaderFields;
        // 让webView加载被修改过的request
        // 这会导致本方法再次被调用哦
        [webView loadRequest:my_request];
        return;
    }

     if ([url hasPrefix:@"alipays://"] || [url hasPrefix:@"alipay://"]) {
          [[UIApplication sharedApplication]openURL:[navigationAction request].URL];
         //bSucc是否成功调起支付宝
     }
     else if ([url hasPrefix:@"weixin://"]) {
         [[UIApplication sharedApplication]openURL:[navigationAction request].URL];
         //bSucc是否成功调起微信
     }
     else if ([URL.scheme isEqualToString:myScheme]) {
         // 在微信支付完成或失败后回到APP会调用
         // 将xxx.faker.com://www.myFaker.com/epay…
         // 修改成 https://www.myFaker.com/epay…
         // 让webView重新加载
         decisionHandler(WKNavigationActionPolicyCancel);

         NSString *urlAbsoluteString = self.wechatPayUrl; //[URL.absoluteString stringByReplacingPercentEscapesUsingEncoding:(NSUTF8StringEncoding)];
         NSString *schemeDetail = [NSString stringWithFormat:@"%@://",myScheme];
         NSString *targetUrl = [urlAbsoluteString stringByReplacingOccurrencesOfString:schemeDetail withString:@"https://"];
         NSURL *targetURL = [NSURL URLWithString:targetUrl];
         //NSURL *targetURL = [NSURL URLWithString:self.wechatPayUrl];
         NSURLRequest *request = [NSURLRequest requestWithURL:targetURL];
         [webView loadRequest:request];
         return;
     }
    
    
    if ([scheme isEqualToString:self.jsScheme]) {
        self.onJsCallback(url.UTF8String);
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    if (self.shouldStartLoading && url) {
        if (self.shouldStartLoading(url.UTF8String) )
            decisionHandler(WKNavigationActionPolicyAllow);
        else
            decisionHandler(WKNavigationActionPolicyCancel);

        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (self.didFinishLoading) {
        NSString *url = [webView.URL absoluteString];
        self.didFinishLoading([url UTF8String]);
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (self.didFailLoading) {
        NSString *errorInfo = error.userInfo[NSURLErrorFailingURLStringErrorKey];
        if (errorInfo) {
            self.didFailLoading([errorInfo UTF8String]);
        }
    }
}

#pragma WKUIDelegate

// Implement js alert function.
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)())completionHandler
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:message
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Ok"
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
                                                          completionHandler();
                                                      }]];

    auto rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    [rootViewController presentViewController:alertController animated:YES completion:^{}];
}

@end



namespace cocos2d {

    WebViewImpl::WebViewImpl(WebView *webView)
    : _uiWebViewWrapper([UIWebViewWrapper webViewWrapper]),
    _webView(webView) {
        [_uiWebViewWrapper retain];

        _uiWebViewWrapper.shouldStartLoading = [this](std::string url) {
            if (this->_webView->_onShouldStartLoading) {
                return this->_webView->_onShouldStartLoading(this->_webView, url);
            }
            return true;
        };
        _uiWebViewWrapper.didFinishLoading = [this](std::string url) {
            if (this->_webView->_onDidFinishLoading) {
                this->_webView->_onDidFinishLoading(this->_webView, url);
            }
        };
        _uiWebViewWrapper.didFailLoading = [this](std::string url) {
            if (this->_webView->_onDidFailLoading) {
                this->_webView->_onDidFailLoading(this->_webView, url);
            }
        };
        _uiWebViewWrapper.onJsCallback = [this](std::string url) {
            if (this->_webView->_onJSCallback) {
                this->_webView->_onJSCallback(this->_webView, url);
            }
        };
    }

    WebViewImpl::~WebViewImpl(){
        [_uiWebViewWrapper release];
        _uiWebViewWrapper = nullptr;
    }

    void WebViewImpl::setJavascriptInterfaceScheme(const std::string &scheme) {
        [_uiWebViewWrapper setJavascriptInterfaceScheme:scheme];
    }

    void WebViewImpl::loadData(const Data &data,
                               const std::string &MIMEType,
                               const std::string &encoding,
                               const std::string &baseURL) {

        std::string dataString(reinterpret_cast<char *>(data.getBytes()), static_cast<unsigned int>(data.getSize()));
        [_uiWebViewWrapper loadData:dataString MIMEType:MIMEType textEncodingName:encoding baseURL:baseURL];
    }

    void WebViewImpl::loadHTMLString(const std::string &string, const std::string &baseURL) {
        [_uiWebViewWrapper loadHTMLString:string baseURL:baseURL];
    }

    void WebViewImpl::loadURL(const std::string &url) {
        [_uiWebViewWrapper loadUrl:url];
    }

    void WebViewImpl::loadFile(const std::string &fileName) {
        auto fullPath = cocos2d::FileUtils::getInstance()->fullPathForFilename(fileName);
        [_uiWebViewWrapper loadFile:fullPath];
    }

    void WebViewImpl::stopLoading() {
        [_uiWebViewWrapper stopLoading];
    }

    void WebViewImpl::reload() {
        [_uiWebViewWrapper reload];
    }

    bool WebViewImpl::canGoBack() {
        return _uiWebViewWrapper.canGoBack;
    }

    bool WebViewImpl::canGoForward() {
        return _uiWebViewWrapper.canGoForward;
    }

    void WebViewImpl::goBack() {
        [_uiWebViewWrapper goBack];
    }

    void WebViewImpl::goForward() {
        [_uiWebViewWrapper goForward];
    }

    void WebViewImpl::evaluateJS(const std::string &js) {
        [_uiWebViewWrapper evaluateJS:js];
    }

    void WebViewImpl::setBounces(bool bounces) {
        [_uiWebViewWrapper setBounces:bounces];
    }

    void WebViewImpl::setScalesPageToFit(const bool scalesPageToFit) {
        [_uiWebViewWrapper setScalesPageToFit:scalesPageToFit];
    }

    void WebViewImpl::setVisible(bool visible){
        [_uiWebViewWrapper setVisible:visible];
    }

    void WebViewImpl::setFrame(float x, float y, float width, float height){
        auto eaglview = (CCEAGLView*)cocos2d::Application::getInstance()->getView();
        auto scaleFactor = [eaglview contentScaleFactor];
        [_uiWebViewWrapper setFrameWithX:x/scaleFactor
                                       y:y/scaleFactor
                                   width:width/scaleFactor
                                  height:height/scaleFactor];
    }

    void WebViewImpl::setBackgroundTransparent(bool isTransparent){
        [_uiWebViewWrapper setBackgroundTransparent:isTransparent];
    }
} //namespace cocos2d

#endif // CC_TARGET_PLATFORM == CC_PLATFORM_IOS
