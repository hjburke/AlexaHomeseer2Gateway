/**
 * API to control HomeSeer 2 home automation controller.
 *
 * This is intended to be run as an AWS Lambda function.
 *
 * Copyright 2016 hburke
 */

'use strict';

var username=process.env.username;
var password=process.env.password;
var hsserver=process.env.hsserver;
var hsport  =process.env.hsport;

var auth = 'Basic ' + new Buffer(username + ':' + password).toString('base64');

var http = require('http');

console.log('Loading function');

/**
 * Demonstrates a simple HTTP endpoint using API Gateway. You have full
 * access to the request and response payload, including headers and
 * status code.
 */
exports.handler = (event, context, callback) => {
    console.log('Received event:', JSON.stringify(event, null, 2));

    const done = (err, res) => callback(null, {
        statusCode: err ? '400' : '200',
        body: err ? err.message : JSON.stringify(res),
        headers: {
            'Content-Type': 'application/json',
        },
    });

    switch (event.httpMethod) {
        case 'GET':
            handleControl(event,done);
            break;
        default:
            done(new Error(`Unsupported method "${event.httpMethod}"`));
    }
};

/**
 * Control events are processed here.
 * This is called when Alexa requests an action (IE turn off appliance).
 */
function handleControl(event, callback) {

    if (event.queryStringParameters.namespace !== 'Alexa.ConnectedHome.Control' || 
            !(event.queryStringParameters.name == 'TurnOnRequest' ||
              event.queryStringParameters.name == 'TurnOffRequest' || 
              event.queryStringParameters.name == 'SetPercentageRequest' ||
              event.queryStringParameters.name == 'IncrementPercentageRequest' ||
              event.queryStringParameters.name == 'DecrementPercentageRequest'
              ) ) {
        console.log('Bad namespace or name:',event);
        callback(new Error('Unsupported Operation'));
        return;
    }

    var applianceId = event.queryStringParameters.applianceId;

    if (typeof applianceId !== "string" ) {
        console.log('Event payload is invalid:',event);
        callback(new Error('Unexpected Information Recieved'));
        return;
    }
    
    var deviceValue = event.queryStringParameters.value;
    
    if ((event.queryStringParameters.name == 'SetPercentageRequest' ||
              event.queryStringParameters.name == 'IncrementPercentageRequest' ||
              event.queryStringParameters.name == 'DecrementPercentageRequest') &&
              typeof deviceValue !== "string") {
        console.log('Value required for action:',event);
        callback(new Error('Value required for action'));
        return;
    }

    switch (event.queryStringParameters.name) {
        case 'TurnOnRequest':
            controlHSDevice(applianceId,'deviceon',100,function(response){
                if (response.error) {
                    callback(new Error('Target Hardware Malfunction'));
                } else {
                    callback();
                }
            });
            break;
        case 'TurnOffRequest':
            controlHSDevice(applianceId,'deviceoff',0,function(response){
                if (response.error) {
                    callback(new Error('Target Hardware Malfunction'));
                } else {
                    callback();
                }
            });
            break;
        case 'SetPercentageRequest':
            controlHSDevice(applianceId,'setdevicevalue',event.queryStringParameters.value,function(response){
                if (response.error) {
                    callback(new Error('Target Hardware Malfunction'));
                } else {
                    callback();
                }
            });
            break;
        case 'IncrementPercentageRequest':
            controlHSDevice(applianceId,'changedevicevalue',event.queryStringParameters.value,function(response){
                if (response.error) {
                    callback(new Error('Target Hardware Malfunction'));
                } else {
                    callback();
                }
            });
            break;
        case 'DecrementPercentageRequest':
            controlHSDevice(applianceId,'changedevicevalue',-event.queryStringParameters.value,function(response){
                if (response.error) {
                    callback(new Error('Target Hardware Malfunction'));
                } else {
                    callback();
                }
            });
            break;
        default:
            console.log('Err', 'No supported action: ' + event.queryStringParameters.name);
            callback(new Error('Something went wrong'));
            break;
    }
}

/**
 * Send a control message to a device, this could be on, off, setvalue.
 * Returns a JSON object of device being controlled.
 */
function controlHSDevice(device,action,value,cbfunc){
    var options = {
        hostname: hsserver,
        path: '/jsonapi.asp?action=' + action + '&id=' + device + '&value=' + value,
        port: hsport,
        headers: {
            'Authorization': auth
        }
    };

    http.get(options, function(response) {
        var body = '';
        response.on('data', function(d) {body += d;});
        response.on('end', function() {cbfunc(JSON.parse(body));});
	    response.on("error",function(e){console.log("Got error: " + e.message); });
    });    
}
