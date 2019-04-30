require('i2c')

print("--init I2C bus--")
i2cInit()


print("--write to at24c02--")
i2cWriteBytes(0xA0, 0, 0x30, 0x31, 0x32) 

print("--read from at24c02--")
isOk,data=i2cReadBytes(0xA0, 0, 3) 

print(table.cocat(data,' '))
 
