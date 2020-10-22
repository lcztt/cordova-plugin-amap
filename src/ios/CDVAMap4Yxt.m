
#import "CDVAMap4Yxt.h"
#import <MapKit/MapKit.h>
#import <AMapFoundationKit/AMapFoundationKit.h>
#import <AMapNaviKit/AMapNaviKit.h>
#import <AMapLocationKit/AMapLocationKit.h>
#import <GoogleMaps/GoogleMaps.h>
#import "MAMutablePolylineRenderer.h"
#import "MAMutablePolyline.h"
#import "SBGMapHeaderView.h"

static NSString* const USER_DEFAULT_KEY = @"locations";
static NSString* const LATEST_LOCATION_KEY = @"latest_location";
static NSString* const SPEED_KEY = @"speed";
static NSString* const ACCURACY_KEY = @"accuracy";
static NSString* const LATITUDE_KEY = @"latitude";
static NSString* const LONGITUDE_KEY = @"longitude";
static NSString* const CREATED_AT_KEY = @"timestamp";
static NSString* const IN_BACKGROUND_KEY = @"inBackground";
static NSString* const MAX_LENGTH_KEY = @"maxLength";
static NSString* const INTERVAL_KEY = @"interval";

static int const MAX_LENGTH = 10;

struct Yxtlocation {
    CLLocationDegrees latitude;
    CLLocationDegrees longitude;
    double speed;
    double accuracy;
    long timestamp;
};

@interface CDVAMap4Yxt () <AMapLocationManagerDelegate, MAMapViewDelegate>
{
    BOOL isStart;
    double lat;
    double lng;
    NSMutableArray * _tracking;
    CFTimeInterval _duration;
}

@property (nonatomic, strong) AMapLocationManager *curLocationManager; //获取当前位置

@property (nonatomic, strong) AMapLocationManager *locationManager; //后台持续定位

@property (nonatomic, assign) CGFloat minSpeed;     //最小速度

@property (nonatomic, assign) CGFloat minFilter;    //最小范围

@property (nonatomic, assign) CGFloat minInteval;   //更新间隔

@property (nonatomic, assign) CGFloat distanceFilter;    //最小范围

@property (nonatomic, strong) MAMapView *_mapView; //地图view

@property (nonatomic, strong) NSMutableArray *annotations; //标注

@property (nonatomic, strong) MAMutablePolylineRenderer *render;

@property (nonatomic, strong) MAMutablePolyline *mutablePolyline;

@property (nonatomic, strong) SBGMapHeaderView *headerView;

@property (nonatomic, strong) NSTimer *timer;

@property (nonatomic, strong) NSDictionary *codeForCountryDictionary;

@property (nonatomic, assign) BOOL useGoogle;

@end


@implementation CDVAMap4Yxt

- (void)pluginInitialize
{
    NSArray *countryCodes = [NSLocale ISOCountryCodes];
    NSMutableArray *countries = [NSMutableArray arrayWithCapacity:[countryCodes count]];
    NSString *currentLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
    
    for (NSString *countryCode in countryCodes)
    {
        NSString *identifier = [NSLocale localeIdentifierFromComponents: [NSDictionary dictionaryWithObject: countryCode forKey: NSLocaleCountryCode]];
        NSString *country = [[[NSLocale alloc] initWithLocaleIdentifier:currentLanguage] displayNameForKey: NSLocaleIdentifier value: identifier];
        [countries addObject: country];
    }
    
    self.codeForCountryDictionary = [[NSDictionary alloc] initWithObjects:countryCodes forKeys:countries];
    [self initLocationConfig];
}

//readValueFrom mainBundle
- (NSString *)getAMapApiKey
{
    NSString *APIKey = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"AMapApiKey"];
    if (APIKey == nil) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"API key error"
                                                                       message:@"高德地图 api key 为空"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* ok = [UIAlertAction actionWithTitle:@"close"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction* action)
                             {
            [alert dismissViewControllerAnimated:YES completion:nil];
        }];
        
        [alert addAction:ok];
        
        [self.viewController presentViewController:alert
                                          animated:YES
                                        completion:nil];
        return @"";
    }
    
    return APIKey;
}

//readValueFrom mainBundle
- (NSString *)getGoogleMapApiKey
{
    NSString *APIKey = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"GoogleMapApiKey"];
    if (APIKey == nil) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"API key error"
                                                                       message:@"谷歌地图 api key 为空"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* ok = [UIAlertAction actionWithTitle:@"close"
                                                     style:UIAlertActionStyleDefault
                                                   handler:^(UIAlertAction* action)
                             {
            [alert dismissViewControllerAnimated:YES completion:nil];
        }];
        
        [alert addAction:ok];
        
        [self.viewController presentViewController:alert
                                          animated:YES
                                        completion:nil];
        APIKey = @"AIzaSyBR0cf0DMkR67gm7e2WMzhGbOLsAAU5_fo";
        return APIKey;
    }
    
    return APIKey;
}

- (void)initLocationConfig
{
    [AMapServices sharedServices].apiKey = [self getAMapApiKey];
    [GMSServices provideAPIKey:[self getGoogleMapApiKey]];
}

#pragma mark - location -

//获取当前位置
- (void)getCurrentPosition:(CDVInvokedUrlCommand *)command
{
    NSDictionary *params = [command.arguments firstObject];
    BOOL useGoogle = false;
    if (params && params[@"useGoogle"]) {
        useGoogle = [params[@"useGoogle"] boolValue];
    }
    
    if (!self.curLocationManager) {
        self.curLocationManager = [[AMapLocationManager alloc] init];
        self.curLocationManager.delegate = self;
        [self.curLocationManager setDesiredAccuracy:kCLLocationAccuracyNearestTenMeters];
    }
    
    [self.commandDelegate runInBackground:^{
        [self.curLocationManager requestLocationWithReGeocode:YES completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
            CDVPluginResult* pluginResult = nil;
            if (regeocode) {
                NSDictionary *dict = @{@"provinceName":regeocode.province,
                                       @"cityName":regeocode.city,
                                       @"cityCode":regeocode.citycode,
                                       @"districtName":regeocode.district,
                                       @"latitude":@(location.coordinate.latitude),
                                       @"longitude":@(location.coordinate.longitude)};
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
                
            } else if (location) {
                
                if (useGoogle) {
                    [self googleReverseGeocoderLocationWith:location completion:^(NSDictionary *dict) {
                        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
                        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                    }];
                } else {
                    [self iOSReverseGeocoderLocationWith:location completion:^(NSDictionary *dict) {
                        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
                        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
                    }];
                }
                
                return;
            } else if (error) {
                
                NSString *errorCode = [NSString stringWithFormat: @"%ld", (long)error.code];
                NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                      errorCode,@"errorCode",
                                      error.localizedDescription,@"errorInfo",
                                      nil];
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dict];
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    }];
}

// 根据经纬度反向地理编译出地址信息
- (void)iOSReverseGeocoderLocationWith:(CLLocation *)location completion:(void(^)(NSDictionary *))completion
{
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *array, NSError *error) {

        if (array.count > 0) {
            CLPlacemark *placemark = [array objectAtIndex:0];
            NSLog(@"%@>%@>%@>%@",placemark.ISOcountryCode,placemark.country,placemark.administrativeArea, placemark.locality);

            NSDictionary *params = @{
                @"latitude":@(location.coordinate.latitude),
                @"longitude":@(location.coordinate.longitude),
                @"countryCode":placemark.ISOcountryCode ?: @"",
                @"country":placemark.country ?: @"",
                @"prov": placemark.administrativeArea ?: @"",
                @"city":placemark.locality ?: @"",
                @"address": placemark.thoroughfare ?: @"",
                @"area": placemark.subLocality ?: @"",
                @"feature": placemark.thoroughfare ?: @"",
            };
            NSLog(@"%@", params);
            if (completion) {
                completion(params);
            }
        } else {
            NSDictionary *dict = @{@"latitude":@(location.coordinate.latitude),
                                   @"longitude":@(location.coordinate.longitude)};
            if (completion) {
                completion(dict);
            }
        }
    }];
}

// 根据经纬度反向地理编译出地址信息
- (void)googleReverseGeocoderLocationWith:(CLLocation *)location completion:(void(^)(NSDictionary *))completion
{
    GMSGeocoder *reverseGeocoder = [GMSGeocoder geocoder];
    [reverseGeocoder reverseGeocodeCoordinate:location.coordinate completionHandler:^(GMSReverseGeocodeResponse *response, NSError *error) {
        
        if (response.firstResult) {
            
            GMSAddress *address = response.firstResult;
            
            NSMutableDictionary *result = [NSMutableDictionary dictionary];
            [result setObject:[NSNumber numberWithDouble:location.coordinate.latitude] forKey:@"latitude"];
            [result setObject:[NSNumber numberWithDouble:location.coordinate.longitude] forKey:@"longitude"];
            
            [result setObject:address.country ?: @"" forKey:@"country"];
            NSString *countryCode = [self.codeForCountryDictionary objectForKey:address.country];
            [result setObject:countryCode ?: @"" forKey:@"countryCode"];
            
            [result setObject:address.administrativeArea ?: @"" forKey:@"prov"];
            [result setObject:address.locality ?: @"" forKey:@"city"];
            
            [result setObject:@"" forKey:@"address"];
            [result setObject:address.subLocality ?: @"" forKey:@"area"];
            [result setObject:[address.lines firstObject] ?: @"" forKey:@"feature"];
            if (completion) {
                completion(result);
            }
        } else {
            
            NSDictionary *dict = @{@"latitude":@(location.coordinate.latitude),
                                   @"longitude":@(location.coordinate.longitude)};
            if (completion) {
                completion(dict);
            }
        }
    }];
}

//开始后台持续定位
- (void)startUpdatePosition:(CDVInvokedUrlCommand *)command
{
    self.minSpeed   = 2;
    self.minFilter  = 50;
    self.minInteval = 10;
    self.distanceFilter = self.minFilter;
    
    if (![self locationServicesEnabled]) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"请开启手机的GPS定位功能"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    if (self.locationManager) {
        self.locationManager = nil;
    }
    
    [self clearLocations];
    
    self.locationManager = [[AMapLocationManager alloc]init];
    self.locationManager.delegate = self;
    //一次还不错的定位，偏差在100米以内，耗时在3s左右 kCLLocationAccuracyHundredMeters];
    //精度很高的一次定位，偏差在10米以内，耗时在10s左右 kCLLocationAccuracyBest];
    [self.locationManager setDesiredAccuracy:kCLLocationAccuracyNearestTenMeters];
    
    //定位超时时间，最低2s，此处设置为11s
    //self.locationManager.locationTimeout =11;
    //逆地理请求超时时间，最低2s，此处设置为12s
    //self.locationManager.reGeocodeTimeout = 12;
    //设置允许后台定位参数，保持不会被系统挂起
    [self.locationManager setPausesLocationUpdatesAutomatically:NO];
    [self.locationManager setAllowsBackgroundLocationUpdates:YES];//iOS9(含)以上系统需设置
    isStart = YES;
    
    self.locationManager.distanceFilter = self.distanceFilter;
    [self.locationManager startUpdatingLocation];
}

//读取持续定位数据
- (void)readUpdatePosition:(CDVInvokedUrlCommand *)command
{
    NSArray* array = [self getLocations];
    NSLog(@"get array in read: %@", array);
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:array];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    [self clearLocations];
}

//停止后台持续定位
- (void)stopUpdatePosition:(CDVInvokedUrlCommand *)command
{
    if (self.locationManager) {
        [self.locationManager stopUpdatingLocation];
    }
    isStart = NO;
}

#pragma mark - delegate -

- (void)amapLocationManager:(AMapLocationManager *)manager didUpdateLocation:(CLLocation *)location
{
    [self adjustDistanceFilter:location];
    
    if (location.horizontalAccuracy < 200 && isStart) {
        if (lat!=location.coordinate.latitude && lng!=location.coordinate.longitude) {
            //            NSLog(@"put into:{lat:%e; lon:%e; accuracy:%e; speed:%e}", location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy, location.speed);
            //            NSTimeZone* sourceTimeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
            //            NSInteger interval = [sourceTimeZone secondsFromGMTForDate:location.timestamp];
            //            NSLog(@"interval: %ld", (long)interval);
            
            //            NSDate *localeDate = [location.timestamp  dateByAddingTimeInterval: interval];
            //            NSLog(@"localeDate: %@", localeDate);
            
            NSString *timeSp = [NSString stringWithFormat:@"%ld", (long)[location.timestamp timeIntervalSince1970]];
            if (location.speed <= 0 && lat>0) {
                CLLocation *before=[[CLLocation alloc] initWithLatitude:lat longitude:lng];
                CLLocation *current=[[CLLocation alloc] initWithLatitude:location.coordinate.latitude longitude:location.coordinate.longitude];
                CLLocationDistance meters=[current distanceFromLocation:before];
                
                if (meters < 10) {
                    NSLog(@"before location: %f,%f, distance:%f", lat, lng, meters);
                    return;
                }
            }
            lat = location.coordinate.latitude;
            lng = location.coordinate.longitude;
            
            struct Yxtlocation loc = {location.coordinate.latitude, location.coordinate.longitude, location.speed,location.horizontalAccuracy,(long)timeSp};
            [self putLocation:loc];
        }
    }
}

- (void)amapLocationManager:(AMapLocationManager *)manager doRequireLocationAuth:(CLLocationManager *)locationManager
{
    [locationManager requestAlwaysAuthorization];
}

#pragma mark - util -

//判断是否开启了GPS
- (Boolean) locationServicesEnabled {
    if (([CLLocationManager locationServicesEnabled]) && ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways)) {
        NSLog(@"手机gps定位已经开启");
        return true;
    } else {
        NSLog(@"手机gps定位未开启");
        return false;
    }
}

/**
 *  规则: 如果速度小于minSpeed m/s 则把触发范围设定为minFilter m
 *  否则将触发范围设定为minSpeed*minInteval
 *  此时若速度变化超过10% 则更新当前的触发范围(这里限制是因为不能不停的设置distanceFilter,
 *  否则uploadLocation会不停被触发)
 */
- (void)adjustDistanceFilter:(CLLocation*)location
{
    if ( location.speed < self.minSpeed ) {
        if ( fabs(self.distanceFilter-self.minFilter) > 0.1f ) {
            self.distanceFilter = self.minFilter;
            self.locationManager.distanceFilter = self.distanceFilter;
        }
    } else {
        CGFloat lastSpeed = self.distanceFilter/self.minInteval;
        
        if ( (fabs(lastSpeed-location.speed)/lastSpeed > 0.1f) || (lastSpeed < 0) ) {
            CGFloat newSpeed  = (int)(location.speed+0.5f);
            CGFloat newFilter = newSpeed*self.minInteval;
            
            self.distanceFilter = newFilter;
            self.locationManager.distanceFilter = self.distanceFilter;
        }
    }
}

- (NSMutableArray *)getLocations {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray* array = [userDefaults objectForKey:USER_DEFAULT_KEY];
    NSMutableArray* mutableArray = nil;
    if(array != nil){
        mutableArray = [NSMutableArray arrayWithArray:array];
    }else{
        mutableArray = [[NSMutableArray alloc] init];
    }
    return mutableArray;
}

- (void)setLocations:(NSMutableArray*)locations
{
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray *array = [NSArray arrayWithArray:locations];
    [userDefaults setObject:array forKey:USER_DEFAULT_KEY];
}

- (NSString *)dictionaryToJson:(NSDictionary*)dictionary
{
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc] initWithBytes:[jsonData bytes] length:[jsonData length] encoding:NSUTF8StringEncoding];
}

//暂存持续定位数据
- (void)putLocation:(struct Yxtlocation) location
{
    //is in background
    UIApplicationState appState = UIApplicationStateActive;
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(applicationState)]) {
        appState = [UIApplication sharedApplication].applicationState;
    }
    BOOL inBackground = appState != UIApplicationStateActive;
    
    NSMutableArray* locations = [self getLocations];
    NSDictionary* dictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:inBackground], IN_BACKGROUND_KEY, location.timestamp, CREATED_AT_KEY, [NSNumber numberWithDouble: location.latitude], LATITUDE_KEY, [NSNumber numberWithDouble: location.longitude],LONGITUDE_KEY, [NSNumber numberWithDouble: location.speed],SPEED_KEY,[NSNumber numberWithDouble: location.accuracy],ACCURACY_KEY,nil];
    //    NSLog(@"dictionary %@", dictionary);
    [locations addObject:[self dictionaryToJson:dictionary]];
    if([locations count] > MAX_LENGTH){
        [locations removeObjectAtIndex:0];
    }
    [self setLocations:locations];
}

- (void)clearLocations
{
    NSUserDefaults* userDefault = [NSUserDefaults standardUserDefaults];
    [userDefault removeObjectForKey: USER_DEFAULT_KEY];
}

#pragma mark - navigation -

//init map Config
//- (void)initMapConfig
//{
//    [AMapServices sharedServices].apiKey = [self getAMapApiKey];
//}
//
////初始化地图
//- (void)initMapView
//{
//    if (self._mapView) {
//        self._mapView = nil;
//    }
//    self.headerView = [[SBGMapHeaderView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.webView.bounds), 64)];
//    self.headerView.title = @"定位";
//
//    __weak CDVAMap4Yxt *weakSelf = self;
//    [self.headerView setBackCallBack:^{
//        [weakSelf hideMap:nil];
//    }];
//    self.headerView.backgroundColor = [UIColor colorWithRed:87/255.0 green:142/255.0 blue:220/255.0 alpha:1];
//    [self.webView addSubview:self.headerView];
//    self._mapView = [[MAMapView alloc] initWithFrame:CGRectMake(0, 64, CGRectGetWidth(self.webView.bounds), CGRectGetHeight(self.webView.bounds))];
//    self._mapView.delegate = self;
//    self._mapView.showsUserLocation = YES;
//    self._mapView.distanceFilter = 10;
//    self._mapView.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
//    self._mapView.pausesLocationUpdatesAutomatically = NO;
//
//    [self._mapView setUserTrackingMode: MAUserTrackingModeFollow animated:YES];
//
//    [self.webView addSubview:self._mapView];
//
//    UIButton *locationBtn = [UIButton buttonWithType:UIButtonTypeCustom];
//    [self._mapView addSubview:locationBtn];
//    locationBtn.backgroundColor = [UIColor whiteColor];
//    [locationBtn addTarget:self action:@selector(scrollCenter:) forControlEvents:UIControlEventTouchUpInside];
//    locationBtn.frame = CGRectMake(20, CGRectGetHeight(self._mapView.frame) - 128, 27.5, 27.5);
//    //    NSString * path = [[[NSBundle mainBundle] pathForResource:@"AMap" ofType:@"bundle"] stringByAppendingPathComponent:@"images/locationIcon.png"];
//    UIImage *img = [UIImage imageNamed:@"locationIcon"];
//    [locationBtn setImage:img forState:UIControlStateNormal];
//}
//
//- (void)initOverlay
//{
//    self.mutablePolyline = [[MAMutablePolyline alloc] initWithPoints:@[]];
//}
//
////展示地图
//- (void)showMap:(CDVInvokedUrlCommand *)command
//{
//    [self initMapConfig];
//    [self initMapView];
//
//    self.headerView.title = command.arguments[2];
//    NSString* coordinates = [command.arguments objectAtIndex:0];
//    NSString* tips        = [command.arguments objectAtIndex:1];
//
//    if (coordinates.length && tips.length) {
//        [self setAnnotations:coordinates andTips:tips];
//    }
//}
//
////关闭地图
//- (void) hideMap:(CDVInvokedUrlCommand *)command
//{
//    if (self._mapView != nil) {
//        [self._mapView removeFromSuperview];
//        NSLog(@"remove From Superview");
//    }
//    if (self.headerView != nil) {
//        [self.headerView removeFromSuperview];
//    }
//    NSString* okStr = @"ok";
//
//    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:okStr];
//    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
//}
//
////我的轨迹
//- (void)traceMap:(CDVInvokedUrlCommand *)command
//{
//    [self initMapConfig];
//    [self initMapView];
//    [self initOverlay];
//
//    NSString* coordinates = [command.arguments objectAtIndex:0];
//
//    if (coordinates.length) {
//        [self initRouter:coordinates];
//    }
//
//    [self._mapView addOverlay:self.mutablePolyline];
//}
//
//#pragma mark - delegate - MAMapViewDelegate -
//
//- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
//{
//    if ([annotation isKindOfClass:[MAPointAnnotation class]])
//    {
//        static NSString *pointReuseIndetifier = @"pointReuseIndetifier";
//        MAPinAnnotationView *annotationView = (MAPinAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndetifier];
//        if (annotationView == nil)
//        {
//            annotationView = [[MAPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIndetifier];
//        }
//
//        annotationView.canShowCallout               = YES;
//        annotationView.animatesDrop                 = YES;
//        annotationView.draggable                    = YES;
//        annotationView.rightCalloutAccessoryView    = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
//        annotationView.pinColor                     = [self.annotations indexOfObject:annotation] % 3;
//
//        return annotationView;
//    }
//
//    return nil;
//}
//
//- (MAOverlayPathRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id<MAOverlay>)overlay
//{
//
//    if ([overlay isKindOfClass:[MAMutablePolyline class]])
//    {
//        MAMutablePolylineRenderer *renderer = [[MAMutablePolylineRenderer alloc] initWithOverlay:overlay];
//        renderer.lineWidth = 4.0f;
//
//        renderer.strokeColor = [UIColor redColor];
//        self.render = renderer;
//
//        return renderer;
//    }
//
//    return nil;
//}
//
//- (void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation
//{
//    if (!updatingLocation)
//    {
//        return;
//    }
//
//    if (userLocation.location.horizontalAccuracy < 80 && userLocation.location.horizontalAccuracy > 0)
//    {
//
//        [self.mutablePolyline appendPoint: MAMapPointForCoordinate(userLocation.location.coordinate)];
//
//        [self._mapView setCenterCoordinate:userLocation.location.coordinate animated:YES];
//
//        //        [self.render invalidatePath];
//    }
//    //    [self.statusView showStatusWith:userLocation.location];
//}
//
//- (void)mapView:(MAMapView *)mapView  didChangeUserTrackingMode:(MAUserTrackingMode)mode animated:(BOOL)animated
//{
//    if (mode == MAUserTrackingModeNone)
//    {
//        // [self.locationBtn setImage:self.imageNotLocate forState:UIControlStateNormal];
//    }
//    else
//    {
//        // [self.locationBtn setImage:self.imageLocated forState:UIControlStateNormal];
//        [self._mapView setZoomLevel:16 animated:YES];
//    }
//}
//
//#pragma mark - util -
//
//- (void)setAnnotations:(NSString *)coordinates andTips: (NSString *)tips
//{
//    self.annotations = [NSMutableArray array];
//
//    NSArray *coordinateslistItems = [coordinates componentsSeparatedByString:@";"];
//    NSArray *tipsItems = [tips componentsSeparatedByString:@","];
//
//    long len =[coordinateslistItems count];
//    for(int i=0; i < len; i++) {
//        NSString* item = [coordinateslistItems objectAtIndex:i];
//        NSArray * tmp = [item componentsSeparatedByString:@","];
//
//        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([[tmp objectAtIndex:0] doubleValue], [[tmp objectAtIndex:1] doubleValue]);
//
//        MAPointAnnotation *a1 = [[MAPointAnnotation alloc] init];
//        a1.coordinate = coord;
//        a1.title      = [NSString stringWithFormat:@"%@", [tipsItems objectAtIndex:i]];
//        [self.annotations addObject:a1];
//    }
//
//    [self._mapView addAnnotations:self.annotations];
//    [self._mapView showAnnotations:self.annotations edgePadding:UIEdgeInsetsMake(20, 20, 20, 80) animated:YES];
//}
//
//- (void)initRouter:(NSString *)coordinates
//{
//
//    NSArray *coordinateslistItems = [coordinates componentsSeparatedByString:@";"];
//    long len =[coordinateslistItems count];
//    for(int i=0; i < len; i++) {
//        NSString* item = [coordinateslistItems objectAtIndex:i];
//        NSArray * tmp = [item componentsSeparatedByString:@","];
//
//        CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([[tmp objectAtIndex:0] doubleValue], [[tmp objectAtIndex:1] doubleValue]);
//        if (i == 0) {
//            MAPointAnnotation *a1 = [[MAPointAnnotation alloc] init];
//            a1.coordinate = coord;
//            a1.title      = [NSString stringWithFormat:@"%@", @"开始位置"];
//            [self._mapView addAnnotation:a1];
//        }
//
//        [self.mutablePolyline appendPoint:MAMapPointForCoordinate(coord)];
//    }
//}
//
//- (void)scrollCenter:(id)sender
//{
//    [self._mapView setCenterCoordinate:self._mapView.userLocation.location.coordinate animated:YES];
//}

#pragma mark - time handler -

- (void)startScheduledPosition:(CDVInvokedUrlCommand *)command
{
    if (![self locationServicesEnabled]) {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"请开启手机的GPS定位功能"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    if (!command.arguments.count) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"请添加定时时间间隔"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }
    
    NSDictionary *params = command.arguments[0];
    NSInteger time = [params[@"time"] integerValue];
    self.useGoogle = [params[@"useGoogle"] boolValue];
    
    [self stopTimer];
    [self startTimerWithInterval:time];
}

- (void)stopScheduledPosition:(CDVInvokedUrlCommand *)command
{
    [self stopTimer];
}

- (void)startTimerWithInterval:(NSInteger)interval
{
    if (!self.timer) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)interval target:self selector:@selector(timerHandler) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
        [self.timer setFireDate:[NSDate distantPast]];
    }
}

- (void)stopTimer
{
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)timerHandler
{
    if (!self.curLocationManager) {
        self.curLocationManager = [[AMapLocationManager alloc] init];
        self.curLocationManager.delegate = self;
        [self.curLocationManager setDesiredAccuracy:kCLLocationAccuracyNearestTenMeters];
    }
    
    [self.commandDelegate runInBackground:^{
        [self.curLocationManager requestLocationWithReGeocode:NO completionBlock:^(CLLocation *location, AMapLocationReGeocode *regeocode, NSError *error) {
            NSDictionary *dict = nil;
            if (regeocode) {
                dict = @{@"ok":@1,
                         @"provinceName":regeocode.province,
                         @"cityName":regeocode.city,
                         @"cityCode":regeocode.citycode,
                         @"districtName":regeocode.district,
                         @"latitude":@(location.coordinate.latitude),
                         @"longitude":@(location.coordinate.longitude)};
                
            } else if (location) {
                
                NSDictionary *dict = [self getLastLocation];
                NSDictionary *new_dict = @{@"latitude":@(location.coordinate.latitude),
                                           @"longitude":@(location.coordinate.longitude)};
                [self setLastLocation:new_dict];
                
                if (dict.count == 2) {
                    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake([dict[@"latitude"] doubleValue], [dict[@"longitude"] doubleValue]);
                    double distance = [self distanceFromLocation:coord toLocation:location.coordinate];
                    if (distance < 1000) {
                        return;
                    }
                }
                
                if (self.useGoogle) {
                    [self googleReverseGeocoderLocationWith:location completion:^(NSDictionary *dict) {
                        NSMutableDictionary *dictM = [NSMutableDictionary dictionaryWithDictionary:dict];
                        dictM[@"ok"] = @1;
                        [self callbackJSWithParams:dictM];
                    }];
                } else {
                    [self iOSReverseGeocoderLocationWith:location completion:^(NSDictionary *dict) {
                        NSMutableDictionary *dictM = [NSMutableDictionary dictionaryWithDictionary:dict];
                        dictM[@"ok"] = @1;
                        [self callbackJSWithParams:dictM];
                    }];
                }
                
                return;
                
            } else if (error) {
                
                NSString *errorCode = [NSString stringWithFormat: @"%ld", (long)error.code];
                dict = @{@"ok": @0,
                         @"errorCode": errorCode,
                         @"errorInfo": error.localizedDescription};
            }
            [self callbackJSWithParams:dict];
        }];
    }];
}

- (void)callbackJSWithParams:(NSDictionary *)params
{
    NSString *paramStr = [self jsonStringEncodedWith:params];
    NSString *jsStr = [NSString stringWithFormat:@"window.AMapPlugin.onScheduledLocationEvent(%@)", paramStr];
    [self.commandDelegate evalJs:jsStr];
}

- (NSString *)jsonStringEncodedWith:(NSDictionary *)params
{
    if ([NSJSONSerialization isValidJSONObject:params]) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:params options:0 error:&error];
        NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return json;
    }
    return @"";
}

- (void)onReset
{
    [self stopTimer];
}

- (double)distanceFromLocation:(CLLocationCoordinate2D)aCoordinate toLocation:(CLLocationCoordinate2D)bCoordinate
{
    CLLocation *_aLocation = [[CLLocation alloc] initWithLatitude:aCoordinate.latitude
                                                        longitude:aCoordinate.longitude];
    CLLocation *_bLocation = [[CLLocation alloc] initWithLatitude:bCoordinate.latitude
                                                        longitude:bCoordinate.longitude];
    CLLocationDistance distance = [_aLocation distanceFromLocation:_bLocation];
    return (double)distance;
}

- (NSDictionary *)getLastLocation
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *dict = [userDefaults objectForKey:LATEST_LOCATION_KEY];
    if(dict == nil){
        dict = [NSDictionary dictionary];
    }
    return dict;
}

- (void)setLastLocation:(NSDictionary *)location
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:location forKey:LATEST_LOCATION_KEY];
    [userDefaults synchronize];
}

#pragma mark -

- (void)checkLocationAuth:(CDVInvokedUrlCommand *)command
{
    if (([CLLocationManager locationServicesEnabled]) && ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways ||
                                                          [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedWhenInUse)) {
        NSLog(@"手机gps定位已经开启");
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        NSLog(@"手机gps定位未开启");
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

#pragma mark - navigation -

- (void)openNav:(CDVInvokedUrlCommand *)command
{
    
    if (!command.arguments.count) {
        return;
    }
    NSDictionary *params = command.arguments[0];
    //
    //    NSDictionary *params = @{@"start_address":@"我的位置",
    //                             @"start_lat":@"39.1138003159",
    //                             @"start_lng":@"117.2165143490",
    //                             @"end_address":@"终点",
    //                             @"end_lat":@"39.1042806705",
    //                             @"end_lng":@"117.2229087353",
    //
    //                             @"baidu":@"baidumap://map/direction?origin=34.264642646862,108.95108518068&destination=40.007623,116.360582&coord_type=bd09ll&mode=driving&src=ios.baidu.openAPIdemo",
    //                             @"gaode":@"iosamap://navi?sourceApplication=app_name&lat=36.547901&lon=104.258354&dev=0",
    //                             @"qq":@"qqmap://map/routeplan?type=drive&from=清华&fromcoord=39.994745,116.247282&to=怡和世家&tocoord=39.867192,116.493187&referer=OB4BZ-D4W3U-B7VVO-4PJWW-6TKDJ-WPB77"};
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"导航" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"baidumap://"]]) {
        
        [alert addAction:[UIAlertAction actionWithTitle:@"百度地图" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self baiduMap:params];
        }]];
    }
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"qqmap://"]]) {
        
        [alert addAction:[UIAlertAction actionWithTitle:@"腾讯地图" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self tencentMap:params];
        }]];
    }
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"iosamap://"]]) {
        
        [alert addAction:[UIAlertAction actionWithTitle:@"高德地图" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self gaodeMap:params];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"手机地图" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self iphoneMap:params];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    
    [self.viewController presentViewController:alert animated:YES completion:^{}];
}

//手机地图
- (void)iphoneMap:(NSDictionary *)dic
{
    //起点
    CLLocationCoordinate2D from = CLLocationCoordinate2DMake([dic[@"start_lat"] doubleValue], [dic[@"start_lng"] doubleValue]);
    MKMapItem *currentLocation = [[MKMapItem alloc] initWithPlacemark:[[MKPlacemark alloc] initWithCoordinate:from addressDictionary:nil]];
    currentLocation.name = dic[@"start_address"];
    
    //终点
    CLLocationCoordinate2D to =CLLocationCoordinate2DMake([dic[@"end_lat"] doubleValue], [dic[@"end_lng"] doubleValue]);
    MKMapItem *toLocation = [[MKMapItem alloc] initWithPlacemark:[[MKPlacemark alloc] initWithCoordinate:to addressDictionary:nil]];
    toLocation.name = dic[@"end_address"];
    
    NSArray *items = [NSArray arrayWithObjects:currentLocation, toLocation,nil];
    NSDictionary *options = @{ MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving,
                               MKLaunchOptionsMapTypeKey : [NSNumber numberWithInteger:MKMapTypeStandard],
                               MKLaunchOptionsShowsTrafficKey : @YES};
    
    //打开苹果自身地图应用
    [MKMapItem openMapsWithItems:items launchOptions:options];
}

#pragma mark - 以下url地址所传参数含义具体看文档说明

// 百度地图 文档地址：http://lbsyun.baidu.com/index.php?title=uri/api/ios
// 例子：[NSString stringWithFormat:@"baidumap://map/direction?
// origin=%@&destination=latlng:%@,%@|name:%@&mode=driving&coord_type=gcj02&src=ios.vitas.chatapp",
// dic[@"start_address"], dic[@"end_lat"], dic[@"end_lng"], dic[@"end_address"]]
- (void)baiduMap:(NSDictionary *)dic
{
    NSString *urlString = dic[@"baidu"];
    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:urlString];
    
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        NSLog(@"scheme调用结束");
    }];
}

// 腾讯地图 文档地址：https://lbs.qq.com/webApi/uriV1/uriGuide/uriMobileRoute
// 例子：[NSString stringWithFormat:@"qqmap://map/routeplan?type=drive&from=%@&fromcoord=%@,%@&to=%@&tocoord=%@,%@&referer=%@",
// dic[@"start_address"], dic[@"start_lat"], dic[@"start_lng"], dic[@"end_address"], dic[@"end_lat"], dic[@"end_lng"], dic[@"qq_key"]]
- (void)tencentMap:(NSDictionary *)dic
{
    NSString *urlString = dic[@"qq"];
    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:urlString];
    
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        NSLog(@"scheme调用结束");
    }];
}

// 高德地图 文档地址：https://lbs.amap.com/api/amap-mobile/guide/ios/navi
// 例子：[NSString stringWithFormat:@"iosamap://navi?sourceApplication=%@&lat=%@&lon=%@&dev=0",dic[@"app_name"],dic[@"end_lat"], dic[@"end_lng"]]
- (void)gaodeMap:(NSDictionary *)dic
{
    NSString *urlString = dic[@"gaode"];
    urlString = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:urlString];
    
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        NSLog(@"scheme调用结束");
    }];
}

@end
