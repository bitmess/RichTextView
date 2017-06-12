//
//  RichTextView.m
//  RichTextView
//
//  Created by jv on 2017/6/5.
//  Copyright © 2017年 jv. All rights reserved.
//

#import "RichTextView.h"
#import <CoreText/CoreText.h>
#import <CommonCrypto/CommonDigest.h>
#import "SDImageCache.h"
#import "SDWebImageDownloader.h"

//some macro for easy use
#define _F(...) [NSString stringWithFormat:__VA_ARGS__]
#define RGB(r,g,b) [UIColor colorWithRed:((float)(r))/255.0 green:((float)(g))/255.0 blue:((float)(b))/255.0 alpha:1.0]
#define kTextColor (RGB(51, 51, 51))
#define kLinkColor (RGB(40, 166, 247))
#define O_RANGE(__rg__, __o__)  NSMakeRange((__rg__).location - (__o__), (__rg__).length)


static NSUInteger const kQuanWenLength = 5;//[more] character length
static CGFloat const kFontSize = 16;

static NSString *kTopicSymbol = @"#";
static NSString *kTopicRegex = @"#[^#]+?#";


static NSString *kUrl = @"url";//attributed config key for anchor A link
static NSString *kHttp = @"http";//attributed config key for http link
static NSString *kEmoji = @"emoji";//attributed config key for emoji
static NSString *kImage = @"img";//attributed config key for net image
static NSString *kLocalImage = @"localimg";//attributed config key for local image
static NSString *kTopic = @"topic";//attributed config key for topic
static NSString *kPlaceHolderString = @" ";//attributed config key for image holder string

static NSArray *kImageExtensions = nil;//image displayed to filter

//emoji normal
void    kEmojiRunDelegateDeallocCallback(void* refCon){}
CGFloat kEmojiRunDelegateGetAscentCallback(void *refCon ){return 17;}
CGFloat kEmojiRunDelegateGetDescentCallback(void *refCon){return 5;}
CGFloat kEmojiRunDelegateGetWidthCallback(void *refCon){return 22;}
CTRunDelegateCallbacks kRichTextEmojiCallbacks = (CTRunDelegateCallbacks)
{
    kCTRunDelegateCurrentVersion,
    kEmojiRunDelegateDeallocCallback,
    kEmojiRunDelegateGetAscentCallback,
    kEmojiRunDelegateGetDescentCallback,
    kEmojiRunDelegateGetWidthCallback
};

//emoji custom
void    kCustomEmojiDealloc(void* refCon){}
CGFloat kCustomEmojiGetAscent(void *refCon ){
    NSString *imageName = (__bridge NSString *)refCon;
    
    UIImage *image = [UIImage imageNamed:imageName];
    
    return image.size.height;
}
CGFloat kCustomEmojiGetDescent(void *refCon){
    return 0;
}
CGFloat kCustomEmojiGetWidth(void *refCon){
    NSString *imageName = (__bridge NSString *)refCon;
    
    UIImage *image = [UIImage imageNamed:imageName];
    
    return image.size.width;
}
CTRunDelegateCallbacks kRichTextCustomEmojiCallbacks = (CTRunDelegateCallbacks)
{
    kCTRunDelegateCurrentVersion,
    kCustomEmojiDealloc,
    kCustomEmojiGetAscent,
    kCustomEmojiGetDescent,
    kCustomEmojiGetWidth
};

//network image
void kImageDeallocCallback( void* refCon ){
    
}
CGFloat kImageGetAscentCallback( void *refCon ){
    NSString *md5 = (__bridge NSString *)refCon;
    
    UIImage *image = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:md5];
    
    return image.size.height / 2.;
}
CGFloat kImageGetDescentCallback(void *refCon){
    return 0;
}
CGFloat kImageGetWidthCallback(void *refCon){
    NSString *md5 = (__bridge NSString *)refCon;
    
    UIImage *image = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:md5];
    
    return image.size.width / 2.;
}
CTRunDelegateCallbacks kRichTextImageCallbacks = (CTRunDelegateCallbacks)
{
    kCTRunDelegateCurrentVersion,
    kImageDeallocCallback,
    kImageGetAscentCallback,
    kImageGetDescentCallback,
    kImageGetWidthCallback
};

//local image
void kLocalImageDeallocCallback( void* refCon ){
    
}
CGFloat kLocalImageGetAscentCallback( void *refCon ){
    NSString *imageName = (__bridge NSString *)refCon;
    
    UIImage *image = [UIImage imageNamed:imageName];
    
    return image.size.height;
}
CGFloat kLocalImageGetDescentCallback(void *refCon){
    return 0;
}
CGFloat kLocalImageGetWidthCallback(void *refCon){
    NSString *imageName = (__bridge NSString *)refCon;
    
    UIImage *image = [UIImage imageNamed:imageName];
    
    return image.size.width + 5;
}
CTRunDelegateCallbacks kRichTextLocalImageCallbacks = (CTRunDelegateCallbacks)
{
    kCTRunDelegateCurrentVersion,
    kLocalImageDeallocCallback,
    kLocalImageGetAscentCallback,
    kLocalImageGetDescentCallback,
    kLocalImageGetWidthCallback
};


//emoji init
static NSMutableDictionary* kNormalEmojis = nil;
static void InitializeEmojis()
{
    NSString* emojisKeyPath    = [[NSBundle mainBundle] pathForResource:@"emoticon_KeyforImageName" ofType:@"plist"];
    NSArray* fArrary    = [NSArray arrayWithContentsOfFile:emojisKeyPath];
    NSArray* baseEmojis = [[[fArrary firstObject] objectForKey:@"String"] componentsSeparatedByString:@","];
    kNormalEmojis             = [NSMutableDictionary dictionary];
    
    for (int i = 0 ;i < baseEmojis.count ;i++) {
        kNormalEmojis[baseEmojis[i]] = [NSString stringWithFormat:@"%02d_base",i];
    }
    
}

static inline NSString *NSStringCCHashFunction(unsigned char *(function)(const void *data, CC_LONG len, unsigned char *md), CC_LONG digestLength, NSString *string)
{
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[digestLength];
    
    function(data.bytes, (CC_LONG)data.length, digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:digestLength * 2];
    
    for (int i = 0; i < digestLength; i++)
    {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return output;
}

@interface RichTextView ()
{
    NSMutableAttributedString* _attributedString;
    BOOL _hasMaxRow;
}

@end

@implementation RichTextView


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self _init];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self _init];
}


- (void)_init {
    
    self.backgroundColor = [UIColor clearColor];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)];
    [self addGestureRecognizer:tap];
    
    _maxRow = NSNotFound;
    _maxWidth = 0;
    
    UILongPressGestureRecognizer *longGes = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressAction:)];
    [self addGestureRecognizer:longGes];
    
}


- (void)drawRect:(CGRect)rect
{
    
    if (_attributedString == nil) {
        return;
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    [self.backgroundColor setFill];
    CGContextFillRect(context, rect);
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGAffineTransform flipVertical = CGAffineTransformMake(1,0,0,-1,0,rect.size.height);
    CGContextConcatCTM(context, flipVertical);
    
    CTFramesetterRef ctFramesetter = CTFramesetterCreateWithAttributedString((CFMutableAttributedStringRef)_attributedString);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, rect.size.width, rect.size.height));
    
    CFRange range  = CFRangeMake(0, 0);
    CTFrameRef ctFrame    = CTFramesetterCreateFrame(ctFramesetter,range, path, NULL);
    CFArrayRef lines      = CTFrameGetLines(ctFrame);
    CFIndex linesCount    = CFArrayGetCount(lines);
    
    CGPoint* lineOrigins = (CGPoint*)malloc(linesCount * sizeof(CGPoint));
    if (lineOrigins == NULL) {
        goto ReleaseResources;
    }
    
    CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), lineOrigins);
    
    
    if (_hasMaxRow) {
        linesCount = linesCount > _maxRow ? _maxRow : linesCount;
    }
    
    for (int i = 0; i < linesCount; i++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGFloat lineAscent;
        CGFloat lineDescent;
        CGFloat lineLeading;
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading);
        
        CGPoint lineOrigin = lineOrigins[i];
        
        CGContextSetTextPosition(context, lineOrigin.x, lineOrigin.y);
        
        //draw emoji or local image
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        CFIndex runCount = CFArrayGetCount(runs);
        for (int j = 0; j < runCount; j++) {
            
            if (_hasMaxRow) {
                if (i + 1 == linesCount && runCount - j <= kQuanWenLength) {
                    break;
                }
            }
            
            CGFloat runAscent;
            CGFloat runDescent;
            CTRunRef run = CFArrayGetValueAtIndex(runs, j);
            NSDictionary* attributes = (NSDictionary*)CTRunGetAttributes(run);
            
            CGRect runRect;
            runRect.size.width = CTRunGetTypographicBounds(run, CFRangeMake(0,0), &runAscent, &runDescent, NULL);
            runRect=CGRectMake(lineOrigin.x + CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, NULL), lineOrigin.y - runDescent, runRect.size.width, runAscent + runDescent);
            
            
            NSString *emoji = [attributes objectForKey:kEmoji];
            if (emoji) {
                UIImage *image = [UIImage imageNamed:emoji];
                if (image) {
                    CGRect imageDrawRect;
                    imageDrawRect.size = self.richTextConfig.emojiType == RichTextEmojiNormal ? CGSizeMake(22, 22) : CGSizeMake(image.size.width, image.size.height);
                    imageDrawRect.origin.x = runRect.origin.x + lineOrigin.x;
                    imageDrawRect.origin.y = self.richTextConfig.emojiType == RichTextEmojiNormal ? lineOrigin.y - 6 : runRect.origin.y;
                    CGContextDrawImage(context, imageDrawRect, image.CGImage);
                    
                    
                }
            }
            
            
            NSString *md5 = [attributes objectForKey:kImage];
            NSString *localImageName = [attributes objectForKey:kLocalImage];
            if (md5 || localImageName) {
                UIImage *image;
                
                if (md5) {
                    image = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:md5];
                }else if (localImageName) {
                    
                    image = [UIImage imageNamed:localImageName];
                }
                
                
                CGRect imageDrawRect;
                imageDrawRect.size = CGSizeMake(image.size.width, image.size.height);
                
                if (!localImageName) {
                    imageDrawRect.size =  CGSizeMake(image.size.width / 2., image.size.height / 2.);
                }
                
                imageDrawRect.origin.x = runRect.origin.x + lineOrigin.x;
                imageDrawRect.origin.y = lineOrigin.y ;
                CGContextDrawImage(context, imageDrawRect, image.CGImage);
            }
        }
        
        //draw text
        if (_hasMaxRow) {
            
            if (i != linesCount - 1) {//不是最后一行
                
                CTLineDraw(line, context);//draw 行文字
                
            }else {// 最后一行，加上省略号
                
                CFRange lastLineRange = CTLineGetStringRange(line);
                
                NSUInteger copyLength = lastLineRange.length - kQuanWenLength;
                
                if (copyLength > lastLineRange.length ) {
                    copyLength = lastLineRange.length;
                }
                
                CTLineTruncationType truncationType = kCTLineTruncationEnd;
                
                NSMutableAttributedString *tokenString = [[NSMutableAttributedString alloc] initWithString:@"\u2026" attributes:self.richTextConfig.textAttributes];
                
                NSMutableAttributedString *quanwen = [[NSMutableAttributedString alloc] initWithString:@"[more]" attributes:self.richTextConfig.textAttributes];
                [quanwen addAttribute: NSForegroundColorAttributeName value:kLinkColor range:NSMakeRange(0, quanwen.length)];
                
                [tokenString appendAttributedString:quanwen];
                
                CTLineRef truncationToken = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)tokenString);
                
                NSMutableAttributedString *truncationString = [[_attributedString attributedSubstringFromRange:NSMakeRange(lastLineRange.location, copyLength)] mutableCopy];
                
                [truncationString appendAttributedString:tokenString];
                
                CTLineRef truncationLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)truncationString);
                
                CTLineRef truncatedLine = CTLineCreateTruncatedLine(truncationLine, rect.size.width, truncationType, truncationToken);
                
                if (!truncatedLine)
                {
                    truncatedLine = CFRetain(truncationToken);
                }
                
                CFRelease(truncationLine);
                CFRelease(truncationToken);
                
                CTLineDraw(truncatedLine, context);
                CFRelease(truncatedLine);
                
                break;
            }
            
        }
        
    }
    
    free(lineOrigins);
    
    if (!_hasMaxRow) {
        CTFrameDraw(ctFrame,context);
    }
    
ReleaseResources:
    CFRelease(ctFrame);
    CFRelease(path);
    CFRelease(ctFramesetter);
    CGContextRestoreGState(context);
}

- (BOOL)canBecomeFirstResponder {
    
    return YES;
    
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    
    
    return action == @selector(copyAction);
    
}


#pragma mark - method

- (id)_clickedAttr:(CGPoint)atpoint
{
    /*  if (_maxRow != NSNotFound) {
     return nil;
     }*/
    
    NSDictionary *result = nil;
    
    CTFramesetterRef ctFramesetter = CTFramesetterCreateWithAttributedString((CFMutableAttributedStringRef)_attributedString);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, self.bounds);
    
    CTFrameRef ctFrame    = CTFramesetterCreateFrame(ctFramesetter,CFRangeMake(0, 0), path, NULL);
    CFArrayRef lines      = CTFrameGetLines(ctFrame);
    if (!lines) {
        return nil;
    }
    CFIndex linesCount    = CFArrayGetCount(lines);
    
    CGPoint* lineOrigins = (CGPoint*)malloc(linesCount * sizeof(CGPoint));
    if (lineOrigins == NULL) {
        goto ReleaseResources;
    }
    
    CTFrameGetLineOrigins(ctFrame, CFRangeMake(0, 0), lineOrigins);
    CGAffineTransform transform =  CGAffineTransformScale(CGAffineTransformMakeTranslation(0, self.bounds.size.height), 1.f, -1.f);
    
    for (int i = 0; i < linesCount; i++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGFloat lineAscent;
        CGFloat lineDescent;
        CGFloat lineLeading;
        CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading);
        CGPoint lineOrigin = lineOrigins[i];
        CGRect lineRect = CGRectMake(lineOrigin.x, lineOrigin.y, self.bounds.size.width, lineAscent + lineDescent + lineLeading);
        CGRect tlrect = CGRectApplyAffineTransform(lineRect, transform);
        if (CGRectContainsPoint(tlrect, atpoint)) {
            CGPoint relativePoint = CGPointMake(atpoint.x-CGRectGetMinX(tlrect),
                                                atpoint.y-CGRectGetMinY(tlrect));
            CFIndex idx = CTLineGetStringIndexForPosition(line, relativePoint);
            if (idx >= [_attributedString length]) {
                break;
            }
            NSDictionary* attr = [_attributedString attributesAtIndex:idx effectiveRange:nil];
            result = attr;
            //            if ([attr hasKey:key] ) {
            //                result = attr[key];
            //            }
            break;
        }
        
    }
    
    free(lineOrigins);
    
ReleaseResources:
    CFRelease(ctFrame);
    CFRelease(path);
    CFRelease(ctFramesetter);
    
    
    return result;
}


- (void)_convertTextToAttributedString {
    _attributedString = RichTextParseToAttributedString(_text,_localImageConfigs,self.richTextConfig);
    CGFloat maxWidth = _maxWidth != 0 ? _maxWidth : self.bounds.size.width;
    _size = _doRichTextHeight(_attributedString,  maxWidth, _maxRow, NO,&_hasMaxRow);
}

#pragma mark - object method

- (void)reload {
    
    [self _convertTextToAttributedString];
    
    [self setNeedsDisplay];
    
}

#pragma mark - setter

- (void)setText:(NSString *)text {
    _text = text.length == 0 ? @" " : text;
    [self reload];
}

- (void)setMaxRow:(NSUInteger)maxRow {
    _maxRow = maxRow;
    
    [self setNeedsDisplay];
}

#pragma mark - getter

- (RichTextConfig *)richTextConfig {
    
    return _richTextConfig ?: [RichTextConfig defaultConfig];
    
}


#pragma mark - action

- (void)copyAction {
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = self.text;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"copied"
                                                    message:@"text copied"
                                                   delegate:nil
                                          cancelButtonTitle:@"ok"
                                          otherButtonTitles:nil];
    [alert show];
    
}


- (void)longPressAction:(UILongPressGestureRecognizer *)sender {
    
    
    if (sender.state == UIGestureRecognizerStateBegan) {
        
        [self becomeFirstResponder];
        UIMenuController* menuController = [UIMenuController sharedMenuController];
        NSMutableArray *menuItemArray = [NSMutableArray array];
        [menuItemArray addObject:[[UIMenuItem alloc] initWithTitle:@"copy" action: @selector(copyAction)]];
        [menuController setMenuItems:menuItemArray];
        [menuController setArrowDirection:UIMenuControllerArrowDown];
        CGRect rect = self.frame;
        [menuController setTargetRect:rect inView:self];
        [menuController setMenuVisible:YES animated:YES];
    }
    
}

- (void) tapAction:(UITapGestureRecognizer*) sender
{
    BOOL delegateOk = YES;
    CGPoint location = [sender locationInView:self];
    
    NSDictionary* attr = [self _clickedAttr:location];
    
    if (!!attr[kImage] || !!attr[kLocalImage]) {
        
        UIImage *image = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:attr[kImage]];
        
        if (image == nil) {
            image = [UIImage imageNamed:attr[kLocalImage]];
        }
        
        if ([_delegate respondsToSelector:@selector(richtextView:didImageClicked:image:)]) {
            [_delegate richtextView:self didImageClicked:attr[kUrl] image:image];
            delegateOk = NO;
        }
        
    }else if (!!attr[kUrl]) {
        
        if ([_delegate respondsToSelector:@selector(richtextView:didUrlClicked:)]) {
            [_delegate richtextView:self didUrlClicked:attr[kUrl]];
            delegateOk = NO;
        }
        
    }else if (!!attr[kTopic]) {
        
        if ([_delegate respondsToSelector:@selector(richtextView:didTopicClicked:)]) {
            [_delegate richtextView:self didTopicClicked:attr[kTopic]];
            delegateOk = NO;
        }
        
    }
    
    if (delegateOk) {
        if ([_delegate respondsToSelector:@selector(richtextViewDidTapped:)]) {
            [_delegate richtextViewDidTapped:self];
        }
        return;
    }
}



#pragma mark - function

CGFloat RichTextGetHeight(NSString *text, int maxWidth, NSUInteger maxRow, RichTextConfig *config, NSArray *imageConfig) {
    
    RichTextConfig *c = config ?: [RichTextConfig defaultConfig];
    
    NSMutableAttributedString *attrString = RichTextParseToAttributedString(text, imageConfig, c);
    
    CGSize size = RichTextHeight(attrString, maxWidth, maxRow, YES);
    
    return size.height;
}


NSMutableAttributedString* RichTextParseToAttributedString(NSString *text,NSArray *localImageConfigs,RichTextConfig *config) {
    
    
    NSMutableAttributedString* contentAttributedString = [[NSMutableAttributedString alloc] initWithString:text];
    
    contentAttributedString = RichTextParseEmojiByType(contentAttributedString,config.emojiType);
    
    contentAttributedString = doRichTextParseLocalImage(contentAttributedString,localImageConfigs);
    
    [contentAttributedString addAttributes:config.textAttributes range:(NSRange){0,contentAttributedString.length}];
    
    contentAttributedString = RichTextParseLink(contentAttributedString, config.linkedTextAttributes);
    contentAttributedString = doRichTextParseHttp(contentAttributedString,config.linkedTextAttributes,YES);
    contentAttributedString = doRichTextParseTopic(contentAttributedString,config.linkedTextAttributes);
    
    //    解决只有[赞]无法显示的问题
    if (contentAttributedString.string.trim.length == 0) {
        NSMutableAttributedString *blank = [[NSMutableAttributedString alloc] initWithString:kPlaceHolderString attributes:config.textAttributes];
        
        [contentAttributedString appendAttributedString:blank];
    }
    
    return contentAttributedString;
}

CGSize RichTextHeight(NSAttributedString *string ,int maxWidth, NSUInteger maxRow, BOOL isSingleRowFitWidth) {
    
    return _doRichTextHeight(string,maxWidth,maxRow,isSingleRowFitWidth,NULL);
    
}

CGSize _doRichTextHeight(NSAttributedString *string ,int maxWidth, NSUInteger maxRow, BOOL isSingleRowFitWidth, BOOL *hasMaxRow)
{
    static int maxHeight = 1000;
    
    CGSize size = CGSizeMake(maxWidth, maxHeight);
    
    int total_height = 0;
    
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)string);//string 为要计算高度的NSAttributedString
    CGRect drawingRect = CGRectMake(0, 0, maxWidth, maxHeight);//这里的高要设置足够大
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, drawingRect);
    CFRange range;
    CTFrameRef textFrame = NULL;
    NSInteger linesCount = 0;
    NSArray *linesArray = nil;
    
    range = CFRangeMake(0, 0);
    textFrame = CTFramesetterCreateFrame(framesetter,range, path, NULL);
    linesArray = (NSArray *) CTFrameGetLines(textFrame);
    linesCount = [linesArray count];
    
    
    CGPathRelease(path);
    CFRelease(framesetter);
    
    
    CGPoint origins[linesCount];
    CTFrameGetLineOrigins(textFrame, CFRangeMake(0, 0), origins);
    
    int line_y = 0;   //最后一行line的原点y坐标
    
    BOOL isMaxRow = maxRow != NSNotFound && maxRow < linesCount;
    if (hasMaxRow != NULL) {
        *hasMaxRow = isMaxRow;
    }
    NSInteger indexRow;
    
    if (isMaxRow) {
        
        indexRow = maxRow - 1;
        
    }else {
        
        indexRow = [linesArray count] - 1;
        
    }
    
    if (indexRow >= 0) {
        line_y = (int)origins[indexRow].y;  //最后一行line的原点y坐标
    }
    
    
    
    CGFloat ascent;
    CGFloat descent;
    CGFloat leading;
    
    
    if([linesArray count] == 0){
        size.width = 16;
        size.height = 17;
    } else {
        
        CTLineRef line = (__bridge CTLineRef)[linesArray objectAtIndex:indexRow];
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        
        
        total_height = maxHeight - line_y + (int)descent + 1;//+1为了纠正descent转换成int小数点后舍去的值
        
        if (!isSingleRowFitWidth && linesCount < 2) {
            CFArrayRef runs = CTLineGetGlyphRuns(line);
            for (int j = 0; j < CFArrayGetCount(runs); j++) {
                CGFloat runAscent;
                CGFloat runDescent;
                CGPoint lineOrigin = origins[0];
                CTRunRef run = CFArrayGetValueAtIndex(runs, j);
                CGRect runRect;
                runRect.size.width = CTRunGetTypographicBounds(run, CFRangeMake(0,0), &runAscent, &runDescent, NULL);
                runRect=CGRectMake(lineOrigin.x + CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, NULL), lineOrigin.y - runDescent, runRect.size.width, runAscent + runDescent);
                size.width = runRect.origin.x + runRect.size.width;
            }
        }
        
        CFRelease(textFrame);
        
        
        size.height = total_height;
    }
    
    size.width = size.width > maxWidth ? maxWidth : size.width;
    
    return size;
}

NSMutableAttributedString * RichTextParseEmoji(NSMutableAttributedString *contentAttributedString) {
    
    return RichTextParseEmojiByType(contentAttributedString,RichTextEmojiNormal);
}


NSMutableAttributedString * RichTextParseEmojiByType(NSMutableAttributedString *contentAttributedString,RichTextEmojiType type) {
    
    NSDictionary *emojis;
    
    if (kNormalEmojis == nil) {
        InitializeEmojis();
    }
    
    switch (type) {
        case RichTextEmojiNormal :
        default: {
            emojis = kNormalEmojis;
            break;
        }
    }
    
    
    NSString *s = [contentAttributedString.string copy];
    NSMutableString *m_s = [contentAttributedString.string mutableCopy];
    
    NSRegularExpression* regex = [[NSRegularExpression alloc] initWithPattern:@"\\[(\\d|\\D)+?\\]" options:NSRegularExpressionCaseInsensitive error:nil];
    NSArray* chunks = [regex matchesInString:s options:NSMatchingWithTransparentBounds range:NSMakeRange(0, [s length])];
    NSUInteger stringInsertIndex = 0;
    NSRange preRange = {0,0};
    
    NSMutableArray *resultMatches = [NSMutableArray array];
    
    for (NSTextCheckingResult *chunk in chunks) {
        NSString* emojiWithSeparator = [s substringWithRange:chunk.range];
        NSString* emoji = nil;
        if (emojiWithSeparator.length > 2) {
            emoji = [emojiWithSeparator substringFromIndex:1];
            emoji = [emoji substringToIndex:emoji.length - 1];
        }
        
        NSString* emojiImageName = emojis[emoji];
        if (emojiImageName == nil) {//emoji not found
            continue;
        }
        
        CTRunDelegateCallbacks callbacks = type == RichTextEmojiNormal ? kRichTextEmojiCallbacks : kRichTextCustomEmojiCallbacks;
        CTRunDelegateRef runDelegate  = CTRunDelegateCreate(&callbacks, (__bridge void *)(emojiImageName));
        
        NSDictionary *attr = @{
                               kEmoji : emojiImageName,
                               (NSString *)kCTRunDelegateAttributeName : (__bridge id)runDelegate,
                               @"uuid":[[NSUUID UUID] UUIDString]
                               };
        
        
        CFRelease(runDelegate);
        
        
        if (stringInsertIndex) {
            stringInsertIndex += chunk.range.location - preRange.location  - preRange.length;
        } else {
            stringInsertIndex = chunk.range.location;
        }
        
        [m_s deleteCharactersInRange:NSMakeRange(stringInsertIndex, chunk.range.length)];
        [m_s insertString:kPlaceHolderString atIndex:stringInsertIndex];
        
        
        [resultMatches addObject:@{
                                   [NSValue valueWithRange:(NSRange){stringInsertIndex,[kPlaceHolderString length]}] : attr
                                   }];
        
        ++stringInsertIndex;
        
        preRange.location = chunk.range.location;
        preRange.length   = chunk.range.length;
    }
    
    NSMutableAttributedString *c = [[NSMutableAttributedString alloc] initWithString:m_s];
    
    
    [c beginEditing];
    for (NSDictionary *param in resultMatches) {
        
        NSValue *range = [[param allKeys] firstObject];
        NSRange r = [range rangeValue];
        
        NSDictionary *attr = [[param allValues] firstObject];
        
        [c addAttributes:attr range:r];
    }
    [c endEditing];
    
    
    return c;
}


NSMutableAttributedString* RichTextParseLink(NSMutableAttributedString* string,NSDictionary *attibutes)
{
    static  NSRegularExpression* regex = nil;
    if (regex == nil) {
        regex = [[NSRegularExpression alloc] initWithPattern:@"<a(?:[\\d\\D]*?)?\\s+href\\s*=\\s*[\"'](.*?)[\"']\\s*(?:[\\d\\D]*?)?>([\\d\\D]*?)</a>" options:NSRegularExpressionUseUnicodeWordBoundaries | NSRegularExpressionDotMatchesLineSeparators error:nil];
    }
    
    NSString *contentString = [string.string copy];
    
    NSArray* chunks = [regex matchesInString:contentString options:0 range:NSMakeRange(0, [contentString length])];
    if (chunks.count < 1) {
        return string;
    }
    
    
    NSMutableDictionary* urltextattr = [NSMutableDictionary dictionaryWithDictionary:attibutes];
    int offset = 0;
    for (NSTextCheckingResult *chunk in chunks) {
        if (chunk.numberOfRanges != 3) {
            continue;
        }
        
        NSRange chnrange  = O_RANGE([chunk rangeAtIndex:0], offset);
        NSRange urlrange  = O_RANGE([chunk rangeAtIndex:1], offset);
        NSRange textrange = O_RANGE([chunk rangeAtIndex:2], offset);
        
        NSString* chn = [contentString substringWithRange:chnrange];
        NSString* url = [contentString substringWithRange:urlrange];
        NSString* text = [contentString substringWithRange:textrange];
        
        [string replaceCharactersInRange:chnrange withString:text];
        
        textrange.location = chnrange.location;
        
        urltextattr[kUrl] = url;
        [string setAttributes:urltextattr range:textrange];
        
        offset += chn.length - text.length;
        
    }
    
    return string;
}


NSMutableAttributedString* RichTextParseHttp(NSMutableAttributedString* string,NSDictionary *attibutes){
    
    return doRichTextParseHttp(string, attibutes, YES);
    
}


NSMutableAttributedString* doRichTextParseHttp(NSMutableAttributedString* string,NSDictionary *attibutes,BOOL needParseImage)
{
    static  NSRegularExpression* regex = nil;
    if (regex == nil) {
        
        regex = [[NSRegularExpression alloc] initWithPattern:@"((?:(http|https|Http|Https):\\/\\/(?:(?:[a-zA-Z0-9\\$\\-\\_\\.\\+\\!\\*\'\(\\)\\,\\;\?\\&\\=]|(?:\%[a-fA-F0-9]{2})){1,64}(?:\\:(?:[a-zA-Z0-9\\$\\-\\_\\.\\+\\!\\*\'\(\\)\\,\\;\?\\&\\=]|(?:\%[a-fA-F0-9]{2})){1,25})?\\@)?)?(?:(([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9]){0,1}\\.)+[a-zA-Z]{2,63}|((25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9])\\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[0-9]))))(?:\\:\\d{1,5})?)(\\/(?:(?:[a-zA-Z0-9\\;\\/\?\\:\\@\\&\\=\\#\\~\\-\\.\\+\\!\\*\'\(\\)\\,\\_])|(?:\%[a-fA-F0-9]{2}))*)?" options:NSRegularExpressionUseUnicodeWordBoundaries | NSRegularExpressionDotMatchesLineSeparators error:nil];
    }
    
    NSString *contentString = [string.string copy];
    
    NSArray* chunks = [regex matchesInString:contentString options:0 range:NSMakeRange(0, [contentString length])];
    if (chunks.count < 1) {
        return string;
    }
    
    NSUInteger stringInsertIndex = 0;
    NSRange preRange = {0,0};
    
    NSMutableDictionary* urltextattr = [NSMutableDictionary dictionaryWithDictionary:attibutes];
    for (NSTextCheckingResult *chunk in chunks) {
        
        NSString *text = [contentString substringWithRange:chunk.range];
        
        if (![text hasPrefix:kHttp]) {
            text = _F(@"%@://%@",kHttp,text);
        }
        
        
        urltextattr[kUrl] = text;
        urltextattr[kHttp] = @(1);//这里只是做个标识，区分a和http
        
        if (stringInsertIndex) {
            stringInsertIndex += chunk.range.location - preRange.location  - preRange.length;
        } else {
            stringInsertIndex = chunk.range.location;
        }
        
        if (needParseImage) {
            if (kImageExtensions == nil) {
                kImageExtensions = @[@"png",@"jpg"];
            }
            
            
            if ([kImageExtensions containsObject:[[text pathExtension] lowercaseString]]) {//是图片链接
                
                NSString *md5 = text.MD5;
                
                CTRunDelegateRef runDelegate  = CTRunDelegateCreate(&kRichTextImageCallbacks, (__bridge void *)(md5));
                
                NSMutableAttributedString* imageAttributedString = [[NSMutableAttributedString alloc] initWithString:kPlaceHolderString attributes:urltextattr];
                
                [imageAttributedString addAttribute:(NSString *)kCTRunDelegateAttributeName value:(__bridge id)runDelegate range:NSMakeRange(0, [kPlaceHolderString length])];
                CFRelease(runDelegate);
                [imageAttributedString addAttribute:kImage value:md5 range:NSMakeRange(0, [kPlaceHolderString length])];
                
                
                [string deleteCharactersInRange:NSMakeRange(stringInsertIndex, chunk.range.length)];
                [string insertAttributedString:imageAttributedString atIndex:stringInsertIndex];
                
                
                [[SDImageCache sharedImageCache] diskImageExistsWithKey:md5 completion:^(BOOL isInCache) {
                    
                    if (isInCache) {
                        [[SDWebImageDownloader sharedDownloader] downloadImageWithURL:[NSURL URLWithString:text] options:SDWebImageDownloaderLowPriority progress:nil completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
                            
                            if (finished) {
                                [[SDImageCache sharedImageCache] storeImage:image forKey:md5 toDisk:YES completion:nil];
                            }
                            
                        }];
                        
                    }
                    
                }];
                
                
            }else {
                [string setAttributes:urltextattr range:NSMakeRange(stringInsertIndex, chunk.range.length)];
            }
            
        }else {
            [string setAttributes:urltextattr range:chunk.range];
        }
        
        ++stringInsertIndex;
        
        preRange.location = chunk.range.location;
        preRange.length   = chunk.range.length;
        
    }
    
    return string;
}


NSMutableAttributedString* doRichTextParseLocalImage(NSMutableAttributedString* string,NSArray *imageConfigs)
{
    if ([imageConfigs count] == 0) {
        return string;
    }
    
    
    
    for (RichTextImageConfig *config in imageConfigs) {
        
        if (![config isKindOfClass:[RichTextImageConfig class]]) {
            continue;
        }
        
        NSString *imageName = config.imageName;
        NSUInteger index = config.index;
        
        if (imageName == nil || index > [string.string length]) {
            continue;
        }
        
        
        CTRunDelegateRef runDelegate  = CTRunDelegateCreate(&kRichTextLocalImageCallbacks, (__bridge void *)(imageName));
        
        NSMutableAttributedString* imageAttributedString = [[NSMutableAttributedString alloc] initWithString:kPlaceHolderString];
        [imageAttributedString addAttribute:(NSString *)kCTRunDelegateAttributeName value:(__bridge id)runDelegate range:NSMakeRange(0, [kPlaceHolderString length])];
        CFRelease(runDelegate);
        
        [imageAttributedString addAttribute:@"uuid" value:[[NSUUID UUID] UUIDString] range:NSMakeRange(0, [kPlaceHolderString length])];
        [imageAttributedString addAttribute:kLocalImage value:imageName range:NSMakeRange(0, [kPlaceHolderString length])];
        
        [string insertAttributedString:imageAttributedString atIndex:index];
        
        
    }
    
    
    return string;
}


NSMutableAttributedString* doRichTextParseTopic(NSMutableAttributedString* string,NSDictionary *attibutes)
{
    static  NSRegularExpression* regex = nil;
    if (regex == nil) {
        regex = [[NSRegularExpression alloc] initWithPattern:kTopicRegex options:NSRegularExpressionUseUnicodeWordBoundaries | NSRegularExpressionDotMatchesLineSeparators error:nil];
    }
    
    NSString *contentString = [string.string copy];
    
    NSArray* chunks = [regex matchesInString:contentString options:0 range:NSMakeRange(0, [contentString length])];
    if (chunks.count < 1) {
        return string;
    }
    
    
    NSMutableDictionary* urltextattr = [NSMutableDictionary dictionaryWithDictionary:attibutes];
    
    //    NSUInteger stringInsertIndex = 0;
    //    NSRange preRange = {0,0};
    for (NSTextCheckingResult *chunk in chunks) {
        
        //        NSAttributedString *subString = [string attributedSubstringFromRange:chunk.range];
        //        NSDictionary *attrs = [subString attributesAtIndex:0 effectiveRange:nil];
        //        [urltextattr addEntriesFromDictionary:attrs];
        //        NSString *str= [subString.string trim];
        //
        //        urltextattr[kTopic] = [contentString substringWithRange:chunk.range];
        //
        //        NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:str attributes:urltextattr];
        //
        //
        //        if (stringInsertIndex) {
        //            stringInsertIndex += chunk.range.location - preRange.location  - preRange.length;
        //        } else {
        //            stringInsertIndex = chunk.range.location;
        //        }
        //
        //        [string deleteCharactersInRange:NSMakeRange(stringInsertIndex, chunk.range.length)];
        //        [string insertAttributedString:attrStr atIndex:stringInsertIndex];
        //
        //        ++stringInsertIndex;
        //
        //        preRange.location = chunk.range.location;
        //        preRange.length   = chunk.range.length;
        
        NSAttributedString *subString = [string attributedSubstringFromRange:chunk.range];
        NSString *cpStr = [subString.string copy];
        cpStr = [cpStr stringByReplacingOccurrencesOfString:kTopicSymbol withString:@""];
        
        if (![cpStr containsString:@"\n"] && ![cpStr containsString:@"\r"]) {
            cpStr = cpStr.trim;
            if (cpStr.length > 0) {
                urltextattr[kTopic] = [contentString substringWithRange:chunk.range];
                [string setAttributes:urltextattr range:chunk.range];
            }
        }
        
    }
    
    return string;
}

@end


@implementation RichTextConfig

static RichTextConfig *_instance;
+ (instancetype)defaultConfig {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        _instance = [[self alloc] init];
        
    });
    return _instance;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        [self defaultAttributes];
    }
    return self;
}


- (void) defaultAttributes
{
    
    self.emojiType = RichTextEmojiNormal;
    
    UIFont* textFont = [UIFont systemFontOfSize:kFontSize];
    UIColor* textColor = kTextColor;
    UIColor* linkTextColor = kLinkColor;
    
    CTParagraphStyleSetting lineBreakMode;
    CTLineBreakMode lineBreak      = kCTLineBreakByCharWrapping;
    lineBreakMode.spec             = kCTParagraphStyleSpecifierLineBreakMode;
    lineBreakMode.value            = &lineBreak;
    lineBreakMode.valueSize        = sizeof(lineBreak);
    
    CGFloat lineSpacing = 1.f;
    
    CGFloat _linespaceAdj             = lineSpacing;
    CTParagraphStyleSetting lineSpaceSettingAdj;
    lineSpaceSettingAdj.spec          = kCTParagraphStyleSpecifierLineSpacingAdjustment;
    lineSpaceSettingAdj.value         = &_linespaceAdj;
    lineSpaceSettingAdj.valueSize     = sizeof(CGFloat);
    
    CTParagraphStyleSetting settings[] = {
        lineBreakMode,
        lineSpaceSettingAdj
    };
    
    size_t styleCount = sizeof(settings) / sizeof(CTParagraphStyleSetting);
    
    CTParagraphStyleRef style = CTParagraphStyleCreate(settings, styleCount);
    
    _textAttributes   = @{(__bridge NSString *)kCTFontAttributeName:textFont, NSForegroundColorAttributeName:textColor,(__bridge NSString*)kCTParagraphStyleAttributeName:(__bridge_transfer id)style};
    
    
    _linkedTextAttributes =  @{(__bridge NSString *)kCTFontAttributeName:textFont,
                               NSForegroundColorAttributeName:linkTextColor,
                               (__bridge NSString*)kCTUnderlineStyleAttributeName:@(kCTUnderlineStyleNone),
                               (__bridge NSString*)kCTParagraphStyleAttributeName:(__bridge_transfer id)style};
    
}

@end


@implementation RichTextImageConfig



@end


@implementation NSString (Hash)

- (NSString *) MD5
{
    return NSStringCCHashFunction(CC_MD5, CC_MD5_DIGEST_LENGTH, self);
}

- (NSString *)trim
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}


@end
