-- stm32f103zet6 I2C functions for eLua
-- 2019-04-30, by Tyler Xiang

tmrId=2

SDA = pio.PB_7 -- pin data
SCL = pio.PB_6 -- pin clock

----------------------------------------------------------------------------------------
function i2cInit()
	pio.pin.setdir(pio.OUTPUT,SDA,SCL)
	pio.pin.sethigh(SDA,SCL)
end
----------------------------------------------------------------------------------------
--During the high level of SCL, the descending edge of SDA is the initial signal.
function i2cStart()
	pio.pin.setdir(pio.OUTPUT,SDA)

	pio.pin.sethigh(SDA)
	tmr.delay(tmrId, 8)
	pio.pin.sethigh(SCL)
	tmr.delay(tmrId, 8)
	if pio.pin.getval(SDA)==0 then --If the SDA is low, the bus is busy and exits
		return false
	end

	pio.pin.setlow(SDA)
	tmr.delay(tmrId, 8)
	if pio.pin.getval(SDA)==1 then --If the SDA is high, the bus is busy and exits
		return false
	end
	tmr.delay(tmrId, 8)

	return true
end
----------------------------------------------------------------------------------------
--During the high level of SCL, the rising edge of SDA is the stop signal.
function i2cStop()
	pio.pin.setdir(pio.OUTPUT,SDA)

	pio.pin.setlow(SDA)
	pio.pin.sethigh(SCL)
	tmr.delay(tmrId, 8)
	pio.pin.sethigh(SDA)
	tmr.delay(tmrId, 8)
	pio.pin.setlow(SCL)
	tmr.delay(tmrId, 8)
end
----------------------------------------------------------------------------------------
function i2cACK()
	pio.pin.setlow(SCL)
	pio.pin.setdir(pio.OUTPUT,SDA)
	pio.pin.setlow(SDA)
	tmr.delay(tmrId, 6)
	pio.pin.sethigh(SCL)
	tmr.delay(tmrId, 6)
	pio.pin.setlow(SCL)
end
----------------------------------------------------------------------------------------
function i2cNoACK()
	pio.pin.setlow(SCL)
	pio.pin.setdir(pio.OUTPUT,SDA)
	pio.pin.sethigh(SDA)
	tmr.delay(tmrId, 6)
	pio.pin.sethigh(SCL)
	tmr.delay(tmrId, 6)
	pio.pin.setlow(SCL)
end
----------------------------------------------------------------------------------------
-- Function ~ Waiting for Answer ___________
-- Input parameters ~ none
-- Return results ~ success or failure
--**During the high level of SCL, the SDA level is lowered from the device to indicate the response.
function i2cWaitACK()
	local errTimes=0

	pio.pin.setdir(pio.INPUT,SDA)

	pio.pin.sethigh(SDA)
	tmr.delay(tmrId, 1)
	pio.pin.sethigh(SCL)
	tmr.delay(tmrId, 1)
	while pio.pin.getval(SDA)==1 do
		errTimes=errTimes+1
		if errTimes >250 then
			i2cStop()
			return false
		end
		tmr.delay(tmrId, 8)
		print('errTimes:'..errTimes)
	end
	pio.pin.setlow(SCL)
	return true
end
----------------------------------------------------------------------------------------
-- Function ~ Write a byte of data through I2C
-- Input parameter ~ one byte sent
-- Return results ~ none
function i2cSendByte(byte)
	local i=8

	pio.pin.setdir(pio.OUTPUT,SDA)
	while i>0 do
		pio.pin.setlow(SCL)  --When the clock signal is low, the data line level is allowed to change.

		if bit.band(byte,0x80) >0 then
			pio.pin.sethigh(SDA)
		else
			pio.pin.setlow(SDA)
		end
		byte=bit.lshift(byte,1)
		tmr.delay(tmrId, 2)
		pio.pin.sethigh(SCL)
		tmr.delay(tmrId, 2)
		pio.pin.setlow(SCL)
		tmr.delay(tmrId, 2)
		i=i-1
	end
end
----------------------------------------------------------------------------------------
-- Function ~ receive one byte of data through I2C
-- Input parameter ~ none
-- Return results ~ Received one byte 
function i2cReceiveByte()
	local i=8;byte=0

	pio.pin.setdir(pio.INPUT,SDA)
	while i>0 do
		byte=bit.lshift(byte,1)
		pio.pin.setlow(SCL)
		tmr.delay(tmrId, 2)
		pio.pin.sethigh(SCL)
		if pio.pin.getval(SDA)==1 then
			byte=bit.bor(byte,0x01)
		else
			byte=bit.bor(byte,0x00)
		end
		tmr.delay(tmrId, 1)
		i=i-1
	end
	return byte
end

----------------------------------------------------------------------------------------
-- function ~ Write batch data to I2C equipment
-- Input parameter ~ dev: device I2C address, reg: register address,...: data
-- Return results ~ success or failure
function i2cWriteBytes(dev, reg, ...)
	local arg={...}

	if i2cStart() == false then
		return false
	end
	i2cSendByte(dev)
	if i2cWaitACK() == false then
		i2cStop()
		return false
	end	

	i2cSendByte(reg)
	if i2cWaitACK() == false then
		i2cStop()
		return false
	end	
	--i2cWaitACK()

	for k,v in pairs(arg) do
		i2cSendByte(v)
		if i2cWaitACK() == false then
			i2cStop()
			return false
		end			
	end
	i2cStop()
	return true
end

----------------------------------------------------------------------------------------
-- Function ~ Reading Data from I2C Device
-- Input parameter ~ dev: device I2C address, reg: register address, len: number of bytes of data
-- Return results ~ success or failure, result data(table)
function i2cReadBytes(dev, reg, len)
	if i2cStart() == false then
		return false,nil
	end
	i2cSendByte(dev)
	if i2cWaitACK() == false then
		i2cStop()
		return false,nil
	end

	i2cSendByte(reg)
	if i2cWaitACK() == false then
		i2cStop()
		return false
	end
    --i2cWaitACK()
    tmr.delay(tmrId, 20)
    i2cStart()
    i2cSendByte(bit.bor(dev, 0x01))  --Device Address + Read Command  
    if i2cWaitACK() == false then
		i2cStop()
		return false
	end  
    --i2cWaitACK()

    local i=len
    local rtn={}
    local recv
    while i>0 do
    	recv=i2cReceiveByte()
    	if i==1 then
    		i2cNoACK() --The last byte should not answer
    	else
    		i2cACK()
    	end
    	data=table.insert(rtn,recv)
    	i=i-1
    end
    i2cStop()
    return true,rtn
end
