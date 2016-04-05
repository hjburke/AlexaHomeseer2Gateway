/**
    Copyright 2014-2015 Amazon.com, Inc. or its affiliates. All Rights Reserved.
    Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
        http://aws.amazon.com/apache2.0/
    or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
*/

var username=""; // Username to access Homeseer 2
var password=""; // Password to access Homeseer 2
var hsserver=""; // DNS Name or IP address of HomeSeer server
var hsport="";   // Port the HomeSeer server is listening on

var auth = 'Basic ' + new Buffer(username + ':' + password).toString('base64');

var https = require('https');
var http = require('http');

var log = log;
var generateControlError = generateControlError;

var PK_Device="";  // if you want to use a specific device, enter it's device ID here
var Server_Device="";

/**
 * Main entry point.
 * Incoming events from Alexa Lighting APIs are processed via this method.
 */
exports.handler = function(event, context) {

    switch (event.header.namespace) {

        case 'Discovery':
            handleDiscovery(event, context);
        break;

        case 'Control':
            handleControl(event, context);
        break;

        case 'System':
            handleSystem(event, context);
        break;

		/**
		 * We received an unexpected message
		 */
        default:
            // Warning! Logging this in production might be a security problem.
            log('Err', 'No supported namespace: ' + event.header.namespace);
            context.fail('Something went wrong');
        break;
    }
};

/**
 * This method is invoked when we receive a "Discovery" message from Alexa Connected Home Skill.
 * We are expected to respond back with a list of appliances that we have discovered for a given
 * customer.
 */
function handleDiscovery(event, context) {
    var devicetype = 'Insteon';

    var headers = {
        namespace: 'Discovery',
        name: 'DiscoverAppliancesResponse',
        payloadVersion: '1'
    };

    var appliances = [];

    getHSDevices(devicetype,function(devices){

        // Loop through the devices and populate applicances
        for(var i=0;i<devices.length;i++){
            var device = devices[i];
        
            var applianceDiscovered = {
                applianceId: device.id,
                manufacturerName: devicetype,
                modelName: device.type,
                version: "1",
                friendlyName: device.name,
                friendlyDescription: device.name+" located in "+device.room,
                isReachable: true,
                additionalApplianceDetails: {}
            };
            appliances.push(applianceDiscovered);
        }

        appliances.sort(function(a, b) {
            return a.friendlyName.localeCompare(b.friendlyName);
        });
        var payloads = {
            discoveredAppliances: appliances
        };
        var result = {
            header: headers,
            payload: payloads
        };

        // Warning! Logging this in production might be a security problem.
        //log('Discovery', JSON.stringify(result));

        context.succeed(result);
    });
}

/**
 * Control events are processed here.
 * This is called when Alexa requests an action (IE turn off appliance).
 */
function handleControl(event, context) {

    var headers = {
        namespace: event.header.namespace,
        name: event.header.name.replace("Request","Response"),
        payloadVersion: '1'
    };
    var payloads = {
        success: true
    };
    var result = {
        header: headers,
        payload: payloads
    };

    if (event.header.namespace !== 'Control' || !(event.header.name == 'SwitchOnOffRequest' || event.header.name == 'AdjustNumericalSettingRequest') ) {
        context.fail(generateControlError(event.header.name.replace("Request","Response"), 'UNSUPPORTED_OPERATION', 'Unrecognized operation'));
    }

    var applianceId = event.payload.appliance.applianceId;

    if (typeof applianceId !== "string" ) {
        log("event payload is invalid",event);
        context.fail(generateControlError(event.header.name.replace("Request","Response"), 'UNEXPECTED_INFORMATION_RECEIVED', 'Input is invalid'));
    }

    if (event.header.name === 'SwitchOnOffRequest') {
        if (event.payload.switchControlAction === 'TURN_ON') {
            controlHSDevice(applianceId,'deviceon',100,function(response){
                if(response.error){
                    //context.fail(generateControlError("SwitchOnOffResponse", 'TARGET_HARDWARE_MALFUNCTION', response.error));
                    context.succeed(generateControlError("SwitchOnOffResponse", 'TARGET_HARDWARE_MALFUNCTION', response.error));
                } else {
                    context.succeed(result);
                }
            })
        } else if (event.payload.switchControlAction === "TURN_OFF") {
            controlHSDevice(applianceId,'deviceoff',0,function(response){
                if(response.error){
                    //context.fail(generateControlError("SwitchOnOffResponse", 'TARGET_HARDWARE_MALFUNCTION', response.error));
                    context.succeed(generateControlError("SwitchOnOffResponse", 'TARGET_HARDWARE_MALFUNCTION', response.error));
                } else {
                    context.succeed(result);
                }
            })
        }
    } else if (event.header.name === 'AdjustNumericalSettingRequest') {

        switch (event.payload.adjustmentType) {
            case 'ABSOLUTE':
                controlHSDevice(applianceId,'setdevicevalue',event.payload.adjustmentValue,function(response){
                    if(response.error){
                        log('response', response.error);
                        //context.fail(generateControlError("AdjustNumericalSettingResponse", 'TARGET_HARDWARE_MALFUNCTION', response.error));
                        context.succeed(generateControlError("AdjustNumericalSettingResponse", 'TARGET_HARDWARE_MALFUNCTION', response.error));
                    } else {
                        context.succeed(result);
                    }
                })
            break;

            case 'RELATIVE':
                controlHSDevice(applianceId,'changedevicevalue',event.payload.adjustmentValue,function(response){
                    if(response.error){
                        log('response', response.error);
                        //context.fail(generateControlError("AdjustNumericalSettingResponse", 'TARGET_HARDWARE_MALFUNCTION', response.error));
                        context.succeed(generateControlError("AdjustNumericalSettingResponse", 'TARGET_HARDWARE_MALFUNCTION', response.error));
                    } else {
                        context.succeed(result);
                    }
                })
            break;

    		/**
	    	 * We received an unexpected type
		     */
            default:
                log('Err', 'No supported namespace: ' + event.header.namespace);
                context.fail('Something went wrong');
            break;
        }
    }
}

/**
 * System events are processed here.
 * This is called when Amazon wants to check for connectivity
 */
function handleSystem(event, context) {
    if(event.header.name=="HealthCheckRequest"){
        // TODO: Add call to HSAPI to test for connectivity
                
        var headers = {
            namespace: 'System',
            name: 'HealthCheckResponse',
            payloadVersion: '1'
        };
        var payloads = {
            "isHealthy": true,
            "description": "The system is currently healthy"
        };
        var result = {
            header: headers,
            payload: payloads
        };

        context.succeed(result);
    }
}

/**
 * Get a list of devices from HomeSeer2 using the JSONAPI endpoint.
 * Takes an optional filter to limit the resulting list.
 * Returns a JSON object of devices.
 */
function getHSDevices(filter,cbfunc){
    var options = {
        hostname: hsserver,
        path: '/jsonapi.asp?action=getdevices&filter='+filter+'&verbose=yes',
        port: hsport,
        headers: {
            'Authorization': auth
        }
    };

    http.get(options, function(response) {
        var body = '';
        response.on('data', function(d) {body += d;});
        response.on('end', function() {cbfunc(JSON.parse(body));});
	    response.on("error",function(e){log("Got error: " + e.message); });
    });
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
	    response.on("error",function(e){log("Got error: " + e.message); });
    });    
}

/**
 * Utility functions.
 */
function parseJson(jsonMessage,requestType){
    try {
        return JSON.parse(jsonMessage);
    } catch (ex)
    {log("Parsing Error","error parsing JSON message of type "+requestType+": "+jsonMessage);}
}

function log(title, msg) {
    console.log('*************** ' + title + ' *************');
    console.log(msg);
    console.log('*************** ' + title + ' End*************');
}

function generateControlError(name, code, description) {
    var headers = {
        namespace: 'Control',
        name: name,
        payloadVersion: '1'
    };

    var payload = {
        exception: {
            code: code,
            description: description
        }
    };

    var result = {
        header: headers,
        payload: payload
    };

    return result;
}
