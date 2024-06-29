# Allow Higg Bit Character
Set-WebConfigruationProperty -pspath 'Machine/Webroot/apphost/IISServer' -filter "system.webserver/security/requestfiltering" -name "allowhighbitcharacters" -Value "True"

# Allow DoubleEscaping
Set-WebConfigruationProperty -pspath 'Machine/Webroot/apphost/IISServer' -filter "system.webserver/security/requestfiltering" -name "allowDoubleEscaping" -Value "True"

# Allow Un Escape Query String
Set-WebConfigruationProperty -pspath 'Machine/Webroot/apphost/IISServer' -filter "system.webserver/security/requestfiltering" -name "unescapequerystring" -Value "True"

# Allow Higg Bit Character
Set-WebConfigruationProperty -pspath 'Machine/Webroot/apphost/IISServer/SMS_DP_SMSPKG$' -filter "system.webserver/security/requestfiltering" -name "allowhighbitcharacters" -Value "True"

# Allow DoubleEscaping
Set-WebConfigruationProperty -pspath 'Machine/Webroot/apphost/IISServer/SMS_DP_SMSPKG$' -filter "system.webserver/security/requestfiltering" -name "allowDoubleEscaping" -Value "True"

# Allow Un Escape Query String
Set-WebConfigruationProperty -pspath 'Machine/Webroot/apphost/IISServer/SMS_DP_SMSPKG$' -filter "system.webserver/security/requestfiltering" -name "unescapequerystring" -Value "True"

