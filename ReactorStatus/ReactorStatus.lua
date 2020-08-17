--Reactor Script v0.4.0
--WebKraken

maxFuel = 79443
minfuel = .1
sleepTime = 0.2

minRate = -8000
maxRate = 8000

maxPower = 10000000
lowPower = 3000000
highPower = 9500000
--When power drops below the powerTreshold
--the reactor is enabled
reactor = peripheral.wrap("BigReactors-Reactor_0")
screen = peripheral.wrap("back")

--used for rolling average
raTickChange = 0
lastPower = 0
status = -1

--used to only update estimates occasionally
lastChargeEst = 0
lastEmptyEst = 0

runtime = 0

function resetScreen()
  resetFormatting()
  screen.clear()
  screen.setCursorPos(1,1)
end

function resetFormatting()
  screen.setBackgroundColour(colours.blue)
  screen.setTextColour(colours.white)
  screen.setTextScale(1)
end

function midWrite(text)
  local len = string.len(text)
  local x,y = screen.getSize()
  local hx = math.floor(x/2,1)
  local hy = math.floor(y/2,1)
  screen.setCursorPos(hx-(len/2), hy)
  screen.write(text)
end

function rightWrite(text, y, pad)
  local len = string.len(text)
  local x,my = screen.getSize()
  screen.setCursorPos((1+x)-(len+pad), y)
  screen.write(text)
end

function commas(num)
  local formatted = num
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

function sum(values)
  local total = 0
  for key,val in pairs(values) do
    total = total + val
  end 
  return total
end

function formatTime(time)
  local out = ""
  
  local seconds = math.floor(time % 60)
  local minutes = math.floor((time / 60) % 60)
  local hours = math.floor(time / 3600)
  
  if hours > 0 then
    out = tostring(hours).."h "
  end
  
  if minutes > 0 then
    out = out .. tostring(minutes).."m "
  end
  
  out = out .. tostring(seconds) .. "s"
  
  return out
end 

function getReactorInfo()
  local info = {}
  info.active = reactor.getActive()
  info.energy = reactor.getEnergyStored()
  info.fuel = reactor.getFuelAmount()
  return info
end

function drawActivity(status)
  resetFormatting()
  screen.setCursorPos(2,1)
  screen.write("Reactor Status:")
  if status then
    screen.setBackgroundColour(colours.green)
    rightWrite("ONLINE",1,1)
  else
    screen.setBackgroundColour(colours.red)
    rightWrite("OFFLINE",1,1)
  end
end

function drawTotal(total)
  resetFormatting()
  screen.setCursorPos(2,2)
  local com = commas(total)
  screen.write("Total Energy:")
  screen.setBackgroundColour(colours.black)
  rightWrite(com.."RF", 2, 1)
end

function drawNetChange(val)
  resetFormatting()
  screen.setCursorPos(2,3)
  screen.write("Energy Change:")
  local com = commas(val)
  screen.setBackgroundColour(colours.black)
  rightWrite(com .. "RF/t",3,1)
end 

function drawBufferStatus(status)
  resetFormatting()
  screen.setCursorPos(2,4)
  screen.write("Buffer Status:")
  if status == -1 then
    screen.setBackgroundColour(colours.grey)
    rightWrite("IDLE", 4, 1)
  elseif status == 1 then
    if raTickChange > 0 then
        screen.setBackgroundColour(colours.green)
        rightWrite("CHARGING", 4, 1)
    else
        screen.setBackgroundColour(colours.red)
        rightWrite("NOT CHARGING", 4, 1)
    end
  end
end

function drawChargeEst(totalCharge, tickChange, update)
  resetFormatting()
  screen.setCursorPos(2,5)
  screen.write("Charge Time:")
  local displayTime = '###'
  local time = 0
  
  if update == true then
    if status == 1 and tickChange > 0 then
        time = (highPower - info.energy) / (tickChange * 20)
        displayTime = formatTime(time)
    elseif status == -1 and tickChange < 0 then
        time = (info.energy - lowPower) / (-tickChange * 20)
        displayTime = formatTime(time)
    end
    lastChargeEst = displayTime
  else
    displayTime = lastChargeEst
  end
  
  screen.setBackgroundColour(colours.black)
  rightWrite(displayTime, 5, 1)
end

function drawEmptyEst(totalCharge, tickCharge, update)
  resetFormatting()
  screen.setCursorPos(2,6)
  screen.write("Time Until Empty:")
  local displayTime = '###'
  local time = 0
  
  if update == true then
    if tickChange < 0 then
      time = info.energy / (-tickChange * 20)
      displayTime = formatTime(time)
    end
    lastEmptyEst = displayTime
  else
    displayTime = lastEmptyEst
  end
  
  screen.setBackgroundColour(colours.black)
  rightWrite(displayTime, 6, 1)
end

function drawBargraph(percent)
  resetFormatting()
  local x,bottomY = screen.getSize()
  local sidePadd = 2

  screen.setTextColour(colours.white)
  screen.setCursorPos(sidePadd, bottomY-1)
  
  screen.write("Buffer Power: " .. tostring(math.floor(percent*100)) .. "%")
      
  screen.setTextColour(128)
 
  screen.setCursorPos(sidePadd, bottomY)
  screen.write("[")
  screen.setCursorPos((1+x)-sidePadd,bottomY)
  screen.write("]")
  
  local xdiff = (x-sidePadd)-sidePadd
  xdiff = xdiff -1
  screen.setCursorPos(sidePadd+1, bottomY)
  for i=0,xdiff do
    if i< (xdiff*percent) then
      screen.setTextColour(16384)
    else
      screen.setTextColour(256)
    end
    screen.write("|")
  end  
end  

function drawChargeGraph(change)
  resetFormatting()
  local x,bottomY = screen.getSize()
  bottomY = bottomY - 2
  local sidePadd = 2

  screen.setTextColour(colours.white)
  screen.setCursorPos(sidePadd, bottomY-1)

  local dischargePercent = (change / maxRate) * 100
  if change < 0 then
    dischargePercent = 0 - (minRate / change)
  end

  
  screen.write("Power change: " .. tostring(math.floor(dischargePercent)) .. "%")
      
  screen.setTextColour(128)
 
  screen.setCursorPos(sidePadd, bottomY)
  screen.write("[")
  screen.setCursorPos((1+x)-sidePadd,bottomY)
  screen.write("]")
  
  local xdiff = (x-sidePadd)-sidePadd

  local midpoint = xdiff/2
  screen.setCursorPos(sidePadd+1+midpoint, bottomY)
  screen.setTextColour(4)
  screen.write("|")

  local positive = (change > 0)

  local range = 0
  local scaleWidth = 0
  if positive then
    range = xdiff - midpoint
  else
    range = midpoint - xdiff
    for start=0,-range do
      screen.setCursorPos(sidePadd+midpoint+start, bottomY)
      screen.write("|")
    end
  end
end  


function main()
  resetScreen()
  info = getReactorInfo()

  tickChange = (info.energy - lastPower) / (20/(1/sleepTime))
  lastPower = info.energy
  
  raTickChange = math.floor((tickChange / 2) + (raTickChange / 2))

--LOGIC
  if info.energy < lowPower then
    status = 1
  elseif status == 1 then
    if info.energy > highPower then
      status = -1
    end
  end

  if status == 1 then
    reactor.setActive(true)
  else
    reactor.setActive(false)
  end

  if maxFuel * minfuel > info.fuel then
    redstone.setOutput("right", true)
  else
    redstone.setOutput("right", false)
  end

--ENDLOGIC

  drawActivity(info.active)
  drawTotal(info.energy)
  drawNetChange(math.floor(raTickChange))
  drawBufferStatus(status)
  
  local invSleepTime = 1/sleepTime
  local drawEstimates = (math.floor((runtime % 1) * invSleepTime)/invSleepTime == 0)
  
  drawChargeEst(totalCharge, raTickChange, drawEstimates)
  drawEmptyEst(totalCharge, raTickChange, drawEstimates)
  
  drawChargeGraph(math.floor(raTickChange))

  powerPercent = info.energy / maxPower
  drawBargraph(powerPercent)

  runtime = runtime + sleepTime
  sleep(sleepTime)
end  

function start()
  resetScreen()
  midWrite("Initializing")
  while true do
    main()
  end
end

start()
