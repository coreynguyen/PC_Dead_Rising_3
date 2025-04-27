/*======================================================================
        D E A D   R I S I N G   3   –   M O D E L   I M P O R T E R
  ======================================================================
  
  Maxscript:  [PC] Dead Rising 3
  Author:     mariokart64n
  Date:       April 27 2025
  Version:    0.5

  ======================================================================

  Description:
    Imports models (.big) from the PC game Dead Rising 3
    
  ======================================================================
  History:
    2025-04-27
      - added read for vertex description
      
    
  ====================================================================== */
gc()
clearListener()
try(DestroyDialog dr3_util)catch(dr3_util)
rollout dr3_util "dr3_util" (
	
	struct bytestream_c (
		fullpath = "",
		filename = "",
		name = "",
		path = "",
		type = "",
		size = 0,
		swapBytes = false,
		bstream = undefined,
		
		coverageRanges = #(),

		fn open file mode:"rb" = (
			local isOpened = false
			if file != undefined and file != "" do (
				bstream = try(fopen file mode)catch(undefined)
				if bstream != undefined then (
					fseek bstream 0 #seek_end
					size = ftell bstream
					fseek bstream 0 #seek_set
					fullpath = file
					filename = filenameFromPath file
					name = getFilenameFile filename
					path = getFilenamePath file
					type = getFilenameType filename
					isOpened = true
					) else (format "Error:\n\tFailed to Open {%}\n" file)
				)
			isOpened
			),
		fn close = (
			size = 0
			fullpath = filename = name = path = type = ""
			if bstream != undefined do (fclose bstream)
			),
		fn good = (bstream != undefined),
		fn setEndian endian = (if endian == #little then swapBytes = false else if endian == #big then swapBytes = true),
		fn isBigEndian = (swapBytes),
		fn isLittleEndian = (not swapBytes),
		fn littleEndian = (swapBytes = false),
		fn bigEndian = (swapBytes = true),
		fn seek offset seekdir:#seek_set = (fseek bstream offset seekdir),
		fn align byte_alignment position:undefined = (
			if position == undefined do (position = ftell bstream)
			fseek bstream (mod (byte_alignment-(mod position byte_alignment)) byte_alignment) #seek_cur
			((ftell bstream) - position)
			),
		fn write_padding byte_alignment position:undefined = (
			if position == undefined do (position = ftell bstream)
			local p = align byte_alignment position:position
			if p > 0 do (
				local i = 1
				for i = 1 to p do (writeByte bstream 0)
				)
			),
		fn tell = (ftell bstream),
		fn print_tell tell_name = (
			local u = #("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z")
			local l = #("a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z")
			local b = 0, s = 1, p = (tell() as integer), n = bit.IntAsHex(p)
			for s = 1 to n.count do (if (b = findItem l n[s]) > 0 do (n[s] = u[b]))
			format "%: \t@ 0x% \t\tdec: %\n" tell_name (substring (n = "00000000" + n) (n.count - 7) (n.count + 6)) p
			),
		fn eos = (not (ftell bstream < size)),

		fn unsigned_to_signed &n nbits = (
			-- unsigned_to_signed 0x80 8 = -128
			if bit.get n nbits do (
				n = n - (pow 2 nbits)
				)
			),

		fn mergeIntervals intervals = (
			if intervals.count == 0 then intervals else (
				local sorted = copy intervals #nomap
				-- Use qsort with a custom comparator that sorts by the first element of each interval.
				qsort sorted (
					fn compareFN a b = (
						if a[1] < b[1] then -1 else if a[1] > b[1] then 1 else 0
						)
					)
				
				local merged = #()
				local current = sorted[1]
				for i = 2 to sorted.count do (
					local interval = sorted[i]
					if interval[1] <= current[2] then (
						-- Overlap: extend current interval if needed.
						current[2] = (if interval[2] > current[2] then interval[2] else current[2])
						)
					else (
						append merged current
						current = interval
						)
					)
				append merged current
				merged
				)
			),
		
		fn recordCoverage start length = (
			if length > 0 then (
				local newInterval = #(start, start + length) -- using an array [start, end]
				append coverageRanges newInterval
				coverageRanges = mergeIntervals coverageRanges
				)
			),
		
		fn reportUncovered = (
			local covered = mergeIntervals coverageRanges
			local gaps = #()
			local pos = 0
			for interval in covered do (
				if interval[1] > pos then (
					append gaps [pos, interval[1]]
					)
				pos = interval[2]
				)
			if pos < size then append gaps [pos, size]
			gaps  -- returns an array of intervals [start, end] that were not read.
			),

		fn read_ubyte = (
			local startPos = ftell bstream
			local val = readbyte bstream #unsigned
			local endPos = ftell bstream
			recordCoverage startPos (endPos - startPos)
			val
			),

		fn read_byte = (
			local startPos = ftell bstream
			local val = readbyte bstream #signed
			local endPos = ftell bstream
			recordCoverage startPos (endPos - startPos)
			val
			),

		fn read_ushort = (
			local startPos = ftell bstream
			local val = readshort bstream #unsigned
			if swapBytes do (val = bit.swapBytes val 1 2)
			local endPos = ftell bstream
			recordCoverage startPos (endPos - startPos)
			val
			),

		fn read_short = (
			local val = read_ushort()  -- read_ushort already records coverage
			unsigned_to_signed &val 16
			val
			),

		fn read_ulong = (
			local startPos = ftell bstream
			local val = readlong bstream #unsigned
			if swapBytes do (val = bit.swapBytes (bit.swapBytes val 1 4) 2 3)
			local endPos = ftell bstream
			recordCoverage startPos (endPos - startPos)
			val
			),

		fn read_long = (
			local val = read_ulong()  -- read_ulong already records coverage
			unsigned_to_signed &val 32
			val
			),

		fn read_ulonglong = (
			local startPos = ftell bstream
			local val = 0L
			if not swapBytes then (
				val += readlonglong bstream #unsigned
				)
			else (
				val += (
					((readbyte bstream #unsigned) * 0x0100000000000000) + \
					((readbyte bstream #unsigned) * 0x0001000000000000) + \
					((readbyte bstream #unsigned) * 0x0000010000000000) + \
					((readbyte bstream #unsigned) * 0x0000000100000000) + \
					((readbyte bstream #unsigned) * 0x0000000001000000) + \
					((readbyte bstream #unsigned) * 0x0000000000010000) + \
					((readbyte bstream #unsigned) * 0x0000000000000100) + \
					((readbyte bstream #unsigned) * 0x0000000000000001)
					)
				)
			local endPos = ftell bstream
			recordCoverage startPos (endPos - startPos)
			val
			),

		fn read_longlong = (
			local startPos = ftell bstream
			local val = 0L
			if not swapBytes then (
				val += readlonglong bstream #signed
				)
			else (
				val += (
					((readbyte bstream #unsigned) * 0x0100000000000000) + \
					((readbyte bstream #unsigned) * 0x0001000000000000) + \
					((readbyte bstream #unsigned) * 0x0000010000000000) + \
					((readbyte bstream #unsigned) * 0x0000000100000000) + \
					((readbyte bstream #unsigned) * 0x0000000001000000) + \
					((readbyte bstream #unsigned) * 0x0000000000010000) + \
					((readbyte bstream #unsigned) * 0x0000000000000100) + \
					((readbyte bstream #unsigned) * 0x0000000000000001)
					)
				unsigned_to_signed &val 64
				)
			local endPos = ftell bstream
			recordCoverage startPos (endPos - startPos)
			val
			),

		fn read_half = (
			local startPos = ftell bstream
			local inputAsInt = readshort bstream #unsigned
			if swapBytes do (inputAsInt = bit.swapBytes inputAsInt 1 2)
			local sign = (bit.and (bit.shift inputAsInt -15) 0x00000001)
			local exponent = (bit.shift (bit.and inputAsInt 0x7C00) -10) as integer + 112
			local fraction = (bit.and inputAsInt 0x03FF)
			local val = bit.intasfloat (
				(bit.or (bit.or (bit.shift fraction 13) (bit.shift exponent 23)) (bit.shift sign 31))
				)
			local endPos = ftell bstream
			recordCoverage startPos (endPos - startPos)
			val
			),

		fn read_float = (
			local startPos = ftell bstream
			local val
			if swapBytes then (
				val = bit.intAsFloat (bit.swapBytes (bit.swapBytes (readlong bstream #unsigned) 1 4) 2 3)
				)
			else (
				val = readfloat bstream
				)
			local endPos = ftell bstream
			recordCoverage startPos (endPos - startPos)
			val
			),

		fn read_double = (
			local startPos = ftell bstream
			local i = 1, ma = 0, mb = 0, mc = 0, ex = 0, bits = 11, sign = 0, expo = 0, mant = 0.0, bias = 0
			if swapBytes then (
				mc = readshort bstream #unsigned
				mb = readshort bstream #unsigned
				ma = readshort bstream #unsigned
				ex = readshort bstream #unsigned
				)
			else (
				ex = bit.swapBytes (readshort bstream #unsigned) 1 2
				ma = bit.swapBytes (readshort bstream #unsigned) 1 2
				mb = bit.swapBytes (readshort bstream #unsigned) 1 2
				mc = bit.swapBytes (readshort bstream #unsigned) 1 2
				)
			sign = if bit.get ex 16 then 1 else 0
			bias = (pow 2 (bits - 1)) - 1
			for i = 1 to bits do (expo = bit.set expo (bits - (i - 1)) (bit.get ex (16 - i)))
			for i = 1 to 4 do (mant += (if bit.get ex (4 - (i - 1)) then 1 else 0) * (pow 2 - i))
			for i = 1 to 16 do (mant += (if bit.get ma (16 - (i - 1)) then 1 else 0) * (pow 2 - (i + 4)))
			for i = 1 to 16 do (mant += (if bit.get mb (16 - (i - 1)) then 1 else 0) * (pow 2 - (i + 20)))
			for i = 1 to 16 do (mant += (if bit.get mc (16 - (i - 1)) then 1 else 0) * (pow 2 - (i + 36)))
			local val = (pow (-1) sign) * (1 + mant) * (pow 2 (expo - bias))
			local endPos = ftell bstream
			recordCoverage startPos (endPos - startPos)
			val
			),

		fn read_string length:-1 = (
			local startPos = ftell bstream
			local i = 1, s = "", b = 1
			if length == -1 then (
				s = readString bstream
				)
			else (
				for i = 1 to length do (
					b = readbyte bstream #unsigned
					if b > 0 then (
						s += bit.IntAsChar b
						)
					else (
						fseek bstream (length - i) #seek_cur
						exit
						)
					)
				)
			local endPos = ftell bstream
			recordCoverage startPos (endPos - startPos)
			s
			),

		fn read_wstring length:0 = (
			local startPos = ftell bstream
			local i = 1, s = "", b = 1
			if length == 0 then (
				do (
					b = read_ushort()
					if b > 0 do (s += bit.IntAsChar b)
					) while i > 0
				)
			else (
				for i = 1 to (length / 2) do (
					b = read_ushort()
					if b > 0 then (
						s += bit.IntAsChar b
						)
					else (
						fseek bstream (length - (i * 2)) #seek_cur
						exit
						)
					)
				)
			local endPos = ftell bstream
			recordCoverage startPos (endPos - startPos)
			s
			),

		fn write_string str length:0 = (
			local i = 1
			if length == 0 then (
				writestring bstream str
				)
			else (
				for i = 1 to length do (
					if i <= str.count and i != length then (
						writebyte bstream (bit.CharAsInt str[i]) #unsigned
						)
					else (
						writebyte bstream 0
						)
					)
				)
			),
		fn write_ubyte val = (
			writebyte bstream val #unsigned
			),
		fn write_byte val = (
			writebyte bstream val #signed
			),
		fn write_ushort val = (
			if swapBytes do (val = bit.swapBytes val 1 2)
			writeshort bstream val #unsigned
			),
		fn write_short val = (
			if swapBytes do (val = bit.swapBytes val 1 2)
			writeshort bstream val #signed
			),
		fn write_ulong val = (
			if swapBytes do (val = bit.swapBytes (bit.swapBytes val 1 4) 2 3)
			writelong bstream val #unsigned
			),
		fn write_long val = (
			if swapBytes do (val = bit.swapBytes (bit.swapBytes val 1 4) 2 3)
			writelong bstream val #signed
			),
		fn write_ulonglong num = (
			local val = 0L + num
			if not swapBytes then (
				writelonglong bstream val #unsigned
				)
			else (
				writebyte bstream (bit.shift (bit.and val 0xFF00000000000000L) -0x38) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x00FF000000000000L) -0x30) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x0000FF0000000000L) -0x28) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x000000FF00000000L) -0x20) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x00000000FF000000L) -0x18) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x0000000000FF0000L) -0x10) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x000000000000FF00L) -0x08) #unsigned
				writebyte bstream (            bit.and val 0x00000000000000FFL          ) #unsigned
				)
			),
		fn write_longlong num = (
			local val = 0L + num
			if not swapBytes then (
				writelonglong bstream val #signed
				)
			else (
				writebyte bstream (bit.shift (bit.and val 0xFF00000000000000L) -0x38) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x00FF000000000000L) -0x30) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x0000FF0000000000L) -0x28) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x000000FF00000000L) -0x20) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x00000000FF000000L) -0x18) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x0000000000FF0000L) -0x10) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x000000000000FF00L) -0x08) #unsigned
				writebyte bstream (            bit.and val 0x00000000000000FFL          ) #unsigned
				)
			),
		fn write_float val = (
			if swapBytes then (
				writelong bstream (bit.swapBytes (bit.swapBytes (bit.floatAsInt val) 1 4) 2 3) #unsigned
				)
			else (
				writefloat bstream val
				)
			),
		fn write_half val = (
			-- "https://galfar.vevb.net/wp/2011/16bit-half-float-in-pascaldelphi/"
			local Sign = 0
			local exponent=0
			local Mantissa=0
			local Result = 0
			local Src = bit.floatAsInt (val as float)
			-- Extract sign, exponent, and mantissa from Single number
			Sign = bit.shift Src -31
			exponent = (bit.shift (bit.and Src 0x7F800000) -23) - 127 + 15
			Mantissa = bit.and Src 0x007FFFFF
			if exponent >= 0 and exponent <= 30 then (
				-- Simple case - round the significand and combine it with the sign and exponent
				Result = bit.or (bit.shift Sign 15) (bit.or (bit.shift exponent 10) (bit.shift (Mantissa + 0x00001000) -13))
				)
			else (
				if Src == 0 then (
					-- Input float is zero - return zero
					Result = 0
					)
				else (
					-- Difficult case - lengthy conversion
					if exponent <= 0 then (
						if exponent <= -10 then (         
							-- Input float's value is less than HalfMin, return zero
							Result = 0
							)
						else (
							-- Float is a normalized Single whose magnitude is less than HalfNormMin.  
							-- We convert it to denormalized half.
							Mantissa = bit.shift (bit.or Mantissa 0x00800000) -(1 - exponent)
							-- Round to nearest
							if (bit.or Mantissa 0x00001000) >= 0 then
								Mantissa = Mantissa + 0x00002000
							-- Assemble Sign and Mantissa (exponent is zero to get denormalized number)
							Result = bit.or (bit.shift Sign 15) (bit.shift Mantissa -13)
							)
						)
					else (
						if exponent = 255 - 127 + 15 then (
							if Mantissa = 0 then (
								-- Input float is infinity, create infinity half with original sign
								Result = (bit.shift Sign 15) or 0x7C00
								)
							else (
								-- Input float is NaN, create half NaN with original sign and mantissa
								Result = bit.or (bit.shift Sign 15) (bit.or 0x7C00 (bit.shift Mantissa -13))
								)
							)
						else (
							-- exponent > 0 so input float is normalized Single
							-- Round to nearest
							if (bit.and Mantissa 0x00001000) >= 0 then (
								Mantissa = Mantissa + 0x00002000
								if (bit.and Mantissa 0x00800000) >= 0 then (
									Mantissa = 0
									exponent = exponent + 1
									)
								)
							if exponent >= 30 then (
								-- exponent overflow - return infinity half
								Result = (bit.shift Sign 15) or 0x7C00
								)
							else (
								-- Assemble normalized half
								Result = bit.or (bit.shift Sign 15) (bit.or (bit.shift exponent 10) (bit.shift Mantissa -13))
								)
							)
						)
					)
				)
			if swapBytes do (Result = bit.swapBytes Result 1 2)
			writeshort bstream Result #unsigned
			)
		)

	struct bytestream (
		fullpath = "",
		filename = "",
		name = "",
		path = "",
		type = "",
		size = 0,
		swapBytes = false,
		bstream = undefined,
		fn open file mode:"rb" = (
			local isOpened = false
			if file != undefined and file != "" do (
				bstream = try(fopen file mode)catch(undefined)
				if bstream != undefined then (
					fseek bstream 0 #seek_end
					size = ftell bstream
					fseek bstream 0 #seek_set
					fullpath = file
					filename = filenameFromPath file
					name = getFilenameFile filename
					path = getFilenamePath file
					type = getFilenameType filename
					isOpened = true
					) else (format "Error:\n\tFailed to Open {%}\n" file)
				)
			isOpened
			),
		fn close = (
			size = 0
			fullpath = filename = name = path = type = ""
			if bstream != undefined do (fclose bstream)
			),
		fn good = (bstream != undefined),
		fn setEndian endian = (if endian == #little then swapBytes = false else if endian == #big then swapBytes = true),
		fn isBigEndian = (swapBytes),
		fn isLittleEndian = (not swapBytes),
		fn littleEndian = (swapBytes = false),
		fn bigEndian = (swapBytes = true),
		fn seek offset seekdir:#seek_set = (fseek bstream offset seekdir),
		fn align byte_alignment position:undefined = (
			if position == undefined do (position = ftell bstream)
			fseek bstream (mod (byte_alignment-(mod position byte_alignment)) byte_alignment) #seek_cur
			((ftell bstream) - position)
			),
		fn write_padding byte_alignment position:undefined = (
			if position == undefined do (position = ftell bstream)
			local p = align byte_alignment position:position
			if p > 0 do (
				local i = 1
				for i = 1 to p do (writeByte bstream 0)
				)
			),
		fn tell = (ftell bstream),
		fn print_tell tell_name = (
			local u = #("A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z")
			local l = #("a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z")
			local b = 0, s = 1, p = (tell() as integer), n = bit.IntAsHex(p)
			for s = 1 to n.count do (if (b = findItem l n[s]) > 0 do (n[s] = u[b]))
			format "%: \t@ 0x% \t\tdec: %\n" tell_name (substring (n = "00000000" + n) (n.count - 7) (n.count + 6)) p
			),
		fn eos = (not (ftell bstream < size)),
		fn unsigned_to_signed &n nbits = (
			-- unsigned_to_signed 0x80 8 = -128
			if bit.get n nbits do (
				n = n - (pow 2 nbits)
				)
			),
		fn read_ubyte = (
			readbyte bstream #unsigned
			),
		fn read_byte = (
			readbyte bstream #signed
			),
		fn read_ushort = (
			local val = readshort bstream #unsigned
			if swapBytes do (val = bit.swapBytes val 1 2)
			val
			),
		fn read_short = (
			local val = read_ushort()
			unsigned_to_signed &val 16
			val
			),
		fn read_ulong = (
			local val = readlong bstream #unsigned
			if swapBytes do (val = bit.swapBytes (bit.swapBytes val 1 4) 2 3)
			val
			),
		fn read_long = (
			local val = read_ulong()
			unsigned_to_signed &val 32
			val
			),
		fn read_ulonglong = (
			local val = 0L
			if not swapBytes then (
				val += readlonglong bstream #unsigned
				)
			else (
				val += (
					((readbyte bstream #unsigned) * 0x0100000000000000) + \
					((readbyte bstream #unsigned) * 0x0001000000000000) + \
					((readbyte bstream #unsigned) * 0x0000010000000000) + \
					((readbyte bstream #unsigned) * 0x0000000100000000) + \
					((readbyte bstream #unsigned) * 0x0000000001000000) + \
					((readbyte bstream #unsigned) * 0x0000000000010000) + \
					((readbyte bstream #unsigned) * 0x0000000000000100) + \
					((readbyte bstream #unsigned) * 0x0000000000000001)
					)
				)
			val
			),
		fn read_longlong = (
			local val = 0L
			if not swapBytes then (
				val += readlonglong bstream #signed
				)
			else (
				val += (
					((readbyte bstream #unsigned) * 0x0100000000000000) + \
					((readbyte bstream #unsigned) * 0x0001000000000000) + \
					((readbyte bstream #unsigned) * 0x0000010000000000) + \
					((readbyte bstream #unsigned) * 0x0000000100000000) + \
					((readbyte bstream #unsigned) * 0x0000000001000000) + \
					((readbyte bstream #unsigned) * 0x0000000000010000) + \
					((readbyte bstream #unsigned) * 0x0000000000000100) + \
					((readbyte bstream #unsigned) * 0x0000000000000001)
					)
				unsigned_to_signed &val 64
				)
			val
			),
		fn read_half = (
			local inputAsInt = readshort bstream #unsigned
			if swapBytes do (inputAsInt = bit.swapBytes inputAsInt 1 2)
			local sign = (bit.and (bit.shift inputAsInt -15) 0x00000001)
			local exponent = (bit.shift (bit.and inputAsInt 0x7C00) -10) as integer + 112
			local fraction = (bit.and inputAsInt 0x03FF)
			bit.intasfloat (
				(bit.or (bit.or (bit.shift fraction 13) (bit.shift exponent 23)) (bit.shift sign 31))
				)
			),
		fn read_float = (
			if swapBytes then (
				bit.intAsFloat (bit.swapBytes (bit.swapBytes (readlong bstream #unsigned) 1 4) 2 3)
				)
			else (
				readfloat bstream
				)
			),
		fn read_double = (
			local i=1,ma=0,mb=0,mc=0,ex=0,bits=11,sign=0,expo=0,mant=0.0,bias=0
			if swapBytes then (
				mc = readshort bstream #unsigned
				mb = readshort bstream #unsigned
				ma = readshort bstream #unsigned
				ex = readshort bstream #unsigned
				)
			else (
				ex = bit.swapBytes (readshort bstream #unsigned) 1 2
				ma = bit.swapBytes (readshort bstream #unsigned) 1 2
				mb = bit.swapBytes (readshort bstream #unsigned) 1 2
				mc = bit.swapBytes (readshort bstream #unsigned) 1 2
				)
			sign = if bit.get ex 16 then 1 else 0;bias = (pow 2 (bits - 1)) - 1
			for i = 1 to bits do (expo = bit.set expo (bits-(i-1)) (bit.get ex (16-i)))
			for i = 1 to 4 do (mant+= (if bit.get ex (4-(i-1)) then 1 else 0) * (pow 2 -i))
			for i = 1 to 16 do (mant+= (if bit.get ma (16-(i-1)) then 1 else 0) * (pow 2 -(i+4)))
			for i = 1 to 16 do (mant+= (if bit.get mb (16-(i-1)) then 1 else 0) * (pow 2 -(i+20)))
			for i = 1 to 16 do (mant+= (if bit.get mc (16-(i-1)) then 1 else 0) * (pow 2 -(i+36)))
			(pow (-1) sign) * (1 + mant) * (pow 2 (expo - bias))
			),
		fn read_string length:-1 = (
			local i = 1, s = "", b = 1
			if length == -1 then (s = readString bstream)
			else (
				for i = 1 to length do (
					b = readbyte bstream #unsigned
					if b > 0 then (
						s += bit.IntAsChar b
						)
					else (
						fseek bstream (length - i) #seek_cur
						exit
						)
					)
				)
			s
			),
		fn read_wstring length:0 = (
			local i = 1, s = "", b = 1
			if length == 0 then (
				do (
					b = read_ushort()
					if b > 0 do (
						s += bit.IntAsChar b
						)
					) while i > 0
				)
			else (
				for i = 1 to (length / 2) do (
					b = read_ushort()
					if b > 0 then (
						s += bit.IntAsChar b
						)
					else (
						fseek bstream (length - (i * 2)) #seek_cur
						exit
						)
					)
				)
			s
			),
		fn write_string str length:0 = (
			local i = 1
			if length == 0 then (
				writestring bstream str
				)
			else (
				for i = 1 to length do (
					if i <= str.count and i != length then (
						writebyte bstream (bit.CharAsInt str[i]) #unsigned
						)
					else (
						writebyte bstream 0
						)
					)
				)
			),
		fn write_ubyte val = (
			writebyte bstream val #unsigned
			),
		fn write_byte val = (
			writebyte bstream val #signed
			),
		fn write_ushort val = (
			if swapBytes do (val = bit.swapBytes val 1 2)
			writeshort bstream val #unsigned
			),
		fn write_short val = (
			if swapBytes do (val = bit.swapBytes val 1 2)
			writeshort bstream val #signed
			),
		fn write_ulong val = (
			if swapBytes do (val = bit.swapBytes (bit.swapBytes val 1 4) 2 3)
			writelong bstream val #unsigned
			),
		fn write_long val = (
			if swapBytes do (val = bit.swapBytes (bit.swapBytes val 1 4) 2 3)
			writelong bstream val #signed
			),
		fn write_ulonglong num = (
			local val = 0L + num
			if not swapBytes then (
				writelonglong bstream val #unsigned
				)
			else (
				writebyte bstream (bit.shift (bit.and val 0xFF00000000000000L) -0x38) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x00FF000000000000L) -0x30) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x0000FF0000000000L) -0x28) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x000000FF00000000L) -0x20) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x00000000FF000000L) -0x18) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x0000000000FF0000L) -0x10) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x000000000000FF00L) -0x08) #unsigned
				writebyte bstream (            bit.and val 0x00000000000000FFL          ) #unsigned
				)
			),
		fn write_longlong num = (
			local val = 0L + num
			if not swapBytes then (
				writelonglong bstream val #signed
				)
			else (
				writebyte bstream (bit.shift (bit.and val 0xFF00000000000000L) -0x38) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x00FF000000000000L) -0x30) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x0000FF0000000000L) -0x28) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x000000FF00000000L) -0x20) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x00000000FF000000L) -0x18) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x0000000000FF0000L) -0x10) #unsigned
				writebyte bstream (bit.shift (bit.and val 0x000000000000FF00L) -0x08) #unsigned
				writebyte bstream (            bit.and val 0x00000000000000FFL          ) #unsigned
				)
			),
		fn write_float val = (
			if swapBytes then (
				writelong bstream (bit.swapBytes (bit.swapBytes (bit.floatAsInt val) 1 4) 2 3) #unsigned
				)
			else (
				writefloat bstream val
				)
			),
		fn write_half val = (
			-- "https://galfar.vevb.net/wp/2011/16bit-half-float-in-pascaldelphi/"
			local Sign = 0
			local exponent=0
			local Mantissa=0
			local Result = 0
			local Src = bit.floatAsInt (val as float)
			-- Extract sign, exponentonent, and mantissa from Single number
			Sign = bit.shift Src -31
			exponent = (bit.shift (bit.and Src 0x7F800000) -23) - 127 + 15
			Mantissa = bit.and Src 0x007FFFFF
			if exponent >= 0 and exponent <= 30 then (
				-- Simple case - round the significand and combine it with the sign and exponentonent
				Result = bit.or (bit.shift Sign 15) (bit.or (bit.shift exponent 10) (bit.shift (Mantissa + 0x00001000) -13))
				)
			else (
				if Src == 0 then (
					-- Input float is zero - return zero
					Result = 0
					)
				else (
					-- Difficult case - lengthy conversion
					if exponent <= 0 then (
						if exponent <= -10 then (         
							-- Input float's value is less than HalfMin, return zero
							Result = 0
							)
						else (
							-- Float is a normalized Single whose magnitude is less than HalfNormMin.  
							-- We convert it to denormalized half.
							Mantissa = bit.shift (bit.or Mantissa 0x00800000) -(1 - exponent)
							-- Round to nearest
							if (bit.or Mantissa 0x00001000) >= 0 then
							Mantissa = Mantissa + 0x00002000
							-- Assemble Sign and Mantissa (exponent is zero to get denormalized number)
							Result = bit.or (bit.shift Sign 15) (bit.shift Mantissa -13)
							)
						)
					else (
						if exponent = 255 - 127 + 15 then (
							if Mantissa = 0 then (
								-- Input float is infinity, create infinity half with original sign
								Result = (bit.shift Sign 15) or 0x7C00
								)
							else (
								-- Input float is NaN, create half NaN with original sign and mantissa
								Result = bit.or (bit.shift Sign 15) (bit.or 0x7C00 (bit.shift Mantissa -13))
								)
							)
						else (
							-- exponent is > 0 so input float is normalized Single
							-- Round to nearest
							if (bit.and Mantissa 0x00001000) >= 0 then (
								Mantissa = Mantissa + 0x00002000
								if (bit.and Mantissa 0x00800000) >= 0 then (
									Mantissa = 0
									exponent = exponent + 1
									)
								)
							if exponent >= 30 then (
								-- exponentonent overflow - return infinity half
								Result = (bit.shift Sign 15) or 0x7C00
								)
							else (
								-- Assemble normalized half
								Result = bit.or (bit.shift Sign 15) (bit.or (bit.shift exponent 10) (bit.shift Mantissa -13))
								)
							)
						)
					)
				)
			if swapBytes do (result = bit.swapBytes result 1 2)
			writeshort bstream result #unsigned
			)
		)
	
	struct byteArray (
		
		filename = "",
		size = 0,
		data = #(),
		
		fn readFromStream f fsize:0 = (
			if (f == undefined) then (
				format "readFromStream: invalid file handle\n"
				size = 0
				data = #()
				)
			else (
				local pos = ftell f
				if fsize == 0 do (
					fseek f 0 #seek_end
					fsize = ftell f - pos
					fseek f pos #seek_set
					)
				size = fsize
				local q = size/4 as integer
				local r = size - q*4
				data[q+r] = 0
				local i
				for i = 1 to q do data[i] = readLong f
				for i = 1 to r do data[q+i] = readByte f
				)
			),

		fn writeToStream s = (
			if (s == undefined) then (
				format "writeToStream: invalid file handle\n"
				)
			else (
				local q = size/4 as integer
				local r = size - q*4
				local i
				for i = 1 to q do writeLong s data[i]
				for i = 1 to r do writeByte s data[q+i]
				)
			),

		fn read filePath = (
			local f = fopen filePath "rbS"
			if (f == undefined) then (
				format "Error: cannot open %\n" filePath
				false
				)
			else (
				readFromStream f fsize:(getFileSize filePath)
				fclose f
				true
				)
			),

		fn write filePath = (
			if (data.count == 0) then (
				format "Error: nothing to write\n"
				false
				)
			else (
				local s = fopen filePath "wbS"
				if (s == undefined) then (
					format "Error: cannot create %\n" filePath
					false
					)
				else (
					writeToStream s
					fclose s
					true
					)
				)
			),

		bitPos  = 0,
		bytePos = 1,

		fn _bitReset = (
			bitPos  = 0
			bytePos = 1
			),

		fn _bitRead n = (
			local val   = 0
			local shift = 0
			local need  = n
			while need > 0 do (
				if (bytePos > size) then (
					need = 0
					format "inflate: ran out of input\n"
					)
				else (
					local cur     = data[bytePos]
					local avail   = 8 - bitPos
					local take    = avail
					if (need < avail) then take = need
					local mask    = (bit.shift 1 take) - 1
					local part    = (bit.shift cur bitPos) band mask
					val  = val + (bit.shift part shift)
					need = need - take
					shift= shift + take
					bitPos = bitPos + take
					if (bitPos == 8) then (
						bitPos  = 0
						bytePos = bytePos + 1
						)
					)
				)
			val
			),

		fn _bitAlignByte = (
			if (bitPos != 0) do (
				bitPos  = 0
				bytePos = bytePos + 1
				)
			),
		
		litTable = #(),
		litMax = 0,
		distTable= #(),
		distMax= 0,

		fn _buildHuff lens = (
			local maxBits = 0
			local i
			for i in lens where i > maxBits do maxBits = i
			local blCount = for i = 1 to maxBits collect 0
			for i in lens where i != 0 do blCount[i] = blCount[i] + 1
			local nextCode = #(0)
			for i = 1 to maxBits do (
				local prev = nextCode[i]
				local nxt  = bit.shift (prev + blCount[i-1]) 1
				append nextCode nxt
				)
			local map = #()
			for i = 1 to lens.count do (
				local ln = lens[i]
				if ln != 0 do (
					local code = nextCode[ln]
					nextCode[ln] = code + 1
					local key  = bit.shift code (16 - ln)
					local step = bit.shift 1 (16 - ln)
					local k
					for k = key to 0xFFFF by step do map[k+1] = i-1
					)
				)
			#(map, maxBits)
			),

		fn _initFixedHuffman = (
			if litTable.count == 0 do (
				local litLens = for i = 1 to 288 collect 0
				local i
				for i = 1   to 144 do litLens[i]   = 8
				for i = 145 to 256 do litLens[i]   = 9
				for i = 257 to 280 do litLens[i]   = 7
				for i = 281 to 288 do litLens[i]   = 8
				local distLens = for i = 1 to 32 collect 5
				local res      = _buildHuff litLens
				litTable = res[1]
				litMax = res[2]
				res = _buildHuff distLens
				distTable = res[1]
				distMax = res[2]
				)
			),

		fn _huffRead tbl maxBits = (
			local code = 0
			local bits = 0
			local result = -1
			local searching = true
			while searching do (
				local bit = _bitRead 1
				code = code + bit.shift bit bits
				bits = bits + 1
				if bits > maxBits then (
					searching = false
					)
				else (
					local idx = bit.shift code (16 - bits) + 1
					if idx <= tbl.count then (
						local sym = tbl[idx]
						if sym != undefined do (
							result    = sym
							searching = false
							)
						)
					)
				)
			result
			),

		lenBase  = #(3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258),
		lenExtra = #(0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0),
		distBase = #(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32),
		distExtra= #(0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14),
		
		fn _inflate startIdx srcBytes = (
			local out = #()
			_bitReset()
			bytePos = startIdx
			_initFixedHuffman()

			local finishedStream = false
			while finishedStream == false do (
				local bfinal = _bitRead 1
				local btype  = _bitRead 2

				if btype == 0 then (
					_bitAlignByte()
					local len  = _bitRead 16
					local nlen = _bitRead 16
					if ((len + nlen) != 0xFFFF) then (
						format "inflate: LEN/NLEN mismatch – abort\n"
						finishedStream = true
						)
					else (
						local i
						for i = 1 to len do (
							if (bytePos > size) then (
								format "inflate: truncated stored block\n"
								finishedStream = true
								exit
								)
							append out data[bytePos]
							bytePos = bytePos + 1
							)
						)
					)
				else if btype == 1 then (
					local endOfBlock = false
					while endOfBlock == false do (
						local sym = _huffRead litTable litMax
						if sym < 256 then (
							append out sym
							)
						else if sym == 256 then (
							endOfBlock = true
							)
						else (
							local lenIdx  = sym - 257 + 1
							local length  = lenBase[lenIdx]
							local extraL  = lenExtra[lenIdx]
							if extraL > 0 do length = length + (_bitRead extraL)

							local distSym = _huffRead distTable distMax
							local distIdx = distSym + 1
							local distance = distBase[distIdx]
							local dExtra   = distExtra[distIdx]
							if dExtra > 0 do distance = distance + (_bitRead dExtra)

							if distance < 1 do distance = 1
							if distance > out.count do distance = out.count

							local j
							for j = 1 to length do (
								local val = out[out.count - distance + 1]
								append out val
								)
							)
						)
					)
				else (
					format "inflate: dynamic Huffman (type 2) not supported – abort\n"
					finishedStream = true
					)

				if bfinal == 1 do finishedStream = true
				)
			out
			),

		/* ------------------------------------------------------------------
		   zlib wrapper that decompresses **into this byteArray**
		   ------------------------------------------------------------------ */
		fn zlibDecompressSelf srcOffset:1 compSize:0 =
		(
			-- basic header check (CM == 8 / mod 31 == 0 / no preset dic)
			if (srcOffset + 1 > size) then
			(
				format "zlib: header truncated\n"
				)
			else
			(
				local cmf = data[srcOffset]
				local flg = data[srcOffset+1]
				if ((cmf band 0x0F) == 8) then
				(
					if (((cmf*256 + flg) mod 31) == 0) then
					(
						if ((flg band 0x20) == 0) then
						(
							local defStart = srcOffset + 2
							local bytesAvail = size - defStart + 1
							if (compSize > 0) then bytesAvail = compSize - 2
							local inflated = _inflate defStart bytesAvail
							data = inflated
							size = inflated.count
							)
						else
						(
							format "zlib: preset dictionary not supported\n"
							)
						)
					else
					(
						format "zlib: bad header checksum\n"
						)
					)
				else
				(
					format "zlib: unsupported compression method\n"
					)
				)
			)
		)
	
	struct drAnimLibSkeletonEntry_t ( -- 36 bytes
		/*float[4]* unk006 = #(0.0, 0.0, 0.0, 0.0), -- quat
		/*float[3]*/ unk007 = #(0.0, 0.0, 0.0), -- position
		/*uint32_t*/ unk008 = 0, -- unknown
		/*uint32_t*/ unk009 = 0, -- unknown
		fn read f = (
			unk006 = #(f.read_float(), f.read_float(), f.read_float(), f.read_float())
			unk007 = #(f.read_float(), f.read_float(), f.read_float())
			unk008 = f.read_ulong()
			unk009 = f.read_ulong()
			),
		fn write s = (
			for v in unk006 do (s.write_float(v))
			for v in unk007 do (s.write_float(v))
			for v in unk008 do (s.write_float(v))
			)
		)
	
	struct drAnimLibSkeleton_t ( -- 16 bytes + (36 * n) Bytes
		/*uint32_t*/ unk000 = 0,
		/*uint32_t*/ unk001 = 0,
		/*uint32_t*/ unk002 = 0,
		/*uint32_t*/ unk003 = 0,
		/*drAnimLibSkeletonEntry_t[]*/ entry = #(),
		/*int8_t[]*/ unk009 = #(), -- indices?
		/*string[]*/ unk10 = #(), -- each string is null terminated
		fn size = (
			local nsize = 16 + (unk001 * 37)
			for i = 1 to unk001 do (nsize += unk10[i].count + 1)
			nsize
			),
		fn fixEnvelopes &obj = (
			local sm = undefined, nb = 0
			local boneArray = #(), i = 1
			local childArray = #(), posArray = #()
			local find = 0, ii = 1, tfm = matrix3 1, tfm2 = matrix3 1
			-- Check We have a selection
			if isValidobj obj then (
				-- Get the skin modifier
				if classOf (sm = try(obj.modifiers[#Skin])catch(undefined)) == Skin then (
					-- Get Number of bones assiocated with skin modifier
					nb = skinOps.GetNumberBones sm
					
					-- Check that Count is valid and greater then 0
					if nb != undefined and nb > 0 do (
						
						-- Size Array to store bone nodes
						boneArray[nb] = undefined
						
						-- Collect bone nodes to array
						for i = 1 to nb do (
							boneArray[i] = getNodeByName (
								skinOps.GetBoneName sm i 0
								)
							)
						)
					) else (messagebox "Error:\tFailed to Find Skin Modifier")
				) else (messagebox "Error:\tNothing Selected")
			
			-- Generate new bone ends
			if boneArray.count > 0 do (
				
				-- Size End Position Array
				posArray[boneArray.count] = [0.0, 0.0, 2.0]
				
				for i = 1 to boneArray.count do (
					-- Determine how to aquire a end bone position by the following conditions:
					-- 	A: There is only 1 child, we set its position as the end position
					-- 	B: There are multiple Childs, we average their Positions and set that as the end position
					-- 	C: There are no Children, however the bone has a parent and we can project a forward vector as the end position
					-- 	D: There are no children, no parents, the default value is used for the bone position
					
					-- Set Default Position, Case D
					posArray[i] = boneArray[i].position + [0.0, 0.0, 2.0]
					
					-- Check if Bone is Valid
					if boneArray[i] != undefined do (
						
						-- Collect Children
						childArray = boneArray[i].children
						
						if childArray.count == 1 then (
							-- Case A: Use Only Child As End Point
							posArray[i] = childArray[1].position
							)
						else if childArray.count > 0 then (
							-- Case B: Use Average of Children Positions as End Point
							posArray[i] = [0.0, 0.0, 0.0]
							for ii = 1 to childArray.count do (
								posArray[i] += childArray[ii].position
								)
							posArray[i] /= childArray.count
							)
						else if boneArray[i].parent != undefined then (
							-- Case C: Use Parent
							posArray[i] = [
								(boneArray[i].parent.position.x * -0.5) + (boneArray[i].position.x * 1.5), \
								(boneArray[i].parent.position.y * -0.5) + (boneArray[i].position.y * 1.5), \
								(boneArray[i].parent.position.z * -0.5) + (boneArray[i].position.z * 1.5) \
								]
							)
						)
					
					-- Check result doesnt suck
					if distance posArray[i] boneArray[i].position < 0.1 do (
						posArray[i] = boneArray[i].position + [0.0, 0.0, 2.0]
						)
					)
				)
			
			-- Replace Envelopes
			if posArray.count > 0 do (
				for i = 1 to boneArray.count do (
					skinOps.SetStartPoint sm i [0.0, 0.0, 0.0]
					tfm = obj.transform
					tfm2 = boneArray[i].transform
					
					tfm.row4 = (posArray[i] - boneArray[i].position)
					tfm2.row4 = [0.0, 0.0, 0.0]
					
					
					tfm *= inverse tfm2
					skinOps.SetEndPoint sm i tfm.row4
					)
				)
			),
		fn fixBoneLengths &boneArray = (
			
			-- Generate new bone ends
			if boneArray.count > 0 do (
				
				
				-- Size End Position Array
				local posArray = #()
				posArray[boneArray.count] = [0.0, 0.0, 2.0]
				
				for i = 1 to boneArray.count do (
					-- Determine how to aquire a end bone position by the following conditions:
					-- 	A: There is only 1 child, we set its position as the end position
					-- 	B: There are multiple Childs, we average their Positions and set that as the end position
					-- 	C: There are no Children, however the bone has a parent and we can project a forward vector as the end position
					-- 	D: There are no children, no parents, the default value is used for the bone position
					
					-- Set Default Position, Case D
					posArray[i] = boneArray[i].position + [0.0, 0.0, 2.0]
					
					-- Check if Bone is Valid
					if boneArray[i] != undefined do (
						
						-- Collect Children
						local childArray = boneArray[i].children
						
						if childArray.count == 1 then (
							-- Case A: Use Only Child As End Point
							posArray[i] = childArray[1].position
							)
						else if childArray.count > 0 then (
							-- Case B: Use Average of Children Positions as End Point
							posArray[i] = [0.0, 0.0, 0.0]
							for ii = 1 to childArray.count do (
								posArray[i] += childArray[ii].position
								)
							posArray[i] /= childArray.count
							)
						else if boneArray[i].parent != undefined then (
							-- Case C: Use Parent
							posArray[i] = [
								(boneArray[i].parent.position.x * -0.5) + (boneArray[i].position.x * 1.5), \
								(boneArray[i].parent.position.y * -0.5) + (boneArray[i].position.y * 1.5), \
								(boneArray[i].parent.position.z * -0.5) + (boneArray[i].position.z * 1.5) \
								]
							)
						)
					
					-- Check result doesnt suck
					if distance posArray[i] boneArray[i].position < 0.1 do (
						posArray[i] = boneArray[i].position + [0.0, 0.0, 2.0]
						)
					)
				)
			
			-- Updates Lengths
			if posArray.count > 0 do (
				for i = 1 to boneArray.count do (
					
					boneArray[i].length = distance boneArray[i].position posArray[i]
					if boneArray[i].position.x < 0.0 do (
						boneArray[i].length = -boneArray[i].length
						)
					)
				)
			),
		fn colorBones &boneArray = (
			
			-- Define color palette
			local colorHead = color 166 202 240
			local colorSpine = color 8 110 134
			local colorLeft = color 28 28 177
			local colorRight = color 6 134 6
			local colorRoot = color 115 115 115
			local colorPelvis = color 224 198 87
			local colorLeftThumb = color 134 6 6
			local colorRightThumb = color 224 198 87
			local colorLeftFingers = color 108 8 136
			local colorRightFingers = color 113 134 6
			
			-- Iterate through each bone
			for b in boneArray do (
				local hasParent = (b.parent != undefined)
				local isRoot = (not hasParent or matchPattern b.name pattern:"root")
				local isHead = matchPattern b.name pattern:"*head*" or matchPattern b.name pattern:"atama*"
				local isSpine = matchPattern b.name pattern:"*spine*" or matchPattern b.name pattern:"mune*"
				local isPelvis = matchPattern b.name pattern:"*pelvis*" or matchPattern b.name pattern:"koshi"
				local isLeg = matchPattern b.name pattern:"*leg*" or matchPattern b.name pattern:"*momo*" or matchPattern b.name pattern:"*knee*" or matchPattern b.name pattern:"*l_hip*" or matchPattern b.name pattern:"*r_hip*" or matchPattern b.name pattern:"*ankle*" or matchPattern b.name pattern:"*sune*" or matchPattern b.name pattern:"*ashi*" or matchPattern b.name pattern:"*shin*" or matchPattern b.name pattern:"*calf*"
				local isArm = matchPattern b.name pattern:"*arm*" or matchPattern b.name pattern:"*elbow*"  or matchPattern b.name pattern:"*ninoude*" or matchPattern b.name pattern:"*kote*" or matchPattern b.name pattern:"*wrist*" or matchPattern b.name pattern:"*shoulder*"
				local isFinger = matchPattern b.name pattern:"*finger*" or matchPattern b.name pattern:"*yubi*" or matchPattern b.name pattern:"*thumb*" or matchPattern b.name pattern:"*index*" or matchPattern b.name pattern:"*middle*" or matchPattern b.name pattern:"*ring*" or matchPattern b.name pattern:"*pink*"
				local isThumb = matchPattern b.name pattern:"*thumb*"
				local isLeftBone = matchPattern b.name pattern:"*.l_*" or matchPattern b.name pattern:"kl_*"
				local isRightBone = matchPattern b.name pattern:"*.r_*" or matchPattern b.name pattern:"kr_*"
				
				-- Assign colors based on positions, names, and relationships
				if isRoot then (
					b.wirecolor = colorRoot
					)
				else if isHead then (
					b.wirecolor = colorHead
					)
				else if isSpine then (
					b.wirecolor = colorSpine
					)
				else if isPelvis then (
					b.wirecolor = colorPelvis
					)
				else if isLeg then (
					if isLeftBone then (
						b.wirecolor = colorLeft
						) else if isRightBone then (
						b.wirecolor = colorRight
						)
					)
				else if isArm then (
					if isLeftBone then (
						b.wirecolor = colorLeft
						) else if isRightBone then (
						b.wirecolor = colorRight
						)
					)
				else if isFinger then (
					if isLeftBone then (
						b.wirecolor = colorLeftFingers
						) else if isRightBone then (
						b.wirecolor = colorRightFingers
						)
					)
				
				-- Always propagate color to children
				for child in b.children do (
					child.wirecolor = b.wirecolor
					)
				)
			
			),
		fn build mscale:39.3701 = (
			
			local boneArray = #()
			for i = 1 to unk001 do (
				--local d = dummy boxsize:([1.0, 1.0, 1.0] * 0.05)
				local d = BoneSys.createBone [0.0, 0.0, 0.0] [1.0, 0.0, 0.0] [0.0, 0.0, 1.0]
				
				d.name = unk10[i]
				d.position = [entry[i].unk007[1], entry[i].unk007[2], entry[i].unk007[3]] * -mscale
				d.rotation = Quat ( -entry[i].unk006[1]) ( -entry[i].unk006[2]) ( -entry[i].unk006[3]) ( entry[i].unk006[4]) 
				
				--print (entry[i].unk009 as string)
				d.showLinksOnly = d.showLinks = true
				--d.transform = orthogonalize d.transform
				append boneArray d
				)
			
			for i = 1 to unk001 do (
				if unk009[i] == 255 then (
					boneArray[i].transform *= rotateXMatrix 90
					)
				else (
					boneArray[i].transform =  inverse boneArray[i].transform * boneArray[unk009[i] + 1].transform
					boneArray[i].parent = boneArray[unk009[i] + 1]
					)
				
				)
			fixBoneLengths &boneArray
			colorBones &boneArray
			boneArray
			),
		fn read f = (
			
			unk000 = f.read_ulong()
			unk001 = f.read_ulong()
			unk002 = f.read_ulong()
			unk003 = f.read_ulong()
			entry = #()
			unk009 = #()
			if unk001 > 0 do (
				entry[unk001] = drAnimLibSkeletonEntry_t()
				
				for i = 1 to unk001 do (
					entry[i] = drAnimLibSkeletonEntry_t()
					entry[i].read(f)
					)
				
				unk009[unk001] = 0
				for i = 1 to unk001 do (
					unk009[i] = f.read_ubyte()
					)
				
				unk10[unk001] = ""
				local spos = f.tell()
				for i = 1 to unk001 do (
					unk10[i] = f.read_string()
					)
				
				)
			),
		fn write s = (
			s.write_ulong(unk000)
			s.write_ulong(unk001 = entry.count)
			s.write_ulong(unk002)
			s.write_ulong(unk003)
			local ptr = 0
			for i = 1 to entry.count do (
				entry[i].unk006 = ptr
				entry[i].write(s)
				ptr += unk10[i].count + 1
				)
			for o in unk009 do (s.write_byte(o))
			for o in unk10 do (s.write_string(o))
			)
		)
	
	struct dr3MdlLocatorArrayEntry_t ( -- 52 Bytes
		
		/* uint32_t */ unk150 = 0,
		/* float[7] */ unk151 = #(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
		/* uint32_t */ unk152 = 0,
		/* float */    unk153 = 0.0,
		/* float[3] */ unk154 = #(0.0, 0.0, 0.0),
		
		fn read f = (
			unk150 = f.read_ulong()
			unk151 = #(f.read_float(), f.read_float(), f.read_float(), f.read_float(), f.read_float(), f.read_float(), f.read_float())
			unk152 = f.read_ulong()
			unk153 = f.read_float()
			unk154 = #(f.read_float(), f.read_float(), f.read_float())
			),
		fn write s = (
			s.write_ulong(unk150)
			for v in unk151 do (s.write_float(v))
			s.write_ulong(unk152)
			s.write_float(unk153)
			for v in unk154 do (s.write_float(v))
			)
		)
	
	struct dr3MdlLocatorArray_t ( -- (n * 52) Bytes
		
		/*dr3MdlLocatorArrayEntry_t[]*/ entry = #(),
		
		fn size = (entry.count * 52),
		fn read f count = (
			entry = #()
			if count > 0 do (
				entry[count] = dr3MdlLocatorArrayEntry_t()
				for i = 1 to count do (
					entry[i] = dr3MdlLocatorArrayEntry_t()
					entry[i].read(f)
					)
				)
			),
		fn write s = (for o in entry do (s.write(o)))
		)
	
	struct dr3MdlTextureNames_t (
		/*uint16_t*/     unk140 = 0,      -- number of texture names
		/*uint16_t[]*/   unk141 = #(),    -- array of ushort offsets (relative to start of string block)
		/*string[]*/     unk142 = #(),    -- array of null-terminated texture names
		
		fn size = (
			-- 2 bytes for unk140 + 2 bytes per offset + (string length + 1) per entry
			local total = 2 + (unk140 * 2)
			for i = 1 to unk140 do (
				total += (unk142[i].count + 1)
				)
			total
			),

		fn read f = (
			unk140 = f.read_ushort()               -- read count
			local spos = f.tell()                  -- start of offsets block
			unk141 = #()                           -- reset arrays
			unk142 = #()
			if unk140 > 0 then (
				-- read the offset table
				for i = 1 to unk140 do (
					unk141[i] = f.read_ushort()
					)
				-- read each string by seeking to (spos + offset)
				for i = 1 to unk140 do (
					f.seek (spos + unk141[i])      -- default #seek_set
					unk142[i] = f.read_string()    -- null-terminated
					)
				)
			),

		fn write s = (
			-- update count from how many names we actually have
			unk140 = unk142.count
			s.write_ushort unk140

			unk141 = #()       -- reset offset table
			local ptr = 0      -- pointer into string block (starts at 0)

			-- write offsets
			for i = 1 to unk140 do (
				unk141[i] = ptr
				s.write_ushort ptr
				ptr += (unk142[i].count + 1)
				)

			-- write strings back-to-back, each null-terminated
			for i = 1 to unk140 do (
				s.write_string unk142[i]
				)
			)
		)
	
	struct dr3MdlSceneHeader_t ( -- 20 Bytes
		/*uint32_t*/ unk130 = 0,
		/*uint32_t*/ unk131 = 0,
		/*uint32_t*/ unk132 = 0,
		/*uint32_t*/ unk133 = 0, -- number of entries in SceneDescription
		/*uint32_t*/ unk134 = 0, -- number of D3DVertexDesc files
		fn size = (20),
		fn read f = (
			unk130 = f.read_ulong()
			unk131 = f.read_ulong()
			unk132 = f.read_ulong()
			unk133 = f.read_ulong()
			unk134 = f.read_ulong()
			),
		fn write s = (
			s.write_ulong(unk130)
			s.write_ulong(unk131)
			s.write_ulong(unk132)
			s.write_ulong(unk133)
			s.write_ulong(unk134)
			)
		)
	
	struct dr3MdlMaskRenderStripEntry_t ( -- 36 Bytes
		/*uint32_t*/ unk020 = 0, -- always 1 ?
		/*uint32_t*/ unk021 = 0, -- index?
		/*uint32_t*/ unk022 = 0, -- material id?
		/*uint32_t*/ unk023 = 0, -- flag
		/*uint32_t*/ unk024 = 0, -- flag
		/*uint32_t*/ unk025 = 0, -- count from desc2
		/*uint32_t*/ unk026 = 0, -- flag
		/*uint32_t*/ unk027 = 0,-- commandBUffer Offset to element
		/*uint32_t*/ unk028 = 0, -- ? CommandBuffer, Element Size? ((n*4)+4) ?
		
		-- for internal processing
		unk027_index = -1,
		unk028_count = -1,
		fn read f = (
			unk020 = f.read_ulong()
			unk021 = f.read_ulong()
			unk022 = f.read_ulong()
			unk023 = f.read_ulong()
			unk024 = f.read_ulong()
			unk025 = f.read_ulong()
			unk026 = f.read_ulong()
			unk027 = f.read_ulong()
			unk028 = f.read_ulong()
			),
		fn write s = (
			s.write_ulong(unk020)
			s.write_ulong(unk021)
			s.write_ulong(unk022)
			s.write_ulong(unk023)
			s.write_ulong(unk024)
			s.write_ulong(unk025)
			s.write_ulong(unk026)
			s.write_ulong(unk027)
			s.write_ulong(unk028)
			)
		)
	
	struct dr3MdlMaskRenderStrip_t ( -- (n * 28) Bytes
		
		/*dr3MdlMaskRenderStripEntry_t[]*/ entry = #(),
		
		fn size = (36 * entry.count),
		fn read f count = (
			entry = #()
			if count > 0 do (
				entry[count] = dr3MdlMaskRenderStripEntry_t()
				for i = 1 to count do (
					entry[i] = dr3MdlMaskRenderStripEntry_t()
					entry[i].read(f)
					)
				)
			),
		fn write s = (for o in entry do (s.write(o)))
		)
	
	struct dr3MdlCommandBufferEnum_t (
		CMD_UNDEFINED                               = 0x00,
		CMD_RET                                     = 0x01,
		CMD_CALL                                    = 0x02,
		CMD_CALL_FAR                                = 0x03,
		CMD_REF                                     = 0x04,
		CMD_REF_FAR                                 = 0x05,
		CMD_CLEAR                                   = 0x06,
		CMD_DRAW                                    = 0x07,
		CMD_DRAW_INDEXED                            = 0x08,
		SET_VERTEX_DECL                             = 0x09,
		SET_VERTEX_BUFFER                           = 0x0A,
		SET_INDEX_BUFFER                            = 0x0B,
		SET_TEXTURE                                 = 0x0C,
		SET_TEXTURE_STATE                           = 0x0D,
		SET_DRAW_STATE                              = 0x0E,
		UNUSED_WAS_PARTICLE_DATA                    = 0x0F,
		FILL_DYNAMIC_VERTEX_BUFFER                  = 0x10,
		SET_CONST_COLOR                             = 0x11,
		SET_CONST_ALPHA                             = 0x12,
		SET_NUM_INSTANCES                           = 0x13,
		SET_STREAM_FREQ                             = 0x14,
		SET_DEPTH_BIAS                              = 0x15,
		SET_SHADER_CONSTANT_STACK_NODE              = 0x16,
		SET_IMMEDIATE_BOUND_CONSTANT_SET_HANDLE     = 0x17,
		SET_VS_CONST                                = 0x18,
		SET_PS_CONST                                = 0x19,
		SET_CB_CONST                                = 0x1A,
		SET_PS_CONST_IMM                            = 0x1B,
		OVERRIDE_DRAW_STATE                         = 0x1C,
		SET_NAMED_EVENT                             = 0x1D,
		SET_USER_CLIP_PLANES_ENABLED                = 0x1E,
		SET_DIFFUSE                                 = 0x1F,
		SET_SPEC_VARS                               = 0x20,
		SET_ENV_REFLECTIVITY                        = 0x21,
		CMD_NOOP0                                   = 0x22,
		CMD_NOOP2                                   = 0x23,
		OVERRIDE_TEXTURE                            = 0x24,
		SET_OFFSET_VERTEX_BUFFER                    = 0x25,
		SET_PARALLAX_PARAMS                         = 0x26,
		SET_SHADER_CONSTANT_SETTING                 = 0x27,
		SET_PROJ_VIEW                               = 0x28,
		APPLY_BULKRENDER_SHADER_RUNTIME_PASS        = 0x29,
		CMD_SET_STENCIL                             = 0x2A,
		SET_SHADER                                  = 0x2B,
		SET_USER_CLIP_PLANE                         = 0x2C,
		SET_CAM_SIDE_VECTOR                         = 0x2D,
		SET_LIGHT_TINT                              = 0x2E,
		SET_WORLD_TRANSFORM                         = 0x2F,
		SET_DYNAMIC_TEXTURE                         = 0x30,
		SET_DYNAMIC_TEXTURE_STACK_NODE              = 0x31,
		SET_BOUND_CONSTANT_SET_HANDLE               = 0x32,
		SET_NUM_POINT_LIGHTS                        = 0x33,
		SET_SHADER_CONTEXT                          = 0x34,
		SET_SHADER_RUNTIME_PASS                     = 0x35,
		SET_MIRROR_TEXTURE                          = 0x36,
		OVERRIDE_VB_OFFSET                          = 0x37,
		SET_BULKRENDER_SHADER_RUNTIME_PASS          = 0x38,
		SET_SHADER_RUNTIME_Z_PASS_INDEX             = 0x39,
		ADD_TO_DYNAMIC_VERTEX_BUFFER                = 0x3A,
		FILL_DYNAMIC_INDEX_BUFFER                   = 0x3B,
		COPY_DYNAMIC_VERTEX_BUFFER                  = 0x3C,
		START_BULK_RENDERING                        = 0x3D,
		SET_BULK_CSM_PASS_ID                        = 0x3E,
		OVERRIDE_DRAW_BULK_INSTANCES                = 0x3F,
		SET_DYNAMIC_VERTEX_BUFFER                   = 0x40,
		SET_OFFSET_INDEX_BUFFER                     = 0x41,
		SET_CB_HANDLE                               = 0x42,
		SET_SEPARATE_ALPHA_BLEND_STATE              = 0x43,
		SET_IMMEDIATE_DYNAMIC_TEXTURE_HANDLE        = 0x44,
		SET_IMMEDIATE_DYNAMIC_TEXTURE               = 0x45,
		OVERRIDE_CULL_MODE                          = 0x46,
		CMD_DRAW_INSTANCED                          = 0x47,
		SET_PREDICATION                             = 0x48,
		SET_Z_PREDICATION                           = 0x49,
		SET_RENDER_PREDICATION                      = 0x4A,
		SET_INSTANCE_PARAMS                         = 0x4B,
		SET_VERTEX_TEXTURE                          = 0x4C,
		SET_VERTEX_TEXTURE_STATE                    = 0x4D,
		SET_CPU_SKINNING_POSITIONS_VB               = 0x4E,
		SET_CPU_SKINNING_NORMALS_VB                 = 0x4F,
		SET_CPU_SKINNING_WEIGHTS_VB                 = 0x50,
		SET_STREAM_DIV_OP                           = 0x51,
		SET_INSTANCE_FREQUENCY                      = 0x52,
		CMD_DRAW_INSTANCED_NONINDEXED               = 0x53,
		SET_VB_OFFSET                               = 0x54,
		START_DRAWING_CPU_SKINNED_ZOMBIES           = 0x55,
		SUBMIT_CPU_SKINNED_ZOMBIES                  = 0x56,
		SET_SKINNING_MATRICES                       = 0x57,
		SET_GPU_ROOT_MATRIX                         = 0x58,
		CMD_WAIT_LABEL                              = 0x59,
		CMD_OCCLUSION_QUERY                         = 0x5A,
		CMD_CALL_HWCMDBUF                           = 0x5B,
		CMD_REF_FAR_COND_OVERRIDE                   = 0x5C,
		SET_CALLBACK_ARRAY                          = 0x5D,
		CALL_CALLBACK                               = 0x5E,
		CMD_START_STRIP                             = 0x5F,
		SET_VERTEX_DECL_EX                          = 0x60,
		CMD_CLEAR_VDE_FLAG                          = 0x61,
		CMD_UPDATE_VDE_FLAG                         = 0x62,
		CMD_CLEAR_TEXTURE_SWITCH                    = 0x63,
		SET_DEPTH_BOUNDS_STATE                      = 0x64,
		CMD_RENDER_IMMEDIATE                        = 0x65,
		SET_CB_PTRS                                 = 0x66,
		OVERRIDE_TEX_OPT                            = 0x67,
		CMD_SET_CS_INPUT                            = 0x68,
		CMD_SET_CS_OUTPUT                           = 0x69,
		CMD_DISPATCH                                = 0x6A,
		CMD_COPY_RESOURCE                           = 0x6B,
		SET_MATERIAL                                = 0x6C,
		CMD_SET_MATERIAL                            = 0x6D,
		UPDATE_DYNAMIC_VERTEX_BUFFER                = 0x6E,
		CMD_COPY_STRUCTURE_COUNT                    = 0x6F,
		CMD_ADD_GPU_SYNC                            = 0x70,
		CMD_CS_TASK_START                           = 0x71,
		CMD_CS_TASK_END                             = 0x72,
		SET_TEXTURE_UNRESOLVED                      = 0x73,
		SET_TEXTURE_STATE_UNRESOLVED                = 0x74,
		SET_TEXTURE2                                = 0x75,
		SET_TEXTURE_STATE2                          = 0x76,
		SET_STRUCTURED_BUFFER_VS                    = 0x77,
		CMD_CLEAR_UAV_FLOAT                         = 0x78,
		CMD_CLEAR_UAV_UINT                          = 0x79,
		SET_MERGED_INDEX_BUFFER                     = 0x7A,
		SET_MERGED_VERTEX_DECL                      = 0x7B,
		CMD_DISPATCH_WITH_NUM_THREADS               = 0x7C,
		CMD_COMMIT_CB                               = 0x7D,
		CMD_DRAW_INDEXED_INSTANCED                  = 0x7E,
		CMD_GPU_WAIT_UNTIL_IDLE                     = 0x7F,
		CMD_NOP                                     = 0xFF,
		fn toString opcode = (
			case opcode of (
				0x00: "CMD_UNDEFINED"
				0x01: "CMD_RET"
				0x02: "CMD_CALL"
				0x03: "CMD_CALL_FAR"
				0x04: "CMD_REF"
				0x05: "CMD_REF_FAR"
				0x06: "CMD_CLEAR"
				0x07: "CMD_DRAW"
				0x08: "CMD_DRAW_INDEXED"
				0x09: "SET_VERTEX_DECL"
				0x0A: "SET_VERTEX_BUFFER"
				0x0B: "SET_INDEX_BUFFER"
				0x0C: "SET_TEXTURE"
				0x0D: "SET_TEXTURE_STATE"
				0x0E: "SET_DRAW_STATE"
				0x0F: "UNUSED_WAS_PARTICLE_DATA"
				0x10: "FILL_DYNAMIC_VERTEX_BUFFER"
				0x11: "SET_CONST_COLOR"
				0x12: "SET_CONST_ALPHA"
				0x13: "SET_NUM_INSTANCES"
				0x14: "SET_STREAM_FREQ"
				0x15: "SET_DEPTH_BIAS"
				0x16: "SET_SHADER_CONSTANT_STACK_NODE"
				0x17: "SET_IMMEDIATE_BOUND_CONSTANT_SET_HANDLE"
				0x18: "SET_VS_CONST"
				0x19: "SET_PS_CONST"
				0x1A: "SET_CB_CONST"
				0x1B: "SET_PS_CONST_IMM"
				0x1C: "OVERRIDE_DRAW_STATE"
				0x1D: "SET_NAMED_EVENT"
				0x1E: "SET_USER_CLIP_PLANES_ENABLED"
				0x1F: "SET_DIFFUSE"
				0x20: "SET_SPEC_VARS"
				0x21: "SET_ENV_REFLECTIVITY"
				0x22: "CMD_NOOP0"
				0x23: "CMD_NOOP2"
				0x24: "OVERRIDE_TEXTURE"
				0x25: "SET_OFFSET_VERTEX_BUFFER"
				0x26: "SET_PARALLAX_PARAMS"
				0x27: "SET_SHADER_CONSTANT_SETTING"
				0x28: "SET_PROJ_VIEW"
				0x29: "APPLY_BULKRENDER_SHADER_RUNTIME_PASS"
				0x2A: "CMD_SET_STENCIL"
				0x2B: "SET_SHADER"
				0x2C: "SET_USER_CLIP_PLANE"
				0x2D: "SET_CAM_SIDE_VECTOR"
				0x2E: "SET_LIGHT_TINT"
				0x2F: "SET_WORLD_TRANSFORM"
				0x30: "SET_DYNAMIC_TEXTURE"
				0x31: "SET_DYNAMIC_TEXTURE_STACK_NODE"
				0x32: "SET_BOUND_CONSTANT_SET_HANDLE"
				0x33: "SET_NUM_POINT_LIGHTS"
				0x34: "SET_SHADER_CONTEXT"
				0x35: "SET_SHADER_RUNTIME_PASS"
				0x36: "SET_MIRROR_TEXTURE"
				0x37: "OVERRIDE_VB_OFFSET"
				0x38: "SET_BULKRENDER_SHADER_RUNTIME_PASS"
				0x39: "SET_SHADER_RUNTIME_Z_PASS_INDEX"
				0x3A: "ADD_TO_DYNAMIC_VERTEX_BUFFER"
				0x3B: "FILL_DYNAMIC_INDEX_BUFFER"
				0x3C: "COPY_DYNAMIC_VERTEX_BUFFER"
				0x3D: "START_BULK_RENDERING"
				0x3E: "SET_BULK_CSM_PASS_ID"
				0x3F: "OVERRIDE_DRAW_BULK_INSTANCES"
				0x40: "SET_DYNAMIC_VERTEX_BUFFER"
				0x41: "SET_OFFSET_INDEX_BUFFER"
				0x42: "SET_CB_HANDLE"
				0x43: "SET_SEPARATE_ALPHA_BLEND_STATE"
				0x44: "SET_IMMEDIATE_DYNAMIC_TEXTURE_HANDLE"
				0x45: "SET_IMMEDIATE_DYNAMIC_TEXTURE"
				0x46: "OVERRIDE_CULL_MODE"
				0x47: "CMD_DRAW_INSTANCED"
				0x48: "SET_PREDICATION"
				0x49: "SET_Z_PREDICATION"
				0x4A: "SET_RENDER_PREDICATION"
				0x4B: "SET_INSTANCE_PARAMS"
				0x4C: "SET_VERTEX_TEXTURE"
				0x4D: "SET_VERTEX_TEXTURE_STATE"
				0x4E: "SET_CPU_SKINNING_POSITIONS_VB"
				0x4F: "SET_CPU_SKINNING_NORMALS_VB"
				0x50: "SET_CPU_SKINNING_WEIGHTS_VB"
				0x51: "SET_STREAM_DIV_OP"
				0x52: "SET_INSTANCE_FREQUENCY"
				0x53: "CMD_DRAW_INSTANCED_NONINDEXED"
				0x54: "SET_VB_OFFSET"
				0x55: "START_DRAWING_CPU_SKINNED_ZOMBIES"
				0x56: "SUBMIT_CPU_SKINNED_ZOMBIES"
				0x57: "SET_SKINNING_MATRICES"
				0x58: "SET_GPU_ROOT_MATRIX"
				0x59: "CMD_WAIT_LABEL"
				0x5A: "CMD_OCCLUSION_QUERY"
				0x5B: "CMD_CALL_HWCMDBUF"
				0x5C: "CMD_REF_FAR_COND_OVERRIDE"
				0x5D: "SET_CALLBACK_ARRAY"
				0x5E: "CALL_CALLBACK"
				0x5F: "CMD_START_STRIP"
				0x60: "SET_VERTEX_DECL_EX"
				0x61: "CMD_CLEAR_VDE_FLAG"
				0x62: "CMD_UPDATE_VDE_FLAG"
				0x63: "CMD_CLEAR_TEXTURE_SWITCH"
				0x64: "SET_DEPTH_BOUNDS_STATE"
				0x65: "CMD_RENDER_IMMEDIATE"
				0x66: "SET_CB_PTRS"
				0x67: "OVERRIDE_TEX_OPT"
				0x68: "CMD_SET_CS_INPUT"
				0x69: "CMD_SET_CS_OUTPUT"
				0x6A: "CMD_DISPATCH"
				0x6B: "CMD_COPY_RESOURCE"
				0x6C: "SET_MATERIAL"
				0x6D: "CMD_SET_MATERIAL"
				0x6E: "UPDATE_DYNAMIC_VERTEX_BUFFER"
				0x6F: "CMD_COPY_STRUCTURE_COUNT"
				0x70: "CMD_ADD_GPU_SYNC"
				0x71: "CMD_CS_TASK_START"
				0x72: "CMD_CS_TASK_END"
				0x73: "SET_TEXTURE_UNRESOLVED"
				0x74: "SET_TEXTURE_STATE_UNRESOLVED"
				0x75: "SET_TEXTURE2"
				0x76: "SET_TEXTURE_STATE2"
				0x77: "SET_STRUCTURED_BUFFER_VS"
				0x78: "CMD_CLEAR_UAV_FLOAT"
				0x79: "CMD_CLEAR_UAV_UINT"
				0x7A: "SET_MERGED_INDEX_BUFFER"
				0x7B: "SET_MERGED_VERTEX_DECL"
				0x7C: "CMD_DISPATCH_WITH_NUM_THREADS"
				0x7D: "CMD_COMMIT_CB"
				0x7E: "CMD_DRAW_INDEXED_INSTANCED"
				0x7F: "CMD_GPU_WAIT_UNTIL_IDLE"
				0xFF: "CMD_NOP"
				default: "CMD_INVALID"
				)
			)
		)
	
	struct dr3MdlCommandBufferEntry_t ( -- 4 + n Bytes
		/*uint8_t[4]*/ cmd = #(0,0,0,0),
		/*void*/data = undefined,
		
		
		fn size = (4 + (data.count * 4)),
		fn read f &ENUM verbose:true = (
			local pos = f.tell()
			local result = true
			cmd = #(f.read_ubyte(), f.read_ubyte(), f.read_ubyte(), f.read_ubyte())
			
			
			case cmd[1] of (
				(ENUM.CMD_RET): ( -- 0x01):
					)
				(ENUM.CMD_CALL): ( -- 0x02): Reads 24-bit operand as jump offset (handled in process_instructions)
					-- No additional data read here; operand is in cmd[2..4]
					)
				(ENUM.CMD_CALL_FAR): ( -- 0x03): Reads 64-bit address from previous instruction
					data = #(
						f.read_ulong(), -- Lower 32 bits
						f.read_ulong()  -- Upper 32 bits
						)
					)
				(ENUM.CMD_REF): ( -- 0x04): Reads 32-bit value from previous instruction (shifted)
					data = #(f.read_ulong())
					)
				(ENUM.CMD_REF_FAR): ( -- 0x05): Reads 64-bit address from previous instruction
					data = #(
						f.read_ulong(), -- Lower 32 bits
						f.read_ulong()  -- Upper 32 bits
						)
					)
				(ENUM.CMD_DRAW): ( -- 0x07): Likely reads vertex and instance counts
					--data = #(
					--	f.read_ulong(), -- Vertex count
					--	f.read_ulong()  -- Instance count
					--	)
					)
				(ENUM.CMD_DRAW_INDEXED): ( -- 0x08): Reads five 32-bit values
					data = #(
						f.read_ulong(),
						f.read_ulong(),
						f.read_ulong(),
						f.read_ulong(),
						f.read_ulong()
						)
					)
				(ENUM.SET_VERTEX_DECL): ( -- 0x09): Reads vertex declaration handle
					--data = #(f.read_ulong())
					)
				(ENUM.SET_VERTEX_BUFFER): ( -- 0x0A): Reads buffer handle and offset
					data = #(
						f.read_ulong(), -- Buffer handle
						f.read_ulong()  -- Offset
						)
					)
				(ENUM.SET_INDEX_BUFFER): ( -- 0x0B): Reads buffer handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_TEXTURE): ( -- 0x0C): Reads texture handle
					--data = #(f.read_ulong())
					)
				(ENUM.SET_TEXTURE_STATE): ( -- 0x0D): Reads texture state handle
					--data = #(f.read_ulong())
					)
				(ENUM.SET_DRAW_STATE): ( -- 0x0E): Reads draw state handle
					--data = #(f.read_ulong())
					)
				(ENUM.FILL_DYNAMIC_VERTEX_BUFFER): ( -- 0x10): Reads buffer handle and size
					data = #(
						f.read_ulong(), -- Buffer handle
						f.read_ulong()  -- Size
						)
					)
				(ENUM.SET_CONST_COLOR): ( -- 0x11): Reads 32-bit color value
					data = #(f.read_ulong())
					)
				(ENUM.SET_CONST_ALPHA): ( -- 0x12): Reads 32-bit alpha value
					data = #(f.read_ulong())
					)
				(ENUM.SET_NUM_INSTANCES): ( -- 0x13): Reads instance count
					data = #(f.read_ulong())
					)
				(ENUM.SET_STREAM_FREQ): ( -- 0x14): Reads one 32-bit value (frequency)
					data = #(f.read_ulong())
					)
				(ENUM.SET_DEPTH_BIAS): ( -- 0x15): Reads depth bias value
					data = #(f.read_ulong())
					)
				(ENUM.SET_SHADER_CONSTANT_STACK_NODE): ( -- 0x16): Reads constant handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_IMMEDIATE_BOUND_CONSTANT_SET_HANDLE): ( -- 0x17): Reads constant handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_VS_CONST): ( -- 0x18): Reads constant index and value
					data = #(
						f.read_ulong(), -- Index
						f.read_ulong()  -- Value
						)
					)
				(ENUM.SET_PS_CONST): ( -- 0x19): Reads constant index and value
					data = #(
						f.read_ulong(), -- Index
						f.read_ulong()  -- Value
						)
					)
				(ENUM.SET_CB_CONST): ( -- 0x1A): Reads constant buffer index and value
					data = #(
						f.read_ulong(), -- Index
						f.read_ulong()  -- Value
						)
					)
				(ENUM.SET_PS_CONST_IMM): ( -- 0x1B): Reads immediate constant value
					data = #(f.read_ulong())
					)
				(ENUM.OVERRIDE_DRAW_STATE): ( -- 0x1C): Reads draw state handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_NAMED_EVENT): ( -- 0x1D): Reads event handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_USER_CLIP_PLANES_ENABLED): ( -- 0x1E): Reads enable flag
					data = #(f.read_ulong())
					)
				(ENUM.SET_DIFFUSE): ( -- 0x1F): Reads diffuse color
					data = #(f.read_ulong())
					)
				(ENUM.SET_SPEC_VARS): ( -- 0x20): Reads specular parameters
					data = #(
						f.read_ulong(), -- Specular power
						f.read_ulong()  -- Specular intensity
						)
					)
				(ENUM.SET_ENV_REFLECTIVITY): ( -- 0x21): Reads reflectivity value
					data = #(f.read_ulong())
					)
				(ENUM.SET_OFFSET_VERTEX_BUFFER): ( -- 0x25): Reads offset
					data = #(f.read_ulong())
					)
				(ENUM.SET_PARALLAX_PARAMS): ( -- 0x26): Reads parallax parameters
					data = #(
						f.read_ulong(), -- Scale
						f.read_ulong()  -- Bias
						)
					)
				(ENUM.SET_SHADER_CONSTANT_SETTING): ( -- 0x27): Reads constant setting handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_PROJ_VIEW): ( -- 0x28): Reads one 32-bit value (likely matrix handle)
					data = #(f.read_ulong())
					)
				(ENUM.APPLY_BULKRENDER_SHADER_RUNTIME_PASS): ( -- 0x29): Reads pass index
					data = #(f.read_ulong())
					)
				(ENUM.CMD_SET_STENCIL): ( -- 0x2A): Reads stencil state
					data = #(f.read_ulong())
					)
				(ENUM.SET_SHADER): ( -- 0x2B): Reads shader handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_USER_CLIP_PLANE): ( -- 0x2C): Reads clip plane parameters
					data = #(
						f.read_ulong(), -- Plane index
						f.read_ulong()  -- Plane data
						)
					)
				(ENUM.SET_CAM_SIDE_VECTOR): ( -- 0x2D): Reads vector data
					data = #(f.read_ulong())
					)
				(ENUM.SET_LIGHT_TINT): ( -- 0x2E): Reads light tint color
					data = #(f.read_ulong())
					)
				(ENUM.SET_WORLD_TRANSFORM): ( -- 0x2F): Reads transform handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_DYNAMIC_TEXTURE): ( -- 0x30): Reads texture handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_DYNAMIC_TEXTURE_STACK_NODE): ( -- 0x31): Reads texture handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_BOUND_CONSTANT_SET_HANDLE): ( -- 0x32): Reads constant handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_NUM_POINT_LIGHTS): ( -- 0x33): Reads light count
					data = #(f.read_ulong())
					)
				(ENUM.SET_SHADER_CONTEXT): ( -- 0x34): Reads context handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_SHADER_RUNTIME_PASS): ( -- 0x35): Reads pass index
					data = #(f.read_ulong())
					)
				(ENUM.SET_MIRROR_TEXTURE): ( -- 0x36): Reads texture handle
					data = #(f.read_ulong())
					)
				(ENUM.OVERRIDE_VB_OFFSET): ( -- 0x37): Reads offset
					data = #(f.read_ulong())
					)
				(ENUM.SET_BULKRENDER_SHADER_RUNTIME_PASS): ( -- 0x38): Reads pass index
					data = #(f.read_ulong())
					)
				(ENUM.SET_SHADER_RUNTIME_Z_PASS_INDEX): ( -- 0x39): Reads pass index
					data = #(f.read_ulong())
					)
				(ENUM.ADD_TO_DYNAMIC_VERTEX_BUFFER): ( -- 0x3A): Reads buffer handle and size
					data = #(
						f.read_ulong(), -- Buffer handle
						f.read_ulong()  -- Size
						)
					)
				(ENUM.FILL_DYNAMIC_INDEX_BUFFER): ( -- 0x3B): Reads buffer handle and size
					data = #(
						f.read_ulong(), -- Buffer handle
						f.read_ulong()  -- Size
						)
					)
				(ENUM.COPY_DYNAMIC_VERTEX_BUFFER): ( -- 0x3C): Reads source and dest handles
					data = #(
						f.read_ulong(), -- Source handle
						f.read_ulong()  -- Destination handle
						)
					)
				(ENUM.SET_BULK_CSM_PASS_ID): ( -- 0x3E): Reads pass ID
					data = #(f.read_ulong())
					)
				(ENUM.OVERRIDE_DRAW_BULK_INSTANCES): ( -- 0x3F): Reads instance count
					data = #(f.read_ulong())
					)
				(ENUM.SET_DYNAMIC_VERTEX_BUFFER): ( -- 0x40): Reads buffer handle and offset
					data = #(
						f.read_ulong(), -- Buffer handle
						f.read_ulong()  -- Offset
						)
					)
				(ENUM.SET_OFFSET_INDEX_BUFFER): ( -- 0x41): Reads offset
					if cmd[3] != 2 do (
						data = #(f.read_ulong())
						)
					)
				(ENUM.SET_CB_HANDLE): ( -- 0x42): Reads constant buffer handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_SEPARATE_ALPHA_BLEND_STATE): ( -- 0x43): Reads blend state handle
					--data = #(f.read_ulong())
					)
				(ENUM.SET_IMMEDIATE_DYNAMIC_TEXTURE_HANDLE): ( -- 0x44): Reads texture handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_IMMEDIATE_DYNAMIC_TEXTURE): ( -- 0x45): Reads texture handle
					data = #(f.read_ulong())
					)
				(ENUM.OVERRIDE_CULL_MODE): ( -- 0x46): Reads cull mode
					data = #(f.read_ulong())
					)
				(ENUM.CMD_DRAW_INSTANCED): ( -- 0x47): Reads vertex and instance counts
					data = #(
						f.read_ulong(), -- Vertex count
						f.read_ulong()  -- Instance count
						)
					)
				(ENUM.SET_PREDICATION): ( -- 0x48): Reads predication handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_Z_PREDICATION): ( -- 0x49): Reads predication handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_RENDER_PREDICATION): ( -- 0x4A): Reads predication handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_INSTANCE_PARAMS): ( -- 0x4B): Reads instance parameters
					data = #(
						f.read_ulong(), -- Parameter 1
						f.read_ulong()  -- Parameter 2
						)
					)
				(ENUM.SET_VERTEX_TEXTURE): ( -- 0x4C): Reads texture handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_VERTEX_TEXTURE_STATE): ( -- 0x4D): Reads texture state handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_CPU_SKINNING_POSITIONS_VB): ( -- 0x4E): Reads buffer handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_CPU_SKINNING_NORMALS_VB): ( -- 0x4F): Reads buffer handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_CPU_SKINNING_WEIGHTS_VB): ( -- 0x50): Reads buffer handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_STREAM_DIV_OP): ( -- 0x51): Reads divisor
					data = #(f.read_ulong())
					)
				(ENUM.SET_INSTANCE_FREQUENCY): ( -- 0x52): Reads frequency
					data = #(f.read_ulong())
					)
				(ENUM.CMD_DRAW_INSTANCED_NONINDEXED): ( -- 0x53): Reads vertex and instance counts
					data = #(
						f.read_ulong(), -- Vertex count
						f.read_ulong()  -- Instance count
						)
					)
				(ENUM.SET_VB_OFFSET): ( -- 0x54): Reads offset
					data = #(f.read_ulong())
					)
				(ENUM.SET_SKINNING_MATRICES): ( -- 0x57): Reads matrix handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_GPU_ROOT_MATRIX): ( -- 0x58): Reads matrix handle
					data = #(f.read_ulong())
					)
				(ENUM.CMD_WAIT_LABEL): ( -- 0x59): Reads label handle
					data = #(f.read_ulong())
					)
				(ENUM.CMD_OCCLUSION_QUERY): ( -- 0x5A): Reads query handle
					data = #(f.read_ulong())
					)
				(ENUM.CMD_CALL_HWCMDBUF): ( -- 0x5B): Reads command buffer handle
					data = #(f.read_ulong())
					)
				(ENUM.CMD_REF_FAR_COND_OVERRIDE): ( -- 0x5C): Reads 64-bit address
					data = #(
						f.read_ulong(), -- Lower 32 bits
						f.read_ulong()  -- Upper 32 bits
						)
					)
				(ENUM.SET_CALLBACK_ARRAY): ( -- 0x5D): Reads array handle
					data = #(f.read_ulong())
					)
				(ENUM.CALL_CALLBACK): ( -- 0x5E): Reads callback index
					data = #(f.read_ulong())
					)
				(ENUM.SET_VERTEX_DECL_EX): ( -- 0x60): Reads vertex declaration handle
					data = #(f.read_ulong())
					)
				(ENUM.CMD_SET_CS_INPUT): ( -- 0x68): Reads input handle
					data = #(f.read_ulong())
					)
				(ENUM.CMD_SET_CS_OUTPUT): ( -- 0x69): Reads output handle
					data = #(f.read_ulong())
					)
				(ENUM.CMD_DISPATCH): ( -- 0x6A): Reads thread group counts
					data = #(
						f.read_ulong(), -- X count
						f.read_ulong(), -- Y count
						f.read_ulong()  -- Z count
						)
					)
				(ENUM.CMD_COPY_RESOURCE): ( -- 0x6B): Reads source and dest handles
					data = #(
						f.read_ulong(), -- Source handle
						f.read_ulong()  -- Destination handle
						)
					)
				(ENUM.SET_MATERIAL): ( -- 0x6C): Reads material handle
					data = #(f.read_ulong())
					)
				(ENUM.CMD_SET_MATERIAL): ( -- 0x6D): Reads material handle
					data = #(f.read_ulong())
					)
				(ENUM.UPDATE_DYNAMIC_VERTEX_BUFFER): ( -- 0x6E): Reads buffer handle and size
					data = #(
						f.read_ulong(), -- Buffer handle
						f.read_ulong()  -- DSize
						)
					)
				(ENUM.CMD_COPY_STRUCTURE_COUNT): ( -- 0x6F): Reads source and dest handles
					data = #(
						f.read_ulong(), -- Source handle
						f.read_ulong()  -- Destination handle
						)
					)
				(ENUM.CMD_CS_TASK_START): ( -- 0x71): 
					)
				(ENUM.SET_TEXTURE_UNRESOLVED): ( -- 0x73): Reads index and hash
					if cmd[3] == 0 do (
						data = #(
							f.read_ulong(), -- Index
							f.read_ulong()  -- Hash
							)
						)
					
					)
				(ENUM.SET_TEXTURE_STATE_UNRESOLVED): ( -- 0x74): Reads index and hash
					data = #(
						f.read_ulong(), -- Index
						f.read_ulong()  -- Hash
						)
					)
				(ENUM.SET_TEXTURE2): ( -- 0x75): Reads texture handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_TEXTURE_STATE2): ( -- 0x76): Reads texture state handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_STRUCTURED_BUFFER_VS): ( -- 0x77): Reads buffer handle
					data = #(
						f.read_ulong(), -- Index
						f.read_ulong()  -- Hash
						)
					)
				(ENUM.CMD_CLEAR_UAV_FLOAT): ( -- 0x78): Reads UAV handle and value
					data = #(
						f.read_ulong(), -- UAV handle
						f.read_ulong()  -- Value
						)
					)
				(ENUM.CMD_CLEAR_UAV_UINT): ( -- 0x79): Reads UAV handle and value
					data = #(
						f.read_ulong(), -- UAV handle
						f.read_ulong()  -- Value
						)
					)
				(ENUM.SET_MERGED_INDEX_BUFFER): ( -- 0x7A): Reads buffer handle
					data = #(f.read_ulong())
					)
				(ENUM.SET_MERGED_VERTEX_DECL): ( -- 0x7B): Reads vertex declaration handle
					data = #(f.read_ulong())
					)
				(ENUM.CMD_DISPATCH_WITH_NUM_THREADS): ( -- 0x7C): Reads thread counts
					data = #(
						f.read_ulong(), -- X count
						f.read_ulong(), -- Y count
						f.read_ulong()  -- Z count
						)
					)
				(ENUM.CMD_COMMIT_CB): ( -- 0x7D): Reads constant buffer handle
					data = #(f.read_ulong())
					)
				(ENUM.CMD_DRAW_INDEXED_INSTANCED): ( -- 0x7E): Reads index and instance counts
					data = #(
						f.read_ulong(), -- Index count
						f.read_ulong()  -- Instance count
						)
					)
				default: (
					format "! New Command Buffer CMD [%]\n" cmd[1]
					print ((pos) as integer)
					result = false
					)
				)
			

			
			result
			),
		fn write s &ENUM = (
			for c in cmd do (s.write_ubyte(c))
			if data != undefined do (
				for d in data do (
					s.write_ulong(d)
					)
				)
			)
		)
	
	struct dr3MdlCommandBuffer_t ( -- variable
		
		/*dr3MdlCommandBufferEntry_t[]*/ entry = #(),
		
		cmd_e = dr3MdlCommandBufferEnum_t(),
		
		fn size = (
			local nsize = 0
			for o in entry do (
				nsize += o.size(cmd_e)
				)
			nsize
			),
		fn read f end_pos &MaskRenderStrip verbose:false = (
			
			local cnt = 0
			local pos = f.tell()
			local cur = 0
			if verbose do format "Start: \t%\n" ((f.tell()) as integer)
			while (cur = f.tell()) < end_pos do (
				
				local o = dr3MdlCommandBufferEntry_t()
				append entry o
				if not (o.read f cmd_e) do exit
				cnt+= 1
				
				cur = cur - pos
				--local end = (((f.tell() - pos + cur) / 4.0) as integer)
				for m in MaskRenderStrip.entry do (
					-- does the address match the MaskRenderStrip Start Position
					
					
					if cur == m.unk027 then (
						m.unk027_index = entry.count
						
						)
					-- does the address match the MaskRenderStrip End Position
					
					else if cur == m.unk027 + (m.unk028 * 4) then (
						
						m.unk028_count = cnt
						cnt = 0
						
						)
					)
				
				)
			

			
			if verbose do format "-------------------------------------------------------\n"
			if verbose do format "End(%): \t%\n" ( cnt ) ((f.tell()) as integer)
			
			),
		fn write s = (for o in entry do (o.write s cmd_e))
		)
	
	struct dr3MdlSceneDescription_t ( -- (n * 16) Bytes
		
		/*char[36][]*/ entry = #(),
		
		fn size = (entry.count * 36),
		fn read f count = (
			entry = #()
			if count > 0 do (
				entry[count] = ""
				for i = 1 to count do (
					entry[i] = f.read_string length:36
					)
				)
			),
		fn write s = (
			for str in entry do (s.write_string str length:36)
			)
		)
	
	struct dr3MdlMatTextureInfoArrayEntry_t ( -- 16 Bytes
		
		/*uint32_t*/ unk120 = 0,
		/*uint32_t*/ unk121 = 0,
		/*uint32_t*/ unk122 = 0,
		/*uint32_t*/ unk123 = 0,
		
		fn read f = (
			
			unk120 = f.read_ulong()
			unk121 = f.read_ulong()
			unk122 = f.read_ulong()
			unk123 = f.read_ulong()
			),
		fn write s = (
			s.write_ulong(unk120)
			s.write_ulong(unk121)
			s.write_ulong(unk122)
			s.write_ulong(unk123)
			)
		)
	
	struct dr3MdlMatTextureInfoArray_t ( -- (n * 16) Bytes
		
		/*dr3MdlMatTextureInfoArrayEntry_t[]*/ entry = #(),
		
		fn size = (16*entry.count),
		fn read f count = (
			entry = #()
			if count > 0 do (
				entry[count] = dr3MdlMatTextureInfoArrayEntry_t()
				for i = 1 to count do (
					entry[i] = dr3MdlMatTextureInfoArrayEntry_t()
					entry[i].read(f)
					)
				)
			),
		fn write s = (for o in entry do o.write(s))
		)
	
	struct dr3MdlMatSamplerInfoArrayEntry_t ( -- 40 Bytes
		
		/*uint32_t*/ unk110 = 0,
		/*uint32_t*/ unk111 = 0,
		/*uint32_t*/ unk112 = 0,
		/*uint32_t*/ unk113 = 0,
		/*uint32_t*/ unk114 = 0,
		/*uint32_t*/ unk115 = 0,
		
		/*float*/ unk116 = 0.0,
		/*float*/ unk117 = 0.0,
		/*float*/ unk118 = 0.0,
		/*float*/ unk119 = 0.0,
		
		fn read f = (
			unk110 = f.read_ulong()
			unk111 = f.read_ulong()
			unk112 = f.read_ulong()
			unk113 = f.read_ulong()
			unk114 = f.read_ulong()
			unk115 = f.read_ulong()
			unk116 = f.read_float()
			unk117 = f.read_float()
			unk118 = f.read_float()
			unk119 = f.read_float()
			),
		fn write s = (
			s.write_ulong(unk110)
			s.write_ulong(unk111)
			s.write_ulong(unk112)
			s.write_ulong(unk113)
			s.write_ulong(unk114)
			s.write_ulong(unk115)
			s.write_float(unk116)
			s.write_float(unk117)
			s.write_float(unk118)
			s.write_float(unk119)
			)
		)
	
	struct dr3MdlMatSamplerInfoArray_t ( -- (n * 40) Bytes
		
		/*dr3MdlMatSamplerInfoArrayEntry_t[]*/ entry = #(),
		fn size = (entry.count * 40),
		fn read f count = (
			entry = #()
			if count > 0 do (
				entry[count] = dr3MdlMatSamplerInfoArrayEntry_t()
				for i = 1 to count do (
					entry[i] = dr3MdlMatSamplerInfoArrayEntry_t()
					entry[i].read(f)
					)
				)
			),
		fn write s = (for o in entry do (s.write(o)))
		)
	
	struct dr3MdlMatParameterArrayEntry_t ( -- 20 Bytes
		
		/*float*/ unk100 = 0.0,
		/*float*/ unk101 = 0.0,
		/*float*/ unk102 = 0.0,
		/*float*/ unk103 = 0.0,
		/*float*/ unk104 = 0.0,
		
		fn read f = (
			unk100 = f.read_float()
			unk101 = f.read_float()
			unk102 = f.read_float()
			unk103 = f.read_float()
			unk104 = f.read_float()
			),
		fn write s = (
			s.write_float(unk100)
			s.write_float(unk101)
			s.write_float(unk102)
			s.write_float(unk103)
			s.write_float(unk104)
			)
		)
	
	struct dr3MdlMatParameterArray_t ( -- (n * 20) Bytes
		
		/*dr3MdlMatParameterArrayEntry_t[]*/ entry = #(),
		
		fn size = (entry.count * 20),
		fn read f count = (
			entry = #()
			if count > 0 do (
				entry[count] = dr3MdlMatParameterArrayEntry_t()
				for i = 1 to count do (
					entry[i] = dr3MdlMatParameterArrayEntry_t()
					entry[i].read(f)
					)
				)
			),
		fn write s = (for o in entry do (s.write(o)))
		)
	
	struct dr3MdlMatArrayEntry_t ( -- 80 Bytes
		
		/*uint32_t*/ unk080 = 0,
		/*uint32_t*/ unk081 = 0, -- hash
		/*uint32_t*/ unk082 = 0,
		/*uint32_t*/ unk083 = 0,
		/*uint32_t*/ unk084 = 0,
		/*uint32_t*/ unk085 = 0,
		/*uint32_t*/ unk086 = 0,
		/*uint32_t*/ unk087 = 0,
		/*uint32_t*/ unk088 = 0,
		/*uint32_t*/ unk089 = 0,
		/*uint32_t*/ unk090 = 0,
		/*uint32_t*/ unk091 = 0,
		/*uint32_t*/ unk092 = 0,
		/*uint32_t*/ unk093 = 0,
		/*uint32_t*/ unk094 = 0,
		/*uint32_t*/ unk095 = 0,
		/*uint32_t*/ unk096 = 0,
		/*uint32_t*/ unk097 = 0,
		/*uint32_t*/ unk098 = 0,
		/*uint32_t*/ unk099 = 0,
		
		fn read f = (
			unk080 = f.read_ulong()
			unk081 = f.read_ulong()
			unk082 = f.read_ulong()
			unk083 = f.read_ulong()
			unk084 = f.read_ulong()
			unk085 = f.read_ulong()
			unk086 = f.read_ulong()
			unk087 = f.read_ulong()
			unk088 = f.read_ulong()
			unk089 = f.read_ulong()
			unk090 = f.read_ulong()
			unk091 = f.read_ulong()
			unk092 = f.read_ulong()
			unk093 = f.read_ulong()
			unk094 = f.read_ulong()
			unk095 = f.read_ulong()
			unk096 = f.read_ulong()
			unk097 = f.read_ulong()
			unk098 = f.read_ulong()
			unk099 = f.read_ulong()
			),
		fn write s = (
			s.write_ulong(unk080)
			s.write_ulong(unk081)
			s.write_ulong(unk082)
			s.write_ulong(unk083)
			s.write_ulong(unk084)
			s.write_ulong(unk085)
			s.write_ulong(unk086)
			s.write_ulong(unk087)
			s.write_ulong(unk088)
			s.write_ulong(unk089)
			s.write_ulong(unk090)
			s.write_ulong(unk091)
			s.write_ulong(unk092)
			s.write_ulong(unk093)
			s.write_ulong(unk094)
			s.write_ulong(unk095)
			s.write_ulong(unk096)
			s.write_ulong(unk097)
			s.write_ulong(unk098)
			s.write_ulong(unk099)
			)
		)
	
	struct dr3MdlMatArray_t ( -- (n * 80) Bytes
		
		/*dr3MdlMatArrayEntry_t[]*/ entry = #(), -- the number of D3DVertexDesc files
		
		fn size = (entry.count * 80),
		fn read f count = (
			entry = #()
			if count > 0 do (
				entry[count] = dr3MdlMatArrayEntry_t()
				for i = 1 to count do (
					entry[i] = dr3MdlMatArrayEntry_t()
					entry[i].read(f)
					)
				)
			),
		fn write s = (for o in entry do (s.write(o)))
		)
	
	struct dr3MdlBufferHeaderEntry_t ( -- 24 Bytes
		
		/*uint32_t*/ unk060 = 0, -- hash of the buffers name, example 'Combined Vertices 44'
		/*uint32_t*/ unk061 = 0,
		/*int32_t*/ unk062 = 0,
		/*uint32_t*/ unk063 = 0, -- count
		/*uint32_t*/ unk064 = 0, -- vertex stride of buffer?
		/*uint32_t*/ unk065 = 0,
		
		fn genHash str = (
			local i,hash=0,lstr = str
			for i = 1 to lstr.count do (
				hash = (bit.CharAsInt lstr[i]) + (bit.shift hash 6) + (bit.shift hash 16) - hash
				)
			hash
			),
		fn read f = (
			unk060 = f.read_ulong()
			unk061 = f.read_ulong()
			unk062 = f.read_long()
			unk063 = f.read_ulong()
			unk064 = f.read_ulong()
			unk065 = f.read_ulong()
			),
		fn write s = (
			s.write_ulong(unk060)
			s.write_ulong(unk061)
			s.write_long (unk062)
			s.write_ulong(unk063)
			s.write_ulong(unk064)
			s.write_ulong(unk065)
			)
		)
	
	struct dr3MdlBufferHeader_t ( -- (n * 24) Bytes
		
		/*dr3MdlBufferHeaderEntry_t[]*/ entry = #(),
		
		fn size = (24 * entry.count),
		fn read f count = (
			entry = #()
			if count > 0 do (
				entry[count] = dr3MdlBufferHeaderEntry_t()
				for i = 1 to count do (
					entry[i] = dr3MdlBufferHeaderEntry_t()
					entry[i].read(f)
					)
				)
			),
		fn write s = (for o in entry do (s.write(o)))
		)
	
	struct dr3MdlDesc2_t ( -- 76 Bytes
		
		/*uint32_t*/ unk040 = 0,
		/*uint32_t*/ unk041 = 0,
		/*uint32_t*/ unk042 = 0,
		/*uint32_t*/ unk043 = 0,
		/*uint32_t*/ unk044 = 0,
		/*uint32_t*/ unk045 = 0, -- how many D3DVertexDesc there are for this mesh group
		/*uint32_t*/ unk046 = 0,
		/*uint32_t*/ unk047 = 0,
		/*float[4]*/ unk048 = #(0.0, 0.0, 0.0, 0.0),
		/*float[4]*/ unk049 = #(0.0, 0.0, 0.0, 0.0),
		/*uint32_t*/ unk050 = 0,
		/*uint32_t*/ unk051 = 0,
		/*uint32_t*/ unk052 = 0,
		
		fn size = (76),
		fn read f = (
			unk040 = f.read_ulong()
			unk041 = f.read_ulong()
			unk042 = f.read_ulong()
			unk043 = f.read_ulong()
			unk044 = f.read_ulong()
			unk045 = f.read_ulong()
			unk046 = f.read_ulong()
			unk047 = f.read_ulong()
			unk048 = #(f.read_float(), f.read_float(), f.read_float(), f.read_float())
			unk049 = #(f.read_float(), f.read_float(), f.read_float(), f.read_float())
			unk050 = f.read_ulong()
			unk051 = f.read_ulong()
			unk052 = f.read_ulong()
			),
		fn write s = (
			s.write_ulong(unk040)
			s.write_ulong(unk041)
			s.write_ulong(unk042)
			s.write_ulong(unk043)
			s.write_ulong(unk044)
			s.write_ulong(unk045)
			s.write_ulong(unk046)
			s.write_ulong(unk047)
			for v in unk048 do s.write_float(v)
			for v in unk049 do s.write_float(v)
			s.write_ulong(unk050)
			s.write_ulong(unk051)
			s.write_ulong(unk052)
			)
		)
	
	struct dr3MdlVDHeaderEntry_t ( -- 16 Bytes
		/*uint32_t*/ unk030 = 0, -- number of entries in D3DVertexDesc
		/*uint32_t*/ unk031 = 0,
		/*uint32_t*/ unk032 = 0, -- hash?
		/*int32_t*/ unk033 = -1,
		
		fn size = (16),
		fn read f = (
			unk030 = f.read_ulong()
			unk031 = f.read_ulong()
			unk032 = f.read_ulong()
			unk033 = f.read_long()
			),
		fn write s = (
			s.write_ulong(unk030)
			s.write_ulong(unk031)
			s.write_ulong(unk032)
			s.write_long (unk033)
			)
		)
	
	struct dr3MdlVDHeader_t ( -- (n * 16) Bytes
		
		/*dr3MdlVDHeaderEntry_t[]*/ entry = #(),
		
		fn size = (16 * entry.count),
		fn read f count = (
			entry = #()
			if count > 0 do (
				entry[count] = dr3MdlVDHeaderEntry_t()
				for i = 1 to count do (
					entry[i] = dr3MdlVDHeaderEntry_t()
					entry[i].read(f)
					)
				)
			),
		fn write s = (for o in entry do (s.write(o)))
		)
	
	struct dr3MdlD3DVertexDescEntry_t ( -- 28 Bytes
		
		/*uint32*/ component = 0,
		/*uint32*/ map_index = 0, -- ?
		/*uint32*/ datatype = 0,
		/*uint32*/ buffer_index = 0, -- ?
		/*int64*/ position = 0,
		/*uint32*/ channel = 0,
		fn getType = (
			case component of (
				0x06: #point3 -- [(readfloat f),(readfloat f),(readfloat f)]
				0x1E: #point4 -- [(readfloat f),(readfloat f),(readfloat f),(readfloat f)]
				default: #UNKNOWN
				)
			),
		fn getDataType = (
			case datatype of (
				0x00: #position
				0x01: #weight
				0x02: #boneid
				0x03: #normal
				0x04: #binormal -- not confirmed
				0x05: #texture
				0x06: #tangent -- not confirmed
				default: #UNKNOWN
				)
			),
		fn read f = (
			component = f.read_ulong()
			map_index = f.read_ulong()
			datatype = f.read_ulong()
			buffer_index = f.read_ulong()
			position = f.read_longlong()
			channel = f.read_ulong()
			),
		fn write s = (
			s.write_ulong(component)
			s.write_ulong(map_index)
			s.write_ulong(datatype)
			s.write_ulong(buffer_index)
			s.write_longlong(position)
			s.write_ulong(channel)
			)
		)
	
	struct dr3MdlD3DVertexDesc_t ( -- (n * 28) Bytes
		
		/*dr3MdlD3DVertexDescEntry_t[]*/ entry = #(),
		
		fn size = (28 * entry.count),
		fn read f count = (
			entry = #()
			if count > 0 do (
				entry[count] = dr3MdlD3DVertexDescEntry_t()
				for i = 1 to count do (
					entry[i] = dr3MdlD3DVertexDescEntry_t()
					entry[i].read(f)
					)
				)
			),
		fn write s = (for o in entry do (s.write(o)))
		)
	
	struct dr3MdlAttribute_t ( -- 4 Bytes
		
		/*uint32_t*/ unk011 = 3,
		
		fn size = (4),
		fn read f = (unk011 = f.read_ulong()),
		fn write s = (s.write_ulong(unk011))
		)
	
	struct dr3MdlBoundingBox_t ( -- 24 Bytes
		
		/*uint32_t*/ bmin = [0.0, 0.0, 0.0],
		/*uint32_t*/ bmax = [0.0, 0.0, 0.0],
		
		fn size = (24),
		fn read f = (
			bmin = [f.read_float(), f.read_float(), f.read_float()]
			bmax = [f.read_float(), f.read_float(), f.read_float()]
			),
		fn write s = (
			for v in bmin do (s.write_float(v))
			for v in bmax do (s.write_float(v))
			)
		)
	
	struct dr3BigFile_t ( -- 28 bytes
		/*uint32_t*/ filename_offset = 0,
		/*uint32_t*/ hash = 0,
		/*uint32_t*/ compressed_size = 0,
		/*uint32_t*/ uncompressed_size = 0,
		/*uint32_t*/ offset = 0,
		/*uint32_t*/ content_id = 0, -- use for typing files
		/*uint32_t*/ compression_flag = 0, -- 0=Raw, 1=Zlib
		
		fn genHash str = (
			local i,hash=0,lstr = toLower str
			for i = 1 to lstr.count do (
				hash = (bit.CharAsInt lstr[i]) + (bit.shift hash 6) + (bit.shift hash 16) - hash
				)
			hash
			),
		
		fn getContentType = (
			case content_id of (
				0x0000: ".nul"
				0x0004: ".hdr"
				0x0010: ".bin"
				0x0020: ".mdl"
				0x0040: ".dat"
				0x0100: ".big"
				0x0200: ".snd"
				0x0800: ".zlb"
				default:".unk"
				)
			),
		fn size = (28),
		fn read f = (
			filename_offset = f.read_ulong()
			hash = f.read_ulong()
			compressed_size = f.read_ulong()
			uncompressed_size = f.read_ulong()
			offset = f.read_ulong()
			content_id = f.read_ulong()
			compression_flag = f.read_ulong()
			),
		fn write s = (
			s.write_ulong(filename_offset)
			s.write_ulong(hash)
			s.write_ulong(compressed_size)
			s.write_ulong(uncompressed_size)
			s.write_ulong(offset)
			s.write_ulong(content_id)
			s.write_ulong(compression_flag)
			)
		)
	
	struct dr3MdlVertex_t ( -- variable
		position = [0.0, 0.0, 0.0],
		normal = [0.0, 0.0, 0.0],
		tangent = [0.0, 0.0, 0.0],
		texcoord0 = [0.0, 0.0, 0.0],
		colour = [0.0, 0.0, 0.0]
		)
	
	struct dr3MdlMesh_t (
		/*dr3MdlDesc2_t*/               desc2                   = dr3MdlDesc2_t(),
		/*dr3MdlMaskRenderStrip_t*/     MaskRenderStrip         = dr3MdlMaskRenderStrip_t(),
		/*dr3MdlVDHeader_t*/            VDHeader                = dr3MdlVDHeader_t(),
		/*dr3MdlCommandBuffer_t*/       CommandBuffer           = dr3MdlCommandBuffer_t(),
		/*dr3MdlD3DVertexDesc_t[]*/     D3DVertexDesc           = #()
		)
	
	struct dr3Mdl_t ( -- collection of files
		
		/*byteArray*/                   unprocesses_files       = #(),
		
		/*drAnimLibSkeleton_t*/         AnimLibSkeleton         = drAnimLibSkeleton_t(),
		/*dr3MdlAttribute_t*/           Attribute               = dr3MdlAttribute_t(),
		/*dr3MdlBoundingBox_t*/         BoundingBox             = dr3MdlBoundingBox_t(),
		
		/*dr3MdlSceneHeader_t*/         SceneHeader             = dr3MdlSceneHeader_t(),
		/*dr3MdlSceneDescription_t*/    SceneDescription        = dr3MdlSceneDescription_t(),
		/*dr3MdlTextureNames_t*/        TextureNames            = dr3MdlTextureNames_t(),
		
		/*dr3MdlMatArray_t*/            MatArray                = dr3MdlMatArray_t(),
		/*dr3MdlMatParameterArray_t*/   MatParameterArray       = dr3MdlMatParameterArray_t(),
		/*dr3MdlMatSamplerInfoArray_t*/ MatSamplerInfoArray     = dr3MdlMatSamplerInfoArray_t(),
		/*dr3MdlMatTextureInfoArray_t*/ MatTextureInfoArray     = dr3MdlMatTextureInfoArray_t(),
		
		/*dr3MdlCommandBuffer_t*/       SharedOpaque            = dr3MdlCommandBuffer_t(),
		/*dr3MdlCommandBuffer_t*/       SharedTransparent       = dr3MdlCommandBuffer_t(),
		/*dr3MdlCommandBuffer_t*/       SharedZPass             = dr3MdlCommandBuffer_t(),
		/*dr3MdlCommandBuffer_t*/       SharedZPassFirst        = dr3MdlCommandBuffer_t(),
		/*dr3MdlCommandBuffer_t*/       SharedZPassSecond       = dr3MdlCommandBuffer_t(),
		
		/*dr3MdlBufferHeader_t*/        Combined_VBHeader       = dr3MdlBufferHeader_t(),
		/*dr3MdlBufferHeader_t*/        Combined_IBHeader       = dr3MdlBufferHeader_t(),
		/*uint16_t*/                    Combined_Indices        = #(), -- I dont store the data just the filetable entry
		/*dr3MdlVertex_t*/              Combined_Vertices       = #(), -- I dont store the data just the filetable entry
		
		/*dr3MdlAttribute_t*/           TotalIBSize             = dr3MdlAttribute_t(),
		/*dr3MdlAttribute_t*/           TotalVBSize             = dr3MdlAttribute_t(),
		
		/*dr3MdlAttribute_t*/           NumLocatorArray         = dr3MdlAttribute_t(),
		/*dr3MdlLocatorArray_t*/        LocatorArray            = dr3MdlLocatorArray_t(),
		
		/*dr3MdlMesh_t*/                meshes = #(),
		
		fn getFileIndex namepattern &filetable &filenames &str_lookup &visitedFiles = (
			local index = 0
			for i = 1 to filetable.count do (
				local x = findItem str_lookup filetable[i].filename_offset
				if x == 0 do continue
				if MatchPattern filenames[x] pattern:namepattern do (
					index = i
					visitedFiles[i] = false
					exit
					)
				)
			index
			),
		
		fn read f &filetable &filenames &str_lookup = (
			
			if filetable.count > 0 then (
				
				local visitedFiles = #{1..(filetable.count)}
				
				local Combined_VBHeaders = #()
				local Combined_IBHeaders = #()
				
				-- SceneHeader
				local SceneHeaderIndex = getFileIndex "SceneHeader" filetable filenames str_lookup &visitedFiles
				if SceneHeaderIndex > 0 then (
					
					f.seek(filetable[SceneHeaderIndex].offset)
					SceneHeader.read(f)
					
					
					-- Attribute
					local AttributeIndex = getFileIndex "_ATTRIBUTE_" filetable filenames str_lookup &visitedFiles
					if AttributeIndex > 0 do (
						f.seek(filetable[AttributeIndex].offset)
						Attribute.read(f)
						)
					
					-- AnimLibSkeleton
					local AnimLibSkeletonIndex = getFileIndex "_ANIMLIB_SKELETON_" filetable filenames str_lookup &visitedFiles
					if AnimLibSkeletonIndex > 0 do (
						f.seek(filetable[AnimLibSkeletonIndex].offset)
						AnimLibSkeleton.read(f)
						)
					
					-- BoundingBox
					local BoundingBoxIndex = getFileIndex "_BOUNDINGBOX_" filetable filenames str_lookup &visitedFiles
					if BoundingBoxIndex > 0 do (
						f.seek(filetable[BoundingBoxIndex].offset)
						BoundingBox.read(f)
						)
					
					-- SceneDescription
					local SceneDescriptionIndex = getFileIndex "SceneDescription" filetable filenames str_lookup &visitedFiles
					if SceneDescriptionIndex > 0 do (
						local SceneDescriptionCount = (filetable[SceneDescriptionIndex].uncompressed_size / 36.0) as integer
						f.seek(filetable[SceneDescriptionIndex].offset)
						SceneDescription.read f SceneDescriptionCount
						)
					
					-- TextureNames
					local TextureNamesIndex = getFileIndex "TextureNames" filetable filenames str_lookup &visitedFiles
					if TextureNamesIndex > 0 do (
						f.seek(filetable[TextureNamesIndex].offset)
						TextureNames.read(f)
						)
					
					-- TotalIBSize
					local TotalIBSizeIndex = getFileIndex "TotalIBSize" filetable filenames str_lookup &visitedFiles
					if TotalIBSizeIndex > 0 do (
						f.seek(filetable[TotalIBSizeIndex].offset)
						TotalIBSize.read(f)
						)
					
					-- TotalVBSize
					local TotalVBSizeIndex = getFileIndex "TotalVBSize" filetable filenames str_lookup &visitedFiles
					if TotalVBSizeIndex > 0 do (
						f.seek(filetable[TotalVBSizeIndex].offset)
						TotalVBSize.read(f)
						)
					
					-- SharedOpaqueCommandBuffer
					local SharedOpaqueCommandBufferIndex = getFileIndex "SharedOpaqueCommandBuffer" filetable filenames str_lookup &visitedFiles
					if SharedOpaqueCommandBufferIndex > 0 do (
						f.seek(filetable[SharedOpaqueCommandBufferIndex].offset)
						--SharedOpaque.read f (filetable[SharedOpaqueCommandBufferIndex].offset + filetable[SharedOpaqueCommandBufferIndex].uncompressed_size)
						)
					
					-- SharedTransparentCommandBuffer
					local SharedTransparentCommandBufferIndex = getFileIndex "SharedTransparentCommandBuffer" filetable filenames str_lookup &visitedFiles
					if SharedTransparentCommandBufferIndex > 0 do (
						f.seek(filetable[SharedTransparentCommandBufferIndex].offset)
						--SharedTransparent.read f (filetable[SharedTransparentCommandBufferIndex].offset + filetable[SharedTransparentCommandBufferIndex].uncompressed_size)
						)
					
					-- SharedZPassCommandBuffer
					local SharedZPassCommandBufferIndex = getFileIndex "SharedZPassCommandBuffer" filetable filenames str_lookup &visitedFiles
					if SharedZPassCommandBufferIndex > 0 do (
						f.seek(filetable[SharedZPassCommandBufferIndex].offset)
						--SharedZPass.read f (filetable[SharedZPassCommandBufferIndex].offset + filetable[SharedZPassCommandBufferIndex].uncompressed_size)
						)
					
					-- SharedZPassFirstCommandBuffer
					local SharedZPassFirstCommandBufferIndex = getFileIndex "SharedZPassFirstCommandBuffer" filetable filenames str_lookup &visitedFiles
					if SharedZPassFirstCommandBufferIndex > 0 do (
						f.seek(filetable[SharedZPassFirstCommandBufferIndex].offset)
						--SharedZPassFirst.read f (filetable[SharedZPassFirstCommandBufferIndex].offset + filetable[SharedZPassFirstCommandBufferIndex].uncompressed_size)
						)
					
					-- SharedZPassSecondCommandBuffer
					local SharedZPassSecondCommandBufferIndex = getFileIndex "SharedZPassSecondCommandBuffer" filetable filenames str_lookup &visitedFiles
					if SharedZPassSecondCommandBufferIndex > 0 do (
						f.seek(filetable[SharedZPassSecondCommandBufferIndex].offset)
						--SharedZPassSecond.read f (filetable[SharedZPassSecondCommandBufferIndex].offset + filetable[SharedZPassSecondCommandBufferIndex].uncompressed_size)
						)
					
					-- MatArray
					local MatArrayIndex = getFileIndex "MatArray" filetable filenames str_lookup &visitedFiles
					if MatArrayIndex > 0 do (
						local MatArrayCount = (filetable[MatArrayIndex].uncompressed_size / 80.0) as integer
						f.seek(filetable[MatArrayIndex].offset)
						MatArray.read f MatArrayCount
						)
					
					-- MatParameterArray
					local MatParameterArrayIndex = getFileIndex "MatParameterArray" filetable filenames str_lookup &visitedFiles
					if MatParameterArrayIndex > 0 do (
						local MatParameterArrayCount = (filetable[MatParameterArrayIndex].uncompressed_size / 20.0) as integer
						f.seek(filetable[MatParameterArrayIndex].offset)
						MatParameterArray.read f MatParameterArrayCount
						)
					
					-- NumLocatorArray
					local NumLocatorArrayIndex = getFileIndex "NumLocatorArray" filetable filenames str_lookup &visitedFiles
					if NumLocatorArrayIndex > 0 do (
						f.seek(filetable[NumLocatorArrayIndex].offset)
						NumLocatorArray.read(f)
						
						-- LocatorArray
						local LocatorArrayIndex = getFileIndex "LocatorArray" filetable filenames str_lookup &visitedFiles
						if LocatorArrayIndex > 0 do (
							local LocatorArrayCount = (filetable[LocatorArrayIndex].uncompressed_size / 52.0) as integer
							f.seek(filetable[LocatorArrayIndex].offset)
							LocatorArray.read f LocatorArrayCount
							)
						)
					
					
					-- MatSamplerInfoArray
					local MatSamplerInfoArrayIndex = getFileIndex "MatSamplerInfoArray" filetable filenames str_lookup &visitedFiles
					if MatSamplerInfoArrayIndex > 0 do (
						local MatSamplerInfoArrayCount = (filetable[MatSamplerInfoArrayIndex].uncompressed_size / 40.0) as integer
						f.seek(filetable[MatSamplerInfoArrayIndex].offset)
						MatSamplerInfoArray.read f MatSamplerInfoArrayCount
						)
					
					-- MatTextureInfoArray
					local MatTextureInfoArrayIndex = getFileIndex "MatTextureInfoArray" filetable filenames str_lookup &visitedFiles
					if MatTextureInfoArrayIndex > 0 do (
						local MatTextureInfoArrayCount = (filetable[MatTextureInfoArrayIndex].uncompressed_size / 16.0) as integer
						f.seek(filetable[MatTextureInfoArrayIndex].offset)
						MatTextureInfoArray.read f MatTextureInfoArrayCount
						)
					
					-- Combined_VBHeader
					local totalVerts = 0
					local vbufferSizes = #()
					local Combined_VBHeaderIndex = getFileIndex "Combined_VBHeader" filetable filenames str_lookup &visitedFiles
					if Combined_VBHeaderIndex > 0 do (
						local Combined_VBHeaderCount = (filetable[Combined_VBHeaderIndex].uncompressed_size / 24.0) as integer
						f.seek(filetable[Combined_VBHeaderIndex].offset)
						Combined_VBHeader.read f Combined_VBHeaderCount
						
						for i = 1 to Combined_VBHeader.entry.count do (
							append Combined_Vertices (
								filetable[getFileIndex ("Combined Vertices " + (Combined_VBHeader.entry[i].unk064 as string)) filetable filenames str_lookup &visitedFiles]
								)
							)
						)
					
					-- Combined_IBHeader
					local Combined_IBHeaderIndex = getFileIndex "Combined_IBHeader" filetable filenames str_lookup &visitedFiles
					if Combined_IBHeaderIndex > 0 do (
						local Combined_IBHeaderCount = (filetable[Combined_IBHeaderIndex].uncompressed_size / 24.0) as integer
						f.seek(filetable[Combined_IBHeaderIndex].offset)
						Combined_IBHeader.read f Combined_IBHeaderCount
						
						for i = 1 to Combined_IBHeader.entry.count do (
							append Combined_Indices (
								filetable[getFileIndex ("Combined Indices " + (Combined_IBHeader.entry[i].unk064 as string)) filetable filenames str_lookup &visitedFiles]
								)
							)
						)
					) else (format "No Scene Header, Not Model?\n")
				
				for element in SceneDescription.entry do (
					
					local o = dr3MdlMesh_t()
					
					local desc2Index = getFileIndex (element + " desc2") filetable filenames str_lookup &visitedFiles
					if desc2Index > 0 do (
						f.seek(filetable[desc2Index].offset)
						o.desc2.read(f)
						
						
						local MaskRenderStripIndex = getFileIndex (element + " MaskRenderStrip") filetable filenames str_lookup &visitedFiles
						if MaskRenderStripIndex > 0 do (
							local MaskRenderStripCount = (filetable[MaskRenderStripIndex].uncompressed_size / 36.0) as integer
							f.seek(filetable[MaskRenderStripIndex].offset)
							o.MaskRenderStrip.read f MaskRenderStripCount
							
							)
						
						local VDHeaderIndex = getFileIndex (element + " VDHeader") filetable filenames str_lookup &visitedFiles
						if VDHeaderIndex > 0 and o.desc2.unk045 > 0 do (
							f.seek(filetable[VDHeaderIndex].offset)
							o.VDHeader.read f o.desc2.unk045
							
							o.D3DVertexDesc = #()
							o.D3DVertexDesc[o.desc2.unk045] = dr3MdlD3DVertexDesc_t()
							for i = 1 to o.desc2.unk045 do (
								
								o.D3DVertexDesc[i] = dr3MdlD3DVertexDesc_t()
								
								local D3DVertexDescIndex = getFileIndex (element + " D3DVertexDesc " + ((i - 1) as string)) filetable filenames str_lookup &visitedFiles
								if D3DVertexDescIndex > 0 do (
									f.seek(filetable[D3DVertexDescIndex].offset)
									o.D3DVertexDesc[i].read f o.VDHeader.entry[i].unk030
									)
								)
							
							local CommandBufferIndex = getFileIndex (element + " CommandBuffer") filetable filenames str_lookup &visitedFiles
							if CommandBufferIndex > 0 do (
								f.seek(filetable[CommandBufferIndex].offset)
								o.CommandBuffer.read f (filetable[CommandBufferIndex].offset + filetable[CommandBufferIndex].uncompressed_size) &o.MaskRenderStrip
								)
							)
						)
					
					append meshes o
					)
				
				
				unprocesses_files = #()
				if visitedFiles.numberSet > 0 do (
					unprocesses_files[visitedFiles.numberSet] = byteArray()
					for i in visitedFiles do (
						f.seek(filetable[i].offset)
						unprocesses_files[i] = byteArray()
						unprocesses_files[i].readFromStream f.bstream fsize:filetable[i].uncompressed_size
						
						local x = findItem str_lookup filetable[i].filename_offset
						if x == 0 do continue
						if matchpattern filenames[x] pattern:"Combined *" do continue
						format "Unused File: \t%\n" filenames[x]
						unprocesses_files[i].filename = filenames[x]
						)
					)
				) else (format "No Files?\n")
			),
		
		fn import_old f mscale:39.3701 = (
			
			print "Building Mesh......"
			
			
			-- clear scene
			delete objects
			
			-- Build each mesh object
			local ENUM = dr3MdlCommandBufferEnum_t()
			
			local VBHeaders = for o in Combined_VBHeader.entry collect o.unk064
			
			local last_vbuf_pos = #(0, 0, 0, 0)
			
			local globalVertArray = #()
			
			
			for m = 1 to meshes.count do (
				
				--if m > 2 do continue
				
				format "\nv---------------- Mesh% ----------------v\n" m
				format "Name: \t%\n" SceneDescription.entry[m]
				-- Interpret each command
				local vertex_starts = #()
				local index_start = 0
				local sm = 1
				
				local vertArray = #()
				local faceArray = #()
				
				format "\nDescription:\n"
				format "\tunk040:   \t%\n" meshes[m].desc2.unk040
				format "\tunk041:   \t%\n" meshes[m].desc2.unk041
				format "\tunk042:   \t%\n" meshes[m].desc2.unk042
				format "\tunk043:   \t%\n" meshes[m].desc2.unk043
				format "\tunk044:   \t%\n" meshes[m].desc2.unk044
				format "\tunk045:   \t%\n" meshes[m].desc2.unk045
				format "\tunk046:   \t%\n" meshes[m].desc2.unk046
				format "\tunk047:   \t%\n" meshes[m].desc2.unk047
				format "\tunk050:   \t0x%\n" (bit.intAsHex meshes[m].desc2.unk050)
				format "\tunk051:   \t0x%\n" (bit.intAsHex meshes[m].desc2.unk051)
				format "\tunk052:   \t% ? reset flag?\n" meshes[m].desc2.unk052
				
				
				for r in meshes[m].MaskRenderStrip.entry do (
					
					format "\nMaskRenderStrip:\n"
					format "\tunk020:   \t%\n"   r.unk020
					format "\tunk021:   \t%\n"   r.unk021
					format "\tunk022:   \t% ? Material index\n"   r.unk022
					format "\tunk023:   \t0x%\n"   (bit.intAsHex r.unk023)
					format "\tunk024:   \t0x%\n"   (bit.intAsHex r.unk024)
					format "\tunk025:   \t%\n"   r.unk025
					format "\tunk026:   \t%\n"   r.unk026
					
					for c = r.unk027_index to r.unk028_count do (
						local cmd = meshes[m].CommandBuffer.entry[c]
						
						case cmd.cmd[1] of (
							(ENUM.CMD_RET): ()
							(ENUM.SET_DRAW_STATE): (
								--if cmd.cmd[4] != 0 do last_vbuf_pos = #(0, 0, 0, 0)
								)
							(ENUM.SET_VERTEX_DECL): ()
							(ENUM.SET_OFFSET_VERTEX_BUFFER): (
								append vertex_starts #(
									cmd.cmd[2], -- VertDesc Index?
									cmd.cmd[3], -- Vertex Stride
									cmd.cmd[4], -- Vertex Flag
									cmd.data[1]   -- Vertex Start Position
									)
								)
							
							(ENUM.SET_OFFSET_INDEX_BUFFER): (
								index_start = cmd.data[1]
								)
							
							(ENUM.CMD_DRAW_INDEXED): (
								
								
								local prim_type = cmd.cmd[2]
								local vertex_count = cmd.data[3]
								local face_count = cmd.data[5]
								
								format "_______________________________\n"
								format "SubMesh%:\n" sm
								
								format "\tprim_type:    \t%\n"    prim_type
								format "\tvertex_count: \t%\n" vertex_count
								format "\tface_count:   \t%\n"   face_count
								
								
								
								-- Retrieve Vertex Buffer Info
								local VertDesc_Index = vertex_starts[sm][1] + 1
								local Vertex_Stride  = vertex_starts[sm][2]
								local Vertex_Flag    = vertex_starts[sm][3]
								local vpos   = vertex_starts[sm][4]
								local VBuf_Index     = findItem VBHeaders Vertex_Stride
								local VBuf_Offset    = Combined_Vertices[VBuf_Index].offset -- Base Offset
								
								format "\tVertDesc_Index: \t%\n"   VertDesc_Index
								format "\tVertex_Stride:  \t%\n"   Vertex_Stride
								format "\tVertex_Flag:    \t0x%\n" (bit.IntAsHex Vertex_Flag)
								format "\tvpos:   \t%\n"   vpos
								format "\tVBuf_Index:     \t%\n"   VBuf_Index
								format "\tVBuf_Offset:    \t%\n"   VBuf_Offset
								format "\tLastVBufPos:    \t%\n"   last_vbuf_pos[VBuf_Index]
								format "\tIBuf_Offset:    \t%\n"   (Combined_Indices[1].offset + (index_start * 2))
								
								-- Construct Vertices
								for v = 1 to vertex_count do (
									
									-- Loop through each vertex component
									for fvf in meshes[m].D3DVertexDesc[VertDesc_Index].entry do (
										
										-- Jump to vertex address
										f.seek(VBuf_Offset + last_vbuf_pos[VBuf_Index] + ((vpos + (v - 1)) * Vertex_Stride) + fvf.position)
										
										
										local val = #(0.0, 0.0, 0.0, 0.0)
										case fvf.datatype of (
											0x06: ( -- 12 Bytes
												val = #(f.read_float(), f.read_float(), f.read_float(), 1.0)
												)
											0x0D: ( -- 8 Bytes
												val = #(f.read_float(), f.read_float(), 0.0, 0.0)
												)
											0x10: ( -- 8 Bytes
												val = #(f.read_float(), f.read_float(), 0.0, 0.0)
												)
											0x1C: ( -- 8 Bytes
												val = #(f.read_short() / 32767.0, f.read_short() / 32767.0, 0.0, 0.0)
												)
											0x1E: ( -- 4 Bytes
												val = #(f.read_byte() / 127.0, f.read_byte() / 127.0, f.read_byte() / 127.0, f.read_byte() / 127.0)
												)
											0x25: ( -- 4 Bytes
												val = #(f.read_byte() / 127.0, f.read_byte() / 127.0, f.read_byte() / 127.0, f.read_byte() / 127.0)
												)
											default: (
												print ("UNKNOWN VERTEX TYPE: \t0x" + (bit.IntAsHex fvf.datatype) + "\n")
												)
											)
										case fvf.component of (
											0x00: ( -- position
												append vertArray ([val[1], -val[3], val[2]] * mscale)
												)
											0x01: ( -- weight
												-- Add weight handling if needed
												)
											0x02: ( -- boneid
												-- Add boneid handling if needed
												)
											0x03: ( -- normal
												-- Add normal handling if needed
												)
											0x04: ( -- binormal
												-- Add binormal handling if needed
												)
											0x05: ( -- texture
												-- Add texture handling if needed
												)
											0x06: ( -- tangent
												-- Add tangent handling if needed
												)
											0x0A: ( -- color?
												-- Add tangent handling if needed
												)
											default: (
												print ("UNKNOWN COMPONENT TYPE: \t0x" + (bit.IntAsHex fvf.component) + "\n")
												)
											)
										)
									
									)
								
								local max_index = 0
								f.seek(Combined_Indices[1].offset + (index_start * 2))
								
								for i = 1 to (face_count / 3) as integer do (
									
									local face = [f.read_ushort(), f.read_ushort(), f.read_ushort()] + 1
									
									for v = 1 to 3 do (
										if face[v] > max_index do (max_index = face[v] as integer)
										)
									
									--append faceArray face
									)
								format "\tMAX_Index:     \t%\n"   max_index
								
								local msh = mesh \
									vertices:vertArray \
									faces:faceArray \
									name:((m as string) + " " + SceneDescription.entry[m])
								
								
								-- patch to get those shoes working... wtfs
								
								last_vbuf_pos[VBuf_Index] += vertex_count * Vertex_Stride
								print (last_vbuf_pos as string)
								
								
								sm += 1
								)
							)
						
						
						
						)
					



					)
				)
			),
		
		fn import f mscale:39.3701 = (
			

			-- clear scene
			delete objects
			
			-- Build each mesh object
			local ENUM = dr3MdlCommandBufferEnum_t()
			
			-- Get Total Number of Vertices
			local total_vertex_count = 0
			for vb in Combined_VBHeader.entry do (
				total_vertex_count += vb.unk063
				)
			
			-- Build a Global Vertex Buffer
			if total_vertex_count > 0 do (
				local globalVertArray = #()
				globalVertArray.count = total_vertex_count
				globalVertArray[total_vertex_count] = [0.0, 0.0, 0.0]
				local gblIdx = 0
				for vb in Combined_VBHeader.entry do (
					globalVertArray[gblIdx+=1] = [0.0, 0.0, 0.0]
					)
				)
			
			-- Build Through the Vertex Buffers
			local globalIndex = 1
			for b = 0 to Combined_VBHeader.entry.count - 1 do (
				local vb = Combined_VBHeader.entry[b + 1]
				
				
				
				
				globalVertArray[gblIdx+=1] = [0.0, 0.0, 0.0]
				
				globalIndex += 1
				)
			
			 -- for tracking vertex positions for each vbuffer
			local VBHeaders = for o in Combined_VBHeader.entry collect o.unk064 -- for lookup
			for m = 1 to meshes.count do ( -- Loop Through Each Mesh / Command Buffer

				
				-- Interpret each command
				local vertex_starts = #()
				local index_start = 0
				local sm = 1
				local Vertex_Last_VBuf = -1

				local ri = 0
				local vertex_counter = 0
				local vpos = 0
				local vertex_pos = for i = 1 to Combined_VBHeader.entry.count collect 0
				for r in meshes[m].MaskRenderStrip.entry do (
					

					
					for c = r.unk027_index to ((r.unk027_index - 1) + r.unk028_count) do (
						local cmd = meshes[m].CommandBuffer.entry[c]
						
						case cmd.cmd[1] of (
							(ENUM.CMD_RET): ()
							(ENUM.SET_DRAW_STATE): (
								--if cmd.cmd[4] != 0 do vertex_pos = #(0, 0, 0, 0)
								)
							(ENUM.SET_VERTEX_DECL): ()
							(ENUM.SET_OFFSET_VERTEX_BUFFER): (
								append vertex_starts #(
									cmd.cmd[2], -- VertDesc Index?
									cmd.cmd[3], -- Vertex Stride
									cmd.cmd[4], -- Vertex Flag
									cmd.data[1] -- Vertex Start Position
									)
								)
							
							(ENUM.SET_OFFSET_INDEX_BUFFER): (
								index_start = cmd.data[1]
								)
							
							(ENUM.CMD_DRAW_INDEXED): (
								local vertArray = #()
								local faceArray = #()
								local prim_type = cmd.cmd[2]
								local vertex_count = cmd.data[3]
								local face_count = cmd.data[5]
								

								
								-- Retrieve Vertex Buffer Info
								local VertDesc_Index = vertex_starts[sm][1] + 1
								local Vertex_Stride  = vertex_starts[sm][2]
								local Vertex_Flag    = vertex_starts[sm][3]
								local vpos   = vertex_starts[sm][4]
								local VBuf_Index     = findItem VBHeaders Vertex_Stride
								local VBuf_Offset    = Combined_Vertices[VBuf_Index].offset -- Base Offset
								
								
								
								
								if Vertex_Last_VBuf == -1 do (
									Vertex_Last_VBuf = VBuf_Index
									)
								
								vertex_pos[VBuf_Index] += vpos
								
								vertex_counter += Combined_VBHeader.entry[VBuf_Index].unk063
								

								
								
								for i = 1 to (face_count / 3) as integer do (
									
									f.seek(Combined_Indices[1].offset + ((index_start + ((i - 1) * 3)) * 2))
									
									-- shift face index
									local face = [f.read_ushort(), f.read_ushort(), f.read_ushort()] + vpos
									
									append faceArray ([1, 2, 3] + ((i - 1) * 3))
									
									-- Construct Vertices
									for j = 1 to 3 do (
										local v = face[j]
										
										-- Loop through each vertex component
										for fvf in meshes[m].D3DVertexDesc[VertDesc_Index].entry do (
											
											-- Jump to vertex address
											f.seek(VBuf_Offset + (v * Vertex_Stride) + fvf.position)
											
											
											local val = #(0.0, 0.0, 0.0, 0.0)
											case fvf.datatype of (
												0x06: ( -- 12 Bytes
													val = #(f.read_float(), f.read_float(), f.read_float(), 1.0)
													)
												0x0D: ( -- 8 Bytes
													val = #(f.read_float(), f.read_float(), 0.0, 0.0)
													)
												0x10: ( -- 8 Bytes
													val = #(f.read_float(), f.read_float(), 0.0, 0.0)
													)
												0x1C: ( -- 8 Bytes
													val = #(f.read_short() / 32767.0, f.read_short() / 32767.0, 0.0, 0.0)
													)
												0x1E: ( -- 4 Bytes
													val = #(f.read_byte() / 127.0, f.read_byte() / 127.0, f.read_byte() / 127.0, f.read_byte() / 127.0)
													)
												0x25: ( -- 4 Bytes
													val = #(f.read_byte() / 127.0, f.read_byte() / 127.0, f.read_byte() / 127.0, f.read_byte() / 127.0)
													)
												default: (
													print ("UNKNOWN VERTEX TYPE: \t0x" + (bit.IntAsHex fvf.datatype) + "\n")
													)
												)
											
											case fvf.component of (
												0x00: ( -- position
													append vertArray ([val[1], -val[3], val[2]] * mscale)
													)
												0x01: ( -- weight
													-- Add weight handling if needed
													)
												0x02: ( -- boneid
													-- Add boneid handling if needed
													)
												0x03: ( -- normal
													-- Add normal handling if needed
													)
												0x04: ( -- binormal
													-- Add binormal handling if needed
													)
												0x05: ( -- texture
													-- Add texture handling if needed
													)
												0x06: ( -- tangent
													-- Add tangent handling if needed
													)
												0x0A: ( -- color?
													-- Add tangent handling if needed
													)
												default: (
													print ("UNKNOWN COMPONENT TYPE: \t0x" + (bit.IntAsHex fvf.component) + "\n")
													)
												)
											)
										
										)
									
									--append faceArray face
									)
								local msh = mesh vertices:vertArray faces:faceArray name:((sm as string) + " " + SceneDescription.entry[m])
								
								
								
								
								
								sm += 1
								)
							)
						
						
						
						)
					



					)
				)
			)







		
		)
	
	struct dr3BctMip_t ( -- 16 bytes
		/*uint32_t*/ dataAddr = 0,  -- uint32
		/*uint32_t*/ dataSize = 0,  -- uint32
		/*uint32_t*/ flags    = 0x80000000,
		/*uint32_t*/ unk09     = 0,
		
		fn read f = (dataAddr=f.read_ulong(); dataSize=f.read_ulong(); flags=f.read_ulong(); unk09=f.read_ulong()),
		fn write s = (s.write_ulong dataAddr; s.write_ulong dataSize; s.write_ulong flags; s.write_ulong unk09)
		)
	
	struct dr3Bct_t (
		sig1 = 0x07, sig2 = 0x01, sig3 = 0x02, sig4 = 0x20,  -- 4 'magic' bytes
		imgWidth = 0, imgHeight = 0,                         -- uint16 each
		imgFormat = 0, fmtVersion = 0xFF,                    -- two uint8
		imgMips = 0, bitsPerPixel = 0,                       -- two uint8
		imgHash = 0, imgInfoAddr = 0,                        -- uint32 each
		unkBuf = #(0x20,0,0,0, 0,0,0,0, 0,0,0,0, 0x20,0,1,0),-- 16 bytes
		unkCount = 16,                                       -- matches above
		imgInfo = #(),                                       -- dr3BctMip_t[]
		
		fn size = (20 + 16 + 4 + imgInfo.count*16),
		fn read f = (
			sig1 = f.read_ubyte(); sig2 = f.read_ubyte(); sig3 = f.read_ubyte(); sig4 = f.read_ubyte()
			imgWidth  = f.read_ushort(); imgHeight = f.read_ushort()
			imgFormat = f.read_ubyte();  fmtVersion = f.read_ubyte()
			imgMips   = f.read_ubyte();  bitsPerPixel = f.read_ubyte()
			imgHash   = f.read_ulong();  imgInfoAddr  = f.read_ulong()
			imgInfo = for i=1 to imgMips collect (
				local o=dr3BctMip_t()
				o.read f
				o
				)
			),

		fn write s = (
			s.write_ubyte sig1; s.write_ubyte sig2; s.write_ubyte sig3; s.write_ubyte sig4
			s.write_ushort imgWidth; s.write_ushort imgHeight
			s.write_ubyte imgFormat; s.write_ubyte fmtVersion
			s.write_ubyte (imgMips = imgInfo.count);  s.write_ubyte bitsPerPixel
			s.write_ulong imgHash;  s.write_ulong imgInfoAddr
			for o in imgInfo do (o.write(s))
			),

		fn mapBctToDxgi fmtID = (
			case fmtID of (
				0x00: 28  -- R8G8B8A8_UNORM
				0x08: 71  -- BC1_UNORM
				0x0A: 77  -- BC3_UNORM
				0x25: 80  -- BC4_UNORM
				0x26: 83  -- BC5_UNORM
				0x27: 95  -- BC6H_UF16
				0x28: 98  -- BC7_UNORM
				0x30: 71  -- DXT1 alias
				0x32: 77  -- DXT5 alias
				0x35: 28
				default: 0 -- UNKNOWN
				)
			),
		
		fn computeHash buffer startIdx endIdx = (
			local h = 0
			for i = endIdx to startIdx by -1 do
				h = (buffer[i] as integer) + (h*0x10001) - h
			h
			),
		
		fn toDDSStream dst = (
			if imgInfo.count > 0 do (
				
				local dxgiFormat = mapBctToDxgi imgFormat
				local isDX10 = (dxgiFormat > 0x40)  -- quick heuristic
				
				dst.write_long 0x20534444          -- "DDS "
				dst.write_long 124                -- header size
				dst.write_long 0x0002100F         -- flags (caps|height|width|pixfmt|mip)
				dst.write_long imgHeight
				dst.write_long imgWidth
				dst.write_long 0                    -- pitchOrLinearSize (filled later)
				dst.write_long 0                    -- depth
				dst.write_long (imgMips-1)          -- mip count in DDS terms
				
				for i=1 to 11 do dst.write_long 0   -- reserved[11]
				if isDX10 then (
					dst.write_long 32          -- size
					dst.write_long 0x00000004  -- flag: FOURCC
					dst.write_long 0x30315844  -- "DX10"
					dst.write_long 0           -- RGB bit count
					dst.write_long 0; dst.write_long 0; dst.write_long 0; dst.write_long 0
					)
				else (
					-- legacy four-character codes or ARGB masks
					local fourCC = case imgFormat of (
						0x30: 0x31545844;  -- "DXT1"
						0x32: 0x35545844;  -- "DXT5"
						0x25: 0x31495441;  -- "ATI1"
						0x26: 0x32495441;  -- "ATI2"
						0x00: 0;           -- RGBA masks
						0x35: 0;
						default: 0
						)
					dst.write_long 32
					dst.write_long (if fourCC!=0 then 0x00000004 else 0x00000041)  -- FOURCC or RGBA
					dst.write_long fourCC
					if fourCC==0 then (
						dst.write_long 32              -- bit count
						dst.write_long 0x00FF0000      -- R
						dst.write_long 0x0000FF00      -- G
						dst.write_long 0x000000FF      -- B
						dst.write_long 0xFF000000      -- A
						)
					else for i=1 to 5 do dst.write_long 0
					)

				dst.write_long 0x00001000           -- DDSCAPS_TEXTURE
				dst.write_long 0x00400008           -- DDSCAPS_COMPLEX|MIPMAP
				dst.write_long 0                    -- DDSCAPS2
				dst.write_long 0; dst.write_long 0  -- reserved2[2]

				if isDX10 do (
					dst.write_long dxgiFormat
					dst.write_long 3        -- DDS_DIMENSION_TEXTURE2D
					dst.write_long 0        -- miscFlag
					dst.write_long imgMips
					dst.write_long 0        -- alphaMode
					)
				
				local dataOffset = dst.tell()
				for ent in imgInfo do (
					dst.seek ent.dataAddr #seek_set
					local block = getBytes ent.dataSize ent.dataAddr  -- helper that grabs raw bytes
					dst.seek 0 #seek_end
					for b in block do dst.write_ubyte b
					)
				)
			),

		fn fromDDSStream src = (
			if src.read_ulong() == 0x20534444 do (
				
				local hdrSize = src.read_ulong()
				local flags   = src.read_ulong()
				imgHeight     = src.read_ulong()
				imgWidth      = src.read_ulong()
				src.read_ulong()  -- skip pitch
				src.read_ulong()  -- skip depth
				imgMips       = (src.read_ulong() as integer) + 1
				
				for i=1 to 11 do src.read_ulong()  -- reserved
				
				local pfSize  = src.read_ulong()
				local pfFlags = src.read_ulong()
				local fourCC  = src.read_ulong()

				if fourCC == 0x30315844 then (
					-- DX10 extended header
					src.seek 20 #seek_cur  -- skip masks
					imgFormat = case src.read_ulong() of (
						28: 0x00
						71: 0x08
						77: 0x0A
						80: 0x25
						83: 0x26
						95: 0x27
						98: 0x28
						default:0x00
						)
					src.seek (src.tell()+12) #seek_set
					)
				else (
					imgFormat = case fourCC of (
						0x31545844: 0x30
						0x35545844: 0x32
						0x31495441: 0x25
						0x32495441: 0x26
						0: 0x35
						default:0x35
						)
					src.seek (src.tell()+20) #seek_set
					)

				src.read_ulong(); src.read_ulong(); src.read_ulong(); src.read_ulong() -- caps
				src.read_ulong() -- caps2
				src.read_ulong(); src.read_ulong()

				local dataOffset = src.tell()

				local bpp = case imgFormat of (
					0x00:32; 0x35:32; 0x08:4; 0x25:4; 0x30:4;  -- BC1 / RGBA
					default:8
					)
				bitsPerPixel = bpp
				imgInfo = #()
				local w = imgWidth; local h = imgHeight; local pos = dataOffset
				for i=1 to imgMips do (
					local sz = (w*h*bpp)/8
					local ent = dr3BctMip_t dataAddr:pos dataSize:sz
					append imgInfo ent
					pos += sz
					w = amax 1 (w/2); h = amax 1 (h/2)
					)

				/* ---------- fill the rest of the header -------------- */
				fmtVersion  = 0xFF
				sig4        = 0x20
				imgHash     = computeHash (src.bstream) dataOffset (src.size-1)
				imgInfoAddr = 32  -- our header size without padding
				unkCount    = 16
				unkBuf      = #(0x20,0,0,0, 0,0,0,0, 0,0,0,0, 0x20,0,1,0)

				)
			)
		)
	
	struct dr3Big_t ( -- archive, can have any purpose
		
		/*uint32_t*/ magic = 0x03040506,
		/*uint32_t*/ data_offset = 0,
		/*uint32_t*/ filesize = 0, -- may be larger then actual physical size of file?
		/*uint32_t*/ filecount = 0,
		/*uint32_t*/ filetable_offset = 0,
		/*uint32_t*/ stringtable_offset = 0,
		/*dr3BigFile_t[]*/ filetable = #(),
		/*Char[][]*/ filenames = #(), -- string buffer, each string read until NULL then the buffer is padded to 4 bytes?
		
		/*dr3Mdl_t*/ mdl = undefined,
		
		fn read f dumpPath:"" = (
			f.setEndian #little
			magic = f.read_ulong()
			if magic == 0x03040506 then (
				data_offset = f.read_ulong()
				filesize = f.read_ulong() 
				filecount = f.read_ulong()
				filetable_offset = f.read_ulong()
				stringtable_offset = f.read_ulong()
				filetable = #()
				if filecount > 0 do (
					filetable[filecount] = dr3BigFile_t()
					for i = 1 to filecount do (
						filetable[i] = dr3BigFile_t()
						filetable[i].read(f)
						--print filetable[i]
						)
					)
				filenames = #()
				local str_lookup = #()
				while f.tell() < data_offset do (
					append str_lookup (f.tell())
					local str = f.read_string()
					append filenames str
					)
				dumpPath=""
				if dumpPath != undefined and dumpPath != "" then (
					
					local str_end = subString dumpPath dumpPath.count 1
					if str_end != "\\" or str_end != "/" do (
						dumpPath += "\\"
						)
					
					if not doesFileExist dumpPath do (
						makeDir dumpPath
						)
					
					for file in filetable do (
						
						local x = findItem str_lookup file.filename_offset
						if x == 0 do continue
						
						
						
						f.seek(file.offset)
						fseek f.bstream file.offset #seek_set
						local s = try(fopen (dumpPath + filenames[x] + file.getContentType()) "wb")catch(undefined)
						if s != undefined do (
							
							-- Would Need to Check compression flag here
							if file.compression_flag == 1 do (
								print "use the zlib decompressor here"
								)
							-- else
							
							local count = (file.compressed_size / 4) as integer
							local leftover = (mod file.compressed_size 4) as integer
							if (count + leftover) > 0 do (
								for i = 1 to count do (writeLong s (readLong f.bstream))
								for i = (1 + count) to (count + leftover) do (writeByte s (readByte f.bstream))
								)
							fclose s
							)
						)
					print "dump complete"
					)
				else if findItem filenames "SceneHeader" > 0 then (
					mdl = dr3Mdl_t()
					mdl.read f filetable filenames str_lookup
					mdl.import(f)
					print "Read Completed"
					) 
				else (
					format "Failed to Located SceneHeader, Not a Model?\n"
					print "files:"
					print filenames
					)
				
				
				) else (format "unsupported file {%}\n" (bit.IntAsHex magic))
			)
		)
-- 	struct dr3Tex_t (
-- 		
-- 		
-- 		)
	struct dr3Package_t (
		big = dr3Big_t(),
		--tex = dr3Tex_t(),
		fn open file = (
			if file != undefined and file != "" do (
				local fname = getFilenameFile file
				local fpath = getFilenamePath file
				
				
				local bfile = fpath + fname + ".big"
				
				if doesFileExist bfile do (
					
					local f = bytestream()
					if f.open(bfile) do (
						local big = dr3Big_t()
						
						big.read f-- dumpPath:("G:\\SteamLibrary\\steamapps\\common\\deadrising3\\_DUMP\\" + fname + "\\")
						
						)
					

					)
				)
			
			)
		)
	fn read file = (
		local dr3asset = dr3Package_t()
		dr3asset.open(file)
		)
	)
--CreateDialog dr3_util
dr3_util.read(
	"G:\\SteamLibrary\\steamapps\\common\\deadrising3\\_DUMP\\boss_01.big"
-- 	"G:\\SteamLibrary\\steamapps\\common\\deadrising3\\_DUMP\\cast_04.big"
-- 	"G:\\SteamLibrary\\steamapps\\common\\deadrising3\\_DUMP\\svr_30.big"
-- 	"G:\\SteamLibrary\\steamapps\\common\\deadrising3\\_DUMP\\cine_zombee.big"
-- 	"G:\\SteamLibrary\\steamapps\\common\\deadrising3\\_DUMP\\boss_02 (2).big"
-- 	"G:\\SteamLibrary\\steamapps\\common\\deadrising3\\_DUMP\\grapes.big"
	"G:\\SteamLibrary\\steamapps\\common\\deadrising3\\_DUMP\\BIG\\legs_fembusiness_m0.big"
	"G:\\SteamLibrary\\steamapps\\common\\deadrising3\\_DUMP\\BIG\\feeto_hawaiian_m0.big"
	"G:\\SteamLibrary\\steamapps\\common\\deadrising3\\_DUMP\\BIG\\dlc_sonya_paddock.big"
-- 	"G:\\SteamLibrary\\steamapps\\common\\deadrising3\\_DUMP\\BIG\\f_trucker_m1_0_ch_00.big"
-- 	"G:\\SteamLibrary\\steamapps\\common\\deadrising3\\_DUMP\\BIG\\Z001_Tree70Shape.big"
	getOpenFileName()
	)