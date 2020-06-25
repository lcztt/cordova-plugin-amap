/*global cordova, module*/
var cordova = require('cordova');
var exec = require('cordova/exec');
var AMapPlugin = function(){};

//获取当前地址
AMapPlugin.getCurrentPosition = function (successCallback, errorCallback) {
    exec(successCallback, errorCallback, "AMapPlugin", "getCurrentPosition", []);
};

//开启持续定位
AMapPlugin.startUpdatePosition = function (successCallback, errorCallback) {
    exec(successCallback, errorCallback, "AMapPlugin", "startUpdatePosition", []);
};

//读取持续定位数据
AMapPlugin.readUpdatePosition = function (successCallback, errorCallback) {
    exec(successCallback, errorCallback, "AMapPlugin", "readUpdatePosition", []);
};

//停止定位
AMapPlugin.stopUpdatePosition = function (successCallback, errorCallback) {
    exec(successCallback, errorCallback, "AMapPlugin", "stopUpdatePosition", []);
};

//展示地图
AMapPlugin.showMap = function (successCallback, errorCallback, coordinates, tips, title) {
    exec(successCallback, errorCallback, "AMapPlugin", "showMap", [coordinates, tips, title]);
};

//关闭展示的地图
AMapPlugin.hideMap = function (successCallback, errorCallback) {
    exec(successCallback, errorCallback, "AMapPlugin", "hideMap", []);
};

//轨迹地图
AMapPlugin.traceMap = function (successCallback, errorCallback, coordinates, title) {
    exec(successCallback, errorCallback, "AMapPlugin", "traceMap", [coordinates, title]);
};

//开启定时定位,参数： time(秒)，定时上报位置时间间隔
AMapPlugin.startScheduledPosition = function (successCallback, errorCallback, time) {
    exec(successCallback, errorCallback, "AMapPlugin", "startScheduledPosition", [{"time":time}]);
};

//关闭定时定位
AMapPlugin.stopScheduledPosition = function () {
    exec(null, null, "AMapPlugin", "stopScheduledPosition", []);
};

// 注册客户端定时定位回调方法
// 回调成功参数：ok=0,errorCode,errorInfo
// 回调失败参数：ok=1,provinceName,cityName,cityCode,districtName,latitude,longitude
AMapPlugin.onScheduledLocationEvent = function (params) {
    cordova.fireDocumentEvent('AMapPlugin.onScheduledLocationEvent', {
        params: params
    })
};

// 开启导航选择，参数如下：
/*
{
    // 苹果导航APP使用的参数
    "start_address":"我的位置",
    "start_lat":"39.1138003159",
    "start_lng":"117.2165143490",
    "end_address":"终点",
    "end_lat":"39.1042806705",
    "end_lng":"117.2229087353",

    // 百度导航
    "baidu":"baidumap://map/direction?origin=34.264642646862,108.95108518068&destination=40.007623,116.360582&coord_type=bd09ll&mode=driving&src=ios.baidu.openAPIdemo",
    // 高德导航
    "gaode":"iosamap://navi?sourceApplication=app_name&lat=36.547901&lon=104.258354&dev=0",
    // 腾讯导航
    "qq":"qqmap://map/routeplan?type=drive&from=清华&fromcoord=39.994745,116.247282&to=怡和世家&tocoord=39.867192,116.493187&referer=OB4BZ-D4W3U-B7VVO-4PJWW-6TKDJ-WPB77"
};
*/
AMapPlugin.openNav = function (params) {
    exec(null, null, "AMapPlugin", "openNav", [params]);
};

// 检查应用是否开启导航权限：
AMapPlugin.checkLocationAuth = function (params) {
    exec(null, null, "AMapPlugin", "checkLocationAuth", [params]);
};

module.exports = AMapPlugin;