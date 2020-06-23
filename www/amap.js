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
AMapPlugin.trastartScheduledPositionceMap = function (successCallback, errorCallback, time) {
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


module.exports = AMapPlugin;