# Filter plugin for appending UCS service profile in the record for [Fluentd](http://fluentd.org)

## Requirements

| fluent-plugin-record-modifier  | fluentd | ruby |
|--------------------------------|---------|------|
| >= 1.0.0 | >= v0.14.0 | >= 2.1 |
|  < 1.0.0 | >= v0.12.0 | >= 1.9 |

## Configuration

    <filter **>
        @type add_service_profile
        domain mydomain
        username myusername
        passwordFile /etc/password/ucsPassword
    </filter>

Will add new hash to record call "serviceProfile" with the detected chassis and blade.

Will check syslog message for the following regex pattern:
    
    sys\/chassis-\d\/blade-\d

If not found, the message will get passed on unchanged.
If found, will log in to UCS using the 'host' record from the source and using mydomain\myusername and password in password file in /etc/password/ucsPassword. The login token will be cached in /tmp/token. It will then query UCS for the service profile associated with the chassis and blade id, then appened it to the record with key "serviceProfile"
