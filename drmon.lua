-- modifiable variables
local reactorSide = "back"
local fluxgateSide = "right"
local targetStrength = 50
local addOutput = 500
local maxOutputAdjustTemperature = 6000
local maxOutputSaveTemperature = 7500
local maxTemperature = 8000
local safeTemperature = 3000
local lowestFieldPercent = 15

local outputSave = true

local activateOnCharged = 1

-- please leave things untouched from here on
os.loadAPI("lib/f")

local version = "0.25"
-- toggleable via the monitor, use our algorithm to achieve our target field strength or let the user tweak it
local autoInputGate = 1
local autoOutputGate = 0
local curOutputGate = 222000
local curInputGate = 222000

-- monitor 
local mon, monitor, monX, monY

-- peripherals
local reactor
local fluxgate
local inputfluxgate

-- reactor information
local ri

-- last performed action
local action = "None since reboot"
local emergencyCharge = false
local emergencyTemp = false
local finallycharged = 0
local userStop = -1

monitor = f.periphSearch("monitor",false)
inputfluxgate = f.periphSearch("flow_gate",false)
fluxgate = f.periphSearch("flow_gate",true)
reactor = f.periphSearch("draconic_reactor",true)

if monitor == null then
  printError("No valid monitor was found")
end

if fluxgate == null then
  printError("No valid fluxgate was found")
end

if reactor == null then
  printError("No valid reactor was found")
end

if inputfluxgate == null then
  printError("No valid flux gate was found")
end

monX, monY = monitor.getSize()
mon = {}
mon.monitor,mon.X, mon.Y = monitor, monX, monY

--write settings to config file
function save_config()
  sw = fs.open("config.txt", "w")   
  sw.writeLine(version)
  sw.writeLine(autoOutputGate)
  sw.writeLine(autoInputGate)
  sw.writeLine(curInputGate)
  sw.close()
end

--read settings from file
function load_config()
  sr = fs.open("config.txt", "r")
  version = sr.readLine()
  autoOutputGate = tonumber(sr.readLine())
  autoInputGate = tonumber(sr.readLine())
  curInputGate = tonumber(sr.readLine())
  sr.close()
end


-- 1st time? save our settings, if not, load our settings
if fs.exists("config.txt") == false then
  save_config()
else
  load_config()
end

function buttons()

  while true do
    -- button handler
    event, side, xPos, yPos = os.pullEvent("monitor_touch")

    -- User star/stop button
    if yPos == 2 and xPos >= mon.X-1-string.len(ri.status) and xPos<=mon.X-2then
      if userStop == -1 then
        reactor.chargeReactor()
        userStop = 0
      elseif userStop == 0 then
        reactor.stopReactor()
        userStop = 1
      elseif userStop == 1 then
        reactor.chargeReactor()
        reactor.activateReactor()
        userStop = 0
      end
      f.clear(mon)
    end

    --Match Output and Generation
    if yPos == 8 and xPos == 16 then
      fluxgate.setSignalLowFlow(ri.generationRate)
      f.clear(mon)
    end

    -- output gate controls
    -- 2-4 = -1000, 6-9 = -10000, 10-12,8 = -100000
    -- 17-19 = +1000, 21-23 = +10000, 25-27 = +100000
    if yPos == 8 and autoOutputGate == 0 and xPos ~= 13 and xPos ~= 14 then
      curOutputGate = fluxgate.getSignalLowFlow()
      if xPos >= 2 and xPos <= 4 then
        curOutputGate = curOutputGate-1000
      elseif xPos >= 6 and xPos <= 9 then
        curOutputGate = curOutputGate-10000
      elseif xPos >= 10 and xPos <= 12 then
        curOutputGate = curOutputGate-100000
      elseif xPos >= 17 and xPos <= 19 then
        curOutputGate = curOutputGate+100000
      elseif xPos >= 21 and xPos <= 23 then
        curOutputGate = curOutputGate+10000
      elseif xPos >= 25 and xPos <= 27 then
        curOutputGate = curOutputGate+1000
      end
      fluxgate.setSignalLowFlow(curOutputGate)
      f.clear(mon)
      save_config()
    end

    -- output gate toggle
    if yPos == 8 and ( xPos == 13 or xPos == 14) then
      if autoOutputGate == 1 then
        autoOutputGate = 0
      else
        autoOutputGate = 1
      end
      f.clear(mon)
      save_config()
    end

    -- input gate controls
    -- 2-4 = -1000, 6-9 = -10000, 10-12,8 = -100000
    -- 17-19 = +1000, 21-23 = +10000, 25-27 = +100000
    if yPos == 10 and autoInputGate == 0 and xPos ~= 13 and xPos ~= 14 then
      if xPos >= 2 and xPos <= 4 then
        curInputGate = curInputGate-1000
      elseif xPos >= 6 and xPos <= 9 then
        curInputGate = curInputGate-10000
      elseif xPos >= 10 and xPos <= 12 then
        curInputGate = curInputGate-100000
      elseif xPos >= 17 and xPos <= 19 then
        curInputGate = curInputGate+100000
      elseif xPos >= 21 and xPos <= 23 then
        curInputGate = curInputGate+10000
      elseif xPos >= 25 and xPos <= 27 then
        curInputGate = curInputGate+1000
      end
      inputfluxgate.setSignalLowFlow(curInputGate)
      f.clear(mon)
      save_config()
    end

    -- input gate toggle
    if yPos == 10 and ( xPos == 13 or xPos == 14) then
      if autoInputGate == 1 then
        autoInputGate = 0
      else
        autoInputGate = 1
      end
      f.clear(mon)
      save_config()
    end



  end
end

function drawButtons(y)

  -- 2-4 = -1000, 6-9 = -10000, 10-12,8 = -100000
  -- 17-19 = +1000, 21-23 = +10000, 25-27 = +100000

  f.draw_text(mon, 2, y, " < ", colors.white, colors.gray)
  f.draw_text(mon, 6, y, " <<", colors.white, colors.gray)
  f.draw_text(mon, 10, y, "<<<", colors.white, colors.gray)

  f.draw_text(mon, 17, y, ">>>", colors.white, colors.gray)
  f.draw_text(mon, 21, y, ">> ", colors.white, colors.gray)
  f.draw_text(mon, 25, y, " > ", colors.white, colors.gray)
end



function update()
  while true do 

    term.clear()
    term.setCursorPos(1,1)
    --f.clear(mon)

    ri = reactor.getReactorInfo()

    -- print out all the infos from .getReactorInfo() to term

    if ri == nil then
      printError("reactor has an invalid setup")
    end

    for k, v in pairs (ri) do
      print(k.. ": ".. tostring(v))
    end
    print("Output Gate: ", fluxgate.getSignalLowFlow())
    print("Input Gate: ", inputfluxgate.getSignalLowFlow())
    print("UserStop", tostring(userStop))

    -- monitor output

    local statusColor
    statusColor = colors.red

    if ri.status == "online" or ri.status == "charged" then
      statusColor = colors.green
    elseif ri.status == "offline" then
      statusColor = colors.gray
    elseif ri.status == "charging" then
      statusColor = colors.orange
    end

    f.draw_text_lr(mon, 2, 2, 1, "Reactor Status", string.upper(ri.status), colors.white, statusColor, colors.black)
    if ri.status == "cold" then
      f.draw_text_right(mon, 1, 2, string.upper(ri.status), colors.white, colors.red)
    elseif ri.status == "cooling" then
      f.draw_text_right(mon, 1, 2, string.upper(ri.status), colors.white, colors.orange)
    else
      f.draw_text_right(mon, 1, 2, string.upper(ri.status), colors.white, colors.green)
    end

    f.draw_text_lr(mon, 2, 4, 1, "Generation", f.format_int(ri.generationRate) .. " rf/t", colors.white, colors.lime, colors.black)
    if ri.generationRate > inputfluxgate.getSignalLowFlow() then
      f.draw_text_lr(mon, 2, 5, 1, "Production", f.format_int(ri.generationRate - inputfluxgate.getSignalLowFlow()) .. " rf/t", colors.white, colors.green, colors.black)
    else
      f.draw_text_lr(mon, 2, 5, 1, "Production", f.format_int(0) .. " rf/t", colors.white, colors.green, colors.black)
    end

    local tempColor = colors.red
    if ri.temperature <= 5000 then tempColor = colors.green end
    if ri.temperature >= 5000 and ri.temperature <= 6500 then tempColor = colors.orange end
    f.draw_text_lr(mon, 2, 6, 1, "Temperature", f.format_int(ri.temperature) .. "C", colors.white, tempColor, colors.black)

    f.draw_text_lr(mon, 2, 7, 1, "Output Gate", f.format_int(fluxgate.getSignalLowFlow()) .. " rf/t", colors.white, colors.blue, colors.black)

    -- buttons
    if autoOutputGate == 1 then
      f.draw_text(mon, 13, 8, "AU", colors.white, colors.gray)
    else
      f.draw_text(mon, 13, 8, "MA", colors.white, colors.gray)
      f.draw_text(mon, 16, 8, "G", colors.white, colors.gray)
      drawButtons(8)
    end    
    

    f.draw_text_lr(mon, 2, 9, 1, "Input Gate", f.format_int(inputfluxgate.getSignalLowFlow()) .. " rf/t", colors.white, colors.blue, colors.black)

    if autoInputGate == 1 then
      f.draw_text(mon, 13, 10, "AU", colors.white, colors.gray)
    else
      f.draw_text(mon, 13, 10, "MA", colors.white, colors.gray)
      drawButtons(10)
    end

    local satPercent
    satPercent = math.ceil(ri.energySaturation / ri.maxEnergySaturation * 10000)*.01

    f.draw_text_lr(mon, 2, 11, 1, "Energy Saturation", satPercent .. "%", colors.white, colors.white, colors.black)
    f.progress_bar(mon, 2, 12, mon.X-2, satPercent, 100, colors.blue, colors.gray)

    local fieldPercent, fieldColor
    fieldPercent = math.ceil(ri.fieldStrength / ri.maxFieldStrength * 10000)*.01

    fieldColor = colors.red
    if fieldPercent >= 50 then fieldColor = colors.green end
    if fieldPercent < 50 and fieldPercent > 30 then fieldColor = colors.orange end

    if autoInputGate == 1 then 
      f.draw_text_lr(mon, 2, 14, 1, "Field Strength T:" .. targetStrength, fieldPercent .. "%", colors.white, fieldColor, colors.black)
    else
      f.draw_text_lr(mon, 2, 14, 1, "Field Strength", fieldPercent .. "%", colors.white, fieldColor, colors.black)
    end
    f.progress_bar(mon, 2, 15, mon.X-2, fieldPercent, 100, fieldColor, colors.gray)

    local fuelPercent, fuelColor

    fuelPercent = 100 - math.ceil(ri.fuelConversion / ri.maxFuelConversion * 10000)*.01

    fuelColor = colors.red

    if fuelPercent >= 70 then fuelColor = colors.green end
    if fuelPercent < 70 and fuelPercent > 30 then fuelColor = colors.orange end

    f.draw_text_lr(mon, 2, 17, 1, "Fuel ", fuelPercent .. "%", colors.white, fuelColor, colors.black)
    f.progress_bar(mon, 2, 18, mon.X-2, fuelPercent, 100, fuelColor, colors.gray)

    f.draw_text_lr(mon, 2, 19, 1, "Action ", action, colors.gray, colors.gray, colors.black)

    -- actual reactor interaction
    --
    if emergencyCharge == true then
      reactor.chargeReactor()
    end
    
    --If the reactor is already started user has started it
    if userStop == -1 and ri.status ~= "cold" then
      userStop = 0
    end

    -- are we charging? open the floodgates
    if ri.status == "warming_up" then
      inputfluxgate.setSignalLowFlow(900000)
      emergencyCharge = false
    end

    -- are we stopping from a shutdown and our temp is better? activate
    if emergencyTemp == true and ri.status == "stopping" and ri.temperature < safeTemperature then
      reactor.activateReactor()
      emergencyTemp = false
    end

    if ri.status == "warming_up" and finallycharged == 0 and ri.temperature > 2000 and ri.temperature < safeTemperature then
      finallycharged = 1
    end

    -- are we charged? lets activate
    if ri.status == "warming_up" and finallycharged == 1 and activateOnCharged == 1 then
      reactor.activateReactor()
      finallycharged = 0
    end

    -- are we on? regulate the input fludgate to our target field strength
    -- or set it to our saved setting since we are on manual
    if ri.status == "running" or ri.status == "cooling"  then
      if autoInputGate == 1 then 
        fluxval = ri.fieldDrainRate / (1 - (targetStrength/100) )
        print("Target Gate: ".. fluxval)
        inputfluxgate.setSignalLowFlow(fluxval)
      else
        inputfluxgate.setSignalLowFlow(curInputGate)
      end
    end

    if ri.status == "running" then

      if autoOutputGate == 1 then
        
        if ri.temperature < maxOutputAdjustTemperature then
          fluxgate.setSignalLowFlow(fluxgate.getSignalLowFlow() + addOutput)
          outputSave = true
        end
        if ri.temperature > maxOutputSaveTemperature then
          if outputSave == true then
            fluxgate.setSignalLowFlow(ri.generationRate)
            outputSave = false
          end
        end
      end

    end

    if ri.status == "stopping" or ri.status == "cooling" then
      if autoOutputGate == 1 then
        curOutputGate = 0
        fluxgate.setSignalLowFlow(ri.generationRate)
      end
    end

    if ri.status == "cold" or ri.status == "offline" then
      if autoOutputGate == 1 then
        fluxgate.setSignalLowFlow(curOutputGate)
        autoOutputGate = 0
      end
    end


    -- safeguards
    --
    
    -- out of fuel, kill it
    if fuelPercent <= 10 then
      reactor.stopReactor()
      action = "Fuel below 10%, refuel"
    end

    -- field strength is too dangerous, kill and it try and charge it before it blows
    if fieldPercent <= lowestFieldPercent and ri.status == "running" then
      action = "Field Str < " ..lowestFieldPercent.."%"
      reactor.stopReactor()
      reactor.chargeReactor()
      emergencyCharge = true
    end

    -- temperature too high, kill it and activate it when its cool
    if ri.temperature > maxTemperature then
      reactor.stopReactor()
      action = "Temp > " .. maxTemperature
      emergencyTemp = true
    end

    sleep(0.1)
  end
end

parallel.waitForAny(buttons, update)
