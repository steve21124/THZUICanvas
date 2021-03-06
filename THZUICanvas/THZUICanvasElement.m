//
//  THZUICanvasElement.m
//  THZUICanvas
//
//  Created by Thomas Heß on 10.8.13.
//  Copyright (c) 2013 Thomas Heß. All rights reserved.
//

#import "THZUICanvasElement.h"
#import "THZUICanvasElementView.h"
#import "THFloatEqualToFloat.h"

@interface THZUICanvasElement ()

@property (nonatomic, strong) NSMutableOrderedSet* mutableChildElements;
@property (nonatomic, readonly, assign) CGRect childElementsUnionFrame;

@end

@implementation THZUICanvasElement

+ (Class)viewClass
{
    return [THZUICanvasElementView class];
}

+ (instancetype)canvasElementWithDataSource:(id<THZUICanvasElementDataSource>)dataSource
{
    return [[[self class] alloc] initWithDataSource:dataSource];
}

- (id)init
{
    NSAssert(NO, @"use initWithDataSource:");
    return nil;
}

- (instancetype)initWithDataSource:(id<THZUICanvasElementDataSource>)dataSource
{
    NSParameterAssert(dataSource);
    
    self = [super init];
    if (self)
    {
        self.dataSource = dataSource;
        self.frame = (CGRect) {
            .origin = CGPointZero,
            .size = self.dataSource.canvasElementMinSize
        };
        self.rotation = 0;
        self.modifiable = YES;
        self.mutableChildElements = [NSMutableOrderedSet orderedSet];
    }
    return self;
}

#pragma mark - Properties

- (void)setFrame:(CGRect)frame
{
    if (CGRectEqualToRect(self.frame, frame)) return;
    
    frame = (CGRect) {
        .origin = frame.origin,
        .size.width = MAX(self.dataSource.canvasElementMinSize.width, frame.size.width),
        .size.height = MAX(self.dataSource.canvasElementMinSize.width, frame.size.height)
    };
    
    if ([self frameIsWithMinSizeInParentElementBounds:frame]
        && [self frameContainsAllChildElementFrames:frame])
        _frame = frame;
}

- (BOOL)frameIsWithMinSizeInParentElementBounds:(CGRect)frame
{
    if (! self.parentElement) return YES;
    
    CGRect intersection = CGRectIntersection(self.parentElement.bounds, frame);
    return (intersection.size.width >= self.dataSource.canvasElementMinSize.width
            && intersection.size.height >= self.dataSource.canvasElementMinSize.height);
}

- (BOOL)frameContainsAllChildElementFrames:(CGRect)frame
{
    CGRect bounds = (CGRect) { .size = frame.size };
    return CGRectContainsRect(bounds, self.childElementsUnionFrame);
}

- (CGPoint)center
{
    return (CGPoint) { .x = CGRectGetMidX(self.frame), .y = CGRectGetMidY(self.frame) };
}

- (CGRect)bounds
{
    return (CGRect) { .size = self.frame.size };
}

- (void)setRotation:(CGFloat)rotation
{
    // normalize
    while (rotation >= 2 * M_PI) rotation -= 2 * M_PI;
	while (rotation < 0) rotation += 2 * M_PI;
    
    if (THFloatEqualToFloat(self.rotation, rotation)) return;
    
    _rotation = rotation;
}

- (NSOrderedSet*)childElements
{
    return self.mutableChildElements;
}

- (CGRect)childElementsUnionFrame
{
    CGRect unionFrame = CGRectNull;
    for (THZUICanvasElement* childElement in self.childElements)
        unionFrame = CGRectUnion(unionFrame, childElement.frame);
    return unionFrame;
}

#pragma mark - Public Methods

- (void)addChildElement:(THZUICanvasElement*)childElement
{
    NSParameterAssert(childElement);
    
    [self.mutableChildElements addObject:childElement];
    childElement.parentElement = self;
}

- (void)removeChildElement:(THZUICanvasElement*)childElement
{
    NSParameterAssert(childElement && [self.childElements containsObject:childElement]);
    
    [self.mutableChildElements removeObject:childElement];
    childElement.parentElement = nil;
}

- (BOOL)bringChildElementToFront:(THZUICanvasElement*)childElement
{
    NSParameterAssert(childElement && [self.childElements containsObject:childElement]);
    
    return [self moveChildElement:childElement toIndex:[self.childElements count] - 1];
}

- (BOOL)sendChildElementToBack:(THZUICanvasElement*)childElement
{
    NSParameterAssert(childElement && [self.childElements containsObject:childElement]);
    
    return [self moveChildElement:childElement toIndex:0];
}

- (BOOL)moveChildElement:(THZUICanvasElement*)childElement toIndex:(NSUInteger)idx
{
    NSUInteger currentIdx = [self.mutableChildElements indexOfObject:childElement];
    if (currentIdx == idx) return NO;
    
    [self.mutableChildElements moveObjectsAtIndexes:[NSIndexSet indexSetWithIndex:currentIdx]
                                            toIndex:idx];
    return YES;
}

- (BOOL)translate:(CGPoint)translation
{
    if (! self.modifiable) return NO;
    
    CGAffineTransform t = CGAffineTransformMakeRotation(-self.rotation);
    t = CGAffineTransformConcat(t, CGAffineTransformMakeTranslation(translation.x,
                                                                    translation.y));
    t = CGAffineTransformConcat(t, CGAffineTransformMakeRotation(self.rotation));
    CGRect newFrame = CGRectApplyAffineTransform(self.frame, t);
    
    CGRect oldFrame = self.frame;
    self.frame = newFrame;
    
    return (! CGRectEqualToRect(oldFrame, self.frame));
}

- (BOOL)rotate:(CGFloat)rotation
{
    if (isnan(rotation)) return NO;
    
    if (! self.modifiable) return NO;
    
    CGFloat currentRotation = self.rotation;
    self.rotation += rotation;
    
    return ! THFloatEqualToFloat(self.rotation, currentRotation);
}

- (BOOL)scale:(CGFloat)scale
{
    if (isnan(scale)) return NO;
    
    if (! self.modifiable) return NO;
    
    CGSize newSize = CGSizeApplyAffineTransform(self.frame.size,
                                                CGAffineTransformMakeScale(scale, scale));
    
    if (newSize.width < self.dataSource.canvasElementMinSize.width
        || newSize.height < self.dataSource.canvasElementMinSize.height) return NO;

    CGRect newFrame = CGRectInset(self.frame,
                                  (self.frame.size.width - newSize.width) / 2,
                                  (self.frame.size.height - newSize.height) / 2);
    
    CGRect oldFrame = self.frame;
    self.frame = newFrame;
    
    return (! CGRectEqualToRect(oldFrame, self.frame));
}

- (NSString*)description
{
    return NSStringFromCGRect(self.frame);
}

@end
