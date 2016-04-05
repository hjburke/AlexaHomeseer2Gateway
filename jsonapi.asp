<%@ LANGUAGE=VBScript %>
<%
' *****************************************************************************
dim qaction, qid, qvalue, qfilter
dim opt_verbose, opt_showhidden
dim jsonapi_version
dim locations(64)
dim numlocations
  
jsonapi_version = "0.2"

' Get action from querystring
qaction = lcase(request.querystring("action"))
if qaction = "" then qaction = "none"

' Get identifier
qid = request.querystring("id")
if qid = "" then qid = "none"

' Get value
qvalue = request.querystring("value")
if qvalue = "" then qvalue = "none"

' Get filter (used to filter getdevices to a certain type
qfilter = request.querystring("filter")

' Get verbose output or not, default is no
if request.querystring("verbose") <> "" then opt_verbose = lcase(request.querystring("verbose"))
if opt_verbose <> "yes" then opt_verbose = "no"

' Get show hidden flag, default is no
if request.querystring("showhidden") <> "" then opt_showhidden = lcase(request.querystring("showhidden"))
if opt_showhidden <> "yes" then opt_showhidden = "no"

' Display usage if no querystring
if qaction = "none" and qid = "none" and qvalue = "none" then
  response.write "{""Usage"": {""action"":[""getroom"",""getdevices"",""setdevicevalue"",""deviceon"",""deviceoff"",""getevents"",""runevent""],""id"":[""HomeseerHomeCode"",""Interface""],""value"":""DeviceValue""}}"
end if

' handle actions, checking for authorizations if needed
if qaction <> "none" then
  if GetUserAuthorizations(hs.WebLoggedInUser) <= 1 then
    response.write "{""Error"":""Authorization Required""}"
    hs.WriteLog "JSONAPI","Ignoring action from " & hs.WebLoggedInUser & " at " & request.ServerVariables("REMOTE_ADDR")
  else
    HandleAction qaction, qid, qvalue, qfilter
  end if
end if

' *****************************************************************************
function Sleep(seconds)
  set oShell = CreateObject("Wscript.Shell")
  cmd = "%COMSPEC% /c timeout " & seconds & " /nobreak"
  oShell.Run cmd,0,1
End function

' *****************************************************************************
sub HandleAction(qaction, qid, qvalue, qfilter)
  ' execute an action; we're assuming that guests have already been filtered out
  
  dim output
  
  if qaction = "getrooms" then
    ShowRooms output

  elseif qaction = "getroom" then
    ShowRoom qid, output

  elseif qaction = "getdevices" then
    ShowDevices qfilter, output

  elseif qaction = "getdevice" then
    opt_verbose="yes"
    ShowDevice qid, output

  elseif qaction = "deviceon" then
    DeviceOn qid, output
	
  elseif qaction = "deviceoff" then
    DeviceOff qid, output

  elseif qaction = "setdevicevalue" then
    SetDeviceValue qid, qvalue, output
	
  elseif qaction = "changedevicevalue" then
    ChangeDeviceValue qid, qvalue, output
	
  elseif qaction = "getevents" then
    ShowEvents output

  elseif qaction = "runevent" then
    RunEvent qid,output
  
  else ' unknown action
    output = "{""Error"":""Unknown action " & qaction & " ignored.""}"
    hs.WriteLog "JSONAPI","Ignoring unknown action " & qaction & " from " & hs.WebLoggedInUser & " at " & request.ServerVariables("REMOTE_ADDR")
  end if

  response.write(output)

end sub

' end of main routine -- everything else is functions and subs

' *****************************************************************************
sub ShowRooms(ByRef output)
  dim i
  
  ' build a list of locations
  BuildLocationsList

  ' show a list of locations as links to those locations
  output = "["
  
  for i = 1 to numlocations
    output = output & "{"
    output = output & """id"": """ & lcase(EncodeString(locations(i))) & """, "
    output = output & """name"": """ & titleCase(locations(i)) & """"
    output = output & "}"
    if not i = numlocations then
      output = output & ", "
    end if
  next

  output = output & "]"
end sub

' *****************************************************************************
sub ShowRoom(room, ByRef output)
  dim dev, devices
  dim first
  
  ' build a list of locations
  BuildLocationsList
  
  output = "{""id"": """ & lcase(room) & """, "
  output = output & """name"": """ & titleCase(Replace(DecodeString(room), "_", " "))  & """, "
  output = output & """devices"": ["

  j = hs.DeviceCount

  thisroom = lcase(Replace(room,"_"," "))
  if thisroom = "no_location" then thisroom = ""

  set devices = hs.GetDeviceEnumerator

  ' loop through all devices
  first = 1
  if IsObject(devices) then
    do while not devices.Finished
      set dev = devices.GetNext
      if not dev is nothing then
        if (opt_showhidden = "yes" or (dev.misc and &H20) = 0) and (lcase(dev.location) = thisroom or thisroom = "all") then
		      if first=1 then
            first=0
          else
            output = output & ", "
          end if
          ' show this device
          id = dev.hc & dev.dc
          ShowDevice id, output
        end if
      end if
    loop
  end if

  output = output & "]}"
end sub

' *****************************************************************************
sub ShowDevices(filter, ByRef output)
  dim devices
  dim first
  set devices = hs.GetDeviceEnumerator

  output = "["
  ' loop through all devices
  first=1
  if IsObject(devices) then
    do while not devices.Finished
      set dev = devices.GetNext
      if not dev is nothing then
        if (opt_showhidden = "yes" or (dev.misc and &H20) = 0) then
          if (InStr(dev.dev_type_string,filter)>0) then
		        if first=1 then
		          first=0
            else
              output = output & ", "
            end if
            ' show this device
            id = dev.hc & dev.dc
            ShowDevice id,output
          end if	
        end if
      end if
    loop
  end if

  output = output & "]"
end sub

' *****************************************************************************
sub ShowDevice(id,ByRef output)
  'Render a device
  dim device
  set device = hs.GetDeviceByRef(hs.DeviceExistsRef(id))
  deviceValue = hs.DeviceValue(id)
  deviceStatus = hs.DeviceStatus(id)

  output = output & "{"
  if (opt_verbose = "yes") then
    output = output &  """id"": """ & Replace(id, "\", "\u005C") & """, "
    output = output &  """name"": """ & Replace(device.name, "\", "\u005C") & """, "
  	output = output &  """room"": """ & device.location & """, "
    output = output &  """floor"": """ & device.location2 & """, "
    output = output &  """dimmable"": " & lcase(device.can_dim) & ", "
    output = output &  """status"": " & deviceStatus & ", "
    output = output &  """value"": " & deviceValue & ", "
    output = output &  """since"": """ & hs.DeviceLastChange(id) & """, "
    output = output &  """type"": """ & device.dev_type_string & """, "
    output = output &  """status_support"": " & lcase(device.status_support) & ", "
    output = output &  """misc"": """ & device.misc & """"
  else
    output = output & """id"": """ & Replace(id, "\", "\u005C") & """, "
    output = output & """name"": """ & Replace(device.name, "\", "\u005C") & """"
  end if
  output = output & "}"

  'if dev.status_support then response.write ", supports status report"
  'if (dev.misc and &H1) <> 0 then response.write ", preset dim"
  'if (dev.misc and &H2) <> 0 then response.write ", extended dim"
  'if (dev.misc and &H4) <> 0 then response.write ", SmartLinc"
  'if (dev.misc and &H8) <> 0 then response.write ", no logging"
  'if (dev.misc and &H10) <> 0 then response.write ", status-only"
  'if (dev.misc and &H20) <> 0 then response.write ", hidden"
  'if (dev.misc and &H40) <> 0 then response.write ", thermostat"
  'if (dev.misc and &H80) <> 0 then response.write ", included in power-fail"
  'if (dev.misc and &H100) <> 0 then response.write ", show values"
  'if (dev.misc and &H200) <> 0 then response.write ", auto voice command"
  'if (dev.misc and &H400) <> 0 then response.write ", confirm voice command"
  'if (dev.misc and &H800) <> 0 then response.write ", Compose device"
  'if (dev.misc and &H1000) <> 0 then response.write ", Z-Wave"
  'if (dev.misc and &H2000) <> 0 then response.write ", other direct-level dim"
  'if (dev.misc and &H4000) <> 0 then response.write ", plugin status call"
  'if (dev.misc and &H8000) <> 0 then response.write ", plugin value call"

end sub

' *****************************************************************************
sub DeviceOn(id, ByRef output)
  ' find the device validating if it exists
  if hs.DeviceExists(id) = -1 then
    output =  "{""error"": ""Device " & id & " does not exist""}"
    exit sub
  end if

  set dev = hs.GetDeviceByRef(hs.DeviceExistsRef(id))

  if dev.can_dim then
    hs.ExecX10 id, "ddim", 100
    Sleep(1)
    ShowDevice id,output
  else ' just turn it on
    hs.ExecX10 id, "on"
    Sleep(1)
    ShowDevice id, output
  end if

  hs.WriteLog "JSONAPI","Device action: " & "Turned on" & " the " & dev.location & " " & dev.name & " at " & id & " from " & hs.WebLoggedInUser & " at " & request.ServerVariables("REMOTE_ADDR")
end sub

' *****************************************************************************
sub DeviceOff(id, ByRef output)
  ' find the device validating if it exists
  if hs.DeviceExists(id) = -1 then
    output =  "{""error"": ""Device " & id & " does not exist""}"
    exit sub
  end if

  set dev = hs.GetDeviceByRef(hs.DeviceExistsRef(id))

  hs.ExecX10 id, "off"
  Sleep(1)
  ShowDevice id,output

  hs.WriteLog "JSONAPI","Device action: " & "Turned off" & " the " & dev.location & " " & dev.name & " at " & id & " from " & hs.WebLoggedInUser & " at " & request.ServerVariables("REMOTE_ADDR")
end sub

' *****************************************************************************
sub SetDeviceValue(id, value, ByRef output)
  dim dev
  
  ' find the device validating if it exists
  if hs.DeviceExists(id) = -1 then
    output =  "{""error"": ""Device " & id & " does not exist""}"
    exit sub
  end if

  set dev = hs.GetDeviceByRef(hs.DeviceExistsRef(id))

  if value < 0 or value > 100 then
    output =  "{""error"": ""Invalid dim level " & value & """}"
    exit sub
  end if

  if dev.can_dim then
    hs.ExecX10 id, "ddim", value
    Sleep(1)
    ShowDevice id,output
  else
    output =  "{""error"": ""Device not dimmable""}"
  end if

  hs.WriteLog "JSONAPI","Device action: " & "Dimmed" & " the " & dev.location & " " & dev.name & " at " & id & " from " & hs.WebLoggedInUser & " at " & request.ServerVariables("REMOTE_ADDR")
end sub

' *****************************************************************************
sub ChangeDeviceValue(id, value, ByRef output)
  dim dev
  dim newvalue
  
  ' find the device validating if it exists
  if hs.DeviceExists(id) = -1 then
    output =  "{""error"": ""Device " & id & " does not exist""}"
    exit sub
  end if

  set dev = hs.GetDeviceByRef(hs.DeviceExistsRef(id))

  ' what's the current and target dim level?
  l = hs.DeviceValue(id)

  if value < -100 or value > 100 then
    output =  "{""error"": ""Invalid dim level " & value & """}"
    exit sub
  end if
  
  ' calculate the value based on the percentage change
  
  newvalue = l + ( l * value / 100 )
  if newvalue > 100 then
    newvalue = 100
  end if

  if dev.can_dim then
    hs.ExecX10 id, "ddim", newvalue
    Sleep(1)
    ShowDevice id,output
  else
    output =  "{""error"": ""Device not dimmable""}"
  end if

  hs.WriteLog "JSONAPI","Device action: " & "Dimmed" & " the " & dev.location & " " & dev.name & " at " & id & " from " & hs.WebLoggedInUser & " at " & request.ServerVariables("REMOTE_ADDR")
end sub

' *****************************************************************************
sub ShowEvents(ByRef output)
  dim events

  set events = hs.GetEventEnumerator

  output = "["

  ' loop through all devices
  if IsObject(events) then
    do while not events.Finished
      set evt = events.GetNext
      if not evt is nothing then
        ' print event
        ShowEvent evt,output
	  if not events.Finished then
        output = output & ", "
	  end if
      end if
    loop
  end if

  output = output & "]"
end sub

' *****************************************************************************
sub ShowEvent(evt,ByRef output)
  'Render an event
  output = output & "{"
  if (opt_verbose = "yes") then
    output = output & """id"": """ & EncodeString(evt.name) & """, "
    output = output & """name"": """ & evt.name & """, "
    output = output & """group"": """ & evt.group & """, "
    output = output & """ev_time"": """ & evt.ev_time & """, "
    output = output & """evref"": """ & evt.evref & """, "
    output = output & """vcmd"": """ & evt.vcmd & """, "
    output = output & """ev_abd_time"": """ & evt.ev_abs_time & """, "
    output = output & """ev_date"": """ & evt.ev_date & """, "
    output = output & """ev_days"": """ & evt.ev_days & """, "
    output = output & """ev_offset"": """ & evt.ev_offset & """, "
    output = output & """ev_offset_before"": """ & evt.ev_offset_before & """, "
    output = output & """retrigger_delay"": """ & evt.retrigger_delay & """, "
    output = output & """ev_trig_hc"": """ & evt.ev_trig_hc & """, "
    output = output & """ev_trig_dc"": """ & evt.ev_trig_dc & """, "
    output = output & """ev_trig_func"": """ & evt.ev_trig_func & """, "
    output = output & """misc"": """ & evt.misc & """, "
    output = output & """misc2"": """ & evt.misc2 & """, "
    output = output & """rec_mins"": """ & evt.rec_mins & """, "
    output = output & """rec_secs"": """ & evt.rec_secs & """, "
    output = output & """security_offset"": """ & evt.security_offset & """, "
    output = output & """UserNote"": """ & evt.UserNote & """"
  else
    output = output & """id"": """ & EncodeString(evt.name) & """, "
    output = output & """name"": """ & evt.name & """, "
    output = output & """group"": """ & evt.group & """"
  end if
  output = output &  "}"
end sub

' *****************************************************************************
sub RunEvent(id,ByRef output)
    hs.TriggerEvent Replace(id, "_", " ")
    output = "{""status"": ""Event " & Replace(id, "_", " ") & " triggered""}"
    hs.WriteLog "JSONAPI","Triggering event " & Replace(id, "_", " ") & " from " & hs.WebLoggedInUser & " at " & request.ServerVariables("REMOTE_ADDR")
end sub

' *****************************************************************************
sub BuildLocationsList()
  ' Build a list of locations for later use (up to 64 locations)
  dim dev, devices, thisloc
  numlocations = 0

  ' loop through devices
  set devices = hs.GetDeviceEnumerator
  if IsObject(devices) then
      do while not devices.Finished
        set dev = devices.GetNext
        if not dev is nothing then
            if opt_showhidden = "yes" or (dev.misc and &H20) = 0 then
                l = 1 ' yes, add it
                thisloc = dev.location
                if thisloc = "" then thisloc = "No Location"
                ' see if this location is already listed
                for k = 1 to numlocations
                  if lcase(thisloc) = lcase(locations(k)) then
                      l = 0 ' don't bother, it's already there
                      exit for
                    end if
                   next
                ' if we're due to add it to the list,
                if l = 1 and numlocations < 64 then ' add it
                    numlocations = numlocations + 1
                    locations(numlocations) = thisloc
                  end if
              end if
          end if
        loop
    end if

  ' sort the list -- simple selection sort
  if numlocations > 2 then ' sort the list
      for i = 1 to numlocations-1
        k = i
        for j = i+1 to numlocations
          if locations(j) < locations(k) then k = j
          next
        if k <> i then
            s = locations(k)
            locations(k) = locations(i)
            locations(i) = s
          end if
        next
    end if
end sub

' *****************************************************************************
function EncodeString(s)
  ' converts a string to URL-encoding (e.g., Frank%26s_Room)
  dim i, c, result
  result = ""
  for i = 1 to len(s)
    c = mid(s,i,1)
    if c = " " then
        result = result & "_"
      elseif c = "." or c = "-" then
        result = result & c
      elseif c < "0" or (c > "9" and c < "A") or (c > "Z" and c < "a") or (c > "z") then
        result = result & "%" & hex(asc(c))
      else
        result = result & c
      end if
    next
  EncodeString = result
end function

' *****************************************************************************
function DecodeString(s)
  ' reverses the above
  dim i, c, result
  result = ""
  for i = 1 to len(s)
    c = mid(s,i,1)
    if c = "%" then
        result = result & chr(mid(s,i+1,2))
        i = i + 2
      else
        result = result & c
      end if
    next
  DecodeString = result
end function

' *****************************************************************************
function GetUserAuthorizations(username)
  dim sUserList, sUsers, sUser, sUsername, sRights, i
  sUserList = hs.GetUsers
  sUsers = Split(sUserList,",")
  for i = 0 to UBound(sUsers)
    sUser = sUsers(i)
    sUsername = left(sUser,instr(sUser,"|")-1)
    sRights = cint(trim(mid(sUser,instr(sUser,"|")+1)))
    if sUsername = username then
        GetUserAuthorizations = sRights
        exit function
      end if
    next
  GetUserAuthorizations = 0
end function

' *****************************************************************************
sub hs_install()
  ' nothing to do
end sub

' *****************************************************************************
sub hs_uninstall()
  ' nothing to do
end sub

' *****************************************************************************
function titleCase(phrase) 
  dim words, i 
  words = split(phrase," ") 
  for i = 0 to ubound(words) 
    words(i) = ucase(left(words(i),1)) & lcase(mid(words(i),2)) 
  next 
  titleCase = join(words," ") 
end function 

%>
