import Foundation

public typealias TimeUnitType = UnitDuration

public extension TimeUnitType {
    @nonobjc static var days = TimeUnitType(symbol: "days", converter: UnitConverterLinear(coefficient: 24*60*60))
    @nonobjc static var weeks = TimeUnitType(symbol: "weeks", converter: UnitConverterLinear(coefficient: 7*24*60*60))
}

//********************************************************************************
//
// This source is Copyright (c) 2013 by Solinst Canada.  All rights reserved.
//
//********************************************************************************
/**
    A general-purpose rate object that has units of seconds, minutes,
    hours, and days.  Methods exist to convert the rate to a string
    and read/save the rate from/to an encoded stream.  Convenience
    methods provide an interface to steppers and scroll wheels.
 
    - Author:   Michael Griebling
    - Date:   22 June 2014
     
******************************************************************************** */

public struct Rate {
    
    public typealias Time = Measurement<TimeUnitType>

	private static let MAX_TIME =  99.0
	private static let HUNDREDS = 100.0
    
    public static let MaxTimeLimit    = Time(value: MAX_TIME, unit: .weeks).converted(to: .seconds)
    public static let MaxDaysLimit    = Time(value: MAX_TIME, unit: .days).converted(to: .seconds)
    public static let MaxHoursLimit   = Time(value: MAX_TIME, unit: .hours).converted(to: .seconds)
    public static let MaxMinutesLimit = Time(value: MAX_TIME, unit: .minutes).converted(to: .seconds)
    public static let MaxSecondsLimit = Time(value: MAX_TIME, unit: .seconds)
    public static let MinTimeLimit    = Time(value: 0, unit: .seconds)

    public static let MINUTES  = Time(value: 1, unit: .minutes).converted(to: .seconds).value
    public static let HOURS    = Time(value: 1, unit: .hours).converted(to: .seconds).value
    public static let DAYS     = Time(value: 1, unit: .days).converted(to: .seconds).value
    public static let WEEKS	   = Time(value: 1, unit: .weeks).converted(to: .seconds).value
    
    private static let ONE_EIGHTH      = (1.0/8.0)
    private static let ONE_HALF        = (1.0/2.0)
	private static let STR_PAUSE       = NSLocalizedString("Pause", comment: "Schedule pause")
	private static let STR_ONE_EIGHTH  = NSLocalizedString("⅛", comment: "1/8 second")
	private static let STR_ONE_HALF    = NSLocalizedString("½", comment: "1/2 second")
	
    public static var useAbbreviations = false
    
	// MARK: - Basic attributes
	public var allowPause: Bool              // sets a pause for time <= 0
    private var time : Time                  // use Apple's Measurement UnitDuration for time
    private var minTime = Rate.MinTimeLimit  // and the minimum/maximum limits
    private var maxTime = Rate.MaxTimeLimit
    
    // 'units' for 'time'
    public var units: TimeUnitType { return time.unit }
    
    public var timeSeconds: TimeInterval {  // time in fractional seconds
        get { return time.converted(to: .seconds).value }
        set { time = Time(value: newValue, unit: .seconds).converted(to: time.unit) }
    }
	
	//********************************************************************************
	/**
	   Get/set the minimum time limit to *minimumSeconds*.  The maximum value
	          of the minimum is limited to *MAX_TIME* weeks.
     
	    - Author:   Michael Griebling
	    - Date:   	28 March 2013
     
     ******************************************************************************** */
    public var minimumSeconds: TimeInterval {
        set {
            let newMinimum = Time(value: newValue, unit: .seconds)
            if newMinimum <= Rate.MaxTimeLimit && newMinimum >= Rate.MinTimeLimit {
                minTime = newMinimum
            }
            if newMinimum > maxTime { maxTime = newMinimum }
            if timeSeconds < minTime.value && !allowPause {
                timeSeconds = minTime.value
            }
        }
        get { return minTime.converted(to: .seconds).value }
    }
	
	//********************************************************************************
	/**
	   Set the maximum time limit to *maximumSeconds*.  The maximum value
	          is limited to *MAX_TIME* weeks.
     
	    - Author:   Michael Griebling
	    - Date:   	8 April 2013
     
     ******************************************************************************** */
	public var maximumSeconds: TimeInterval {
        set {
            let newMaximum = Time(value: newValue, unit: .seconds)
            if newMaximum <= Rate.MaxTimeLimit && newMaximum >= Rate.MinTimeLimit {
                maxTime = newMaximum
            }
            if timeSeconds > maxTime.value {
                timeSeconds = maxTime.value
            }
        }
        get { return maxTime.converted(to: .seconds).value }
	}
	
	// MARK: - Default constructors
	
	//********************************************************************************
	/**
	   Initialize a Rate object with a given *time* and *units*.
     
	    - Author:   Michael Griebling
	    - Date:   	28 March 2013
     
     ******************************************************************************** */
	public init (time: Int, andUnits units: TimeUnitType) {
        let limit = Int(Rate.MAX_TIME)
        assert(time <= limit, "Time must be ≤ \(limit)")
        self.init(time: Time(value: Double(time), unit: units))
	}
	
	//********************************************************************************
	/**
	   Initialize a Rate object with a given *rawTime* in hundredths of seconds.
     
	    - Author:   Michael Griebling
	    - Date:   	28 March 2013
     
     ******************************************************************************** */
    public init (rawTime: TimeInterval) {
        let rawTime = max(0, rawTime)
        let units = Rate.getUnitsForRawTime(rawTime)
        let time = Time(value: Rate.getSecondsFrom(rawTime: rawTime), unit: .seconds).converted(to: units)
        self.init(time: time)
	}
    
    //********************************************************************************
    /**
         Initialize the rate from seconds.
         
            - Author:   Michael Griebling
            - Date:   	28 March 2013
     
     ******************************************************************************** */
    public init (seconds : TimeInterval) {
        if seconds > 99 {
            let rawtime = floor(seconds * Rate.HUNDREDS)
            self.init(rawTime: rawtime)
        } else {
            self.init(time: Time(value: seconds, unit: .seconds))
        }
    }

	//********************************************************************************
	/**
	   Designated initializer for the Rate object.
     
	    - Author:   Michael Griebling
	    - Date:   	28 March 2013
     
     ******************************************************************************** */
    public init (time: Time) {
		self.time = time
		self.allowPause = time.value < Rate.ONE_EIGHTH
        minTime = Time(value: Rate.ONE_EIGHTH, unit: .seconds)
        maxTime = Rate.MaxTimeLimit
	}
	
	
	// MARK: - Utility routines
	
	//********************************************************************************
	/**
	   Returns a preferred time unit for the raw time *num*.
     
	    - Author:   Michael Griebling
	    - Date:   	2 April 2013
     
     ******************************************************************************** */
	private static func getUnitsForRawTime(_ num: TimeInterval) -> TimeUnitType {
        let MAX        = Int(MAX_TIME)
        let SECSPERMIN = Int(MINUTES)
        let MINSPERHR  = Int(HOURS / MINUTES)
        let HRSPERDAY  = Int(DAYS / HOURS)
        let DAYSPERWK  = Int(WEEKS / DAYS)
		var unit: TimeUnitType = .seconds   // default is seconds
        var num = Int(num / HUNDREDS)
		if num == 0 { return unit }
		if num % SECSPERMIN == 0 || num > MAX {
			unit = .minutes                 // assume units are minutes
			num /= SECSPERMIN
			if num % MINSPERHR == 0 || num > MAX {
				unit = .hours               // assume units are in hours
				num /= MINSPERHR
				if num % HRSPERDAY == 0 || num > MAX {
					unit = .days
					num /= HRSPERDAY
					if num % DAYSPERWK == 0 || num > MAX {
						unit = .weeks
						num /= DAYSPERWK
					}
				}
			}
		}
		return unit
	}
	
	//********************************************************************************
	/**
	   Converts a *rawTime* in hundredths of seconds to an *NSTimeInterval*
	          in seconds.  Note: 1/8 second is correctly handled.
     
	    - Author:   Michael Griebling
	    - Date:   	28 March 2013
     
     ******************************************************************************** */
	public static func getSecondsFrom(rawTime: TimeInterval) -> TimeInterval {
		let time = max(0, rawTime)
		if rawTime > 0 {
			if rawTime < HUNDREDS/2 { return ONE_EIGHTH }   // 1/8 sampling rate
		}
		return time / HUNDREDS
	}
	
	//********************************************************************************
	/**
	   Gets a raw time in hundredths of seconds from the *seconds* time.
     
	    - Author:   Michael Griebling
	    - Date:   	28 March 2013
     
     ******************************************************************************** */
	private func getRawTimeFromSeconds(_ seconds: TimeInterval) -> TimeInterval {
		return floor(seconds * Rate.HUNDREDS)
	}
	
	//********************************************************************************
	/**
	   Set the rate from the *rawTime*.  The internal units are determined
	          based on the magnitude of the raw time.
     
	    - Author:   Michael Griebling
	    - Date:   	28 March 2013
     
     ******************************************************************************** */
	private mutating func setRawTime(_ rawTime: TimeInterval) {
        let units = Rate.getUnitsForRawTime(rawTime)
        time = Time(value: Rate.getSecondsFrom(rawTime: rawTime), unit: .seconds).converted(to: units)
	}
	
    //********************************************************************************
    /**
         Returns a date formatter for use by this class and derived objects.
         
            - Author:   Michael Griebling
            - Date:   	28 March 2013
     
     ******************************************************************************** */
	 @nonobjc public static let dateComponentsFormatter: DateComponentsFormatter = {
		let formatter = DateComponentsFormatter()
		formatter.unitsStyle = .full
		return formatter
	}()
	
	//********************************************************************************
	/**
        Returns a units string for any *TimeUnitType* in *units* with a
	    plural extension based on the *time*.  An abbreviated string is
		returned when *abbreviated* is *true*.
     
	    - Author:   Michael Griebling
	    - Date:   	28 March 2013
     
     ******************************************************************************** */
	public func stringFromUnits(_ units: TimeUnitType, andTime time: Int, abbreviated: Bool = Rate.useAbbreviations) -> String {
		let formatter = Rate.dateComponentsFormatter
		var components = DateComponents()
		if abbreviated { formatter.unitsStyle = .abbreviated }
        if units == .seconds { components.second = time }
        if units == .minutes { components.minute = time }
        if units == .hours   { components.hour = time }
        if units == .days    { components.day = time }
        if units == .weeks   { components.weekOfMonth = time }
		if let string = formatter.string(from: components) {
			// remove numbers and spaces from the string
			return string.trimmingCharacters(in: CharacterSet.decimalDigits)
				.trimmingCharacters(in: CharacterSet.whitespaces)
		}
		return ""
	}
	
	//********************************************************************************
	/**
	    Returns a short version of the units string for any *TimeUnitType*
	           in *units*.
     
	   - Author:   Michael Griebling
	     - Date:   	28 March 2013
     
     ******************************************************************************** */
	public func shortStringFromUnits(_ units: TimeUnitType) -> String {
		return stringFromUnits(units, andTime: 1, abbreviated: true)
	}

	
	// MARK: - Getters/Setters
	
	//********************************************************************************
	/**
        Setter to set the rate's time from *time* seconds.  The internal
	    time is clamped to the rate's minimum time.
     
	    - Author:   Michael Griebling
	    - Date:   	28 March 2013
     
     ******************************************************************************** */
	private mutating func makeTimeSeconds (_ time: TimeInterval) {
		// clamp to minimum time
        let time = min(maximumSeconds, max(minimumSeconds, time))
		if time > Rate.MAX_TIME {
			// re-evaluate the units we're using
			setRawTime(time * Rate.HUNDREDS)
		} else {
            self.time = Time(value: time, unit: .seconds)
		}
	}
	
	//********************************************************************************
	/**
	   Get/set the rate's internal time scaled by the active units.  For example,
	          if the internal time = 180 seconds and the time units are minutes,
	          the returned value would be three.
     
	    - Author:   Michael Griebling
	    - Date:   	28 March 2013
     
     ******************************************************************************** */
	public var timeUnits : Int {
		get {
			// get the current time assuming display units are in use
			return Int(round(time.value))
		}
		set (newTime) {
			time = Time(value: Double(newTime), unit: time.unit)  //Double(newTime) * Rate.scale[units.rawValue]
		}
	}

	//********************************************************************************
	/**
	   Set the rate based on the *time* and *units* where 1 ≤ *time* ≤ 99.

            - Author:   Michael Griebling
            - Date:   	28 March 2013
     
     ******************************************************************************** */
	private mutating func setTime (_ time: Int, andUnits units: TimeUnitType) {
        self.time = Time(value: Double(min(max(1, time), Int(Rate.MAX_TIME))), unit: units) // clamp between 1 and 99
	}
	
	//********************************************************************************
	/**
	    Returns an array of time unit strings with a possibly blank initial
        position for the pause.
     
             - Author:   Michael Griebling
             - Date:   	2 April 2013
     
     ******************************************************************************** */
	public var timeUnitsArray : [String] {
		var labels = [String]()
		if allowPause { labels = [""] }     // no units for pause
		labels.append(stringFromUnits(.seconds, andTime:timeUnits))
		if maximumSeconds > Rate.MINUTES { labels.append(stringFromUnits(.minutes, andTime:timeUnits)) }
		if maximumSeconds > Rate.HOURS   { labels.append(stringFromUnits(.hours, andTime:timeUnits)) }
		if maximumSeconds > Rate.DAYS	 { labels.append(stringFromUnits(.days, andTime:timeUnits)) }
		if maximumSeconds > Rate.WEEKS	 { labels.append(stringFromUnits(.weeks, andTime:timeUnits)) }
		return labels
	}
	
	public var rawTime: TimeInterval { return getRawTimeFromSeconds(timeSeconds) }	// raw time in 1/100 of a second
	
	// MARK: - Support for scrollwheels
	
	//********************************************************************************
	/**
	   Returns the maximum time index for a scroll wheel based on the active rate.
     
	    - Author:   Michael Griebling
	    - Date:   	2 April 2013
     
     ******************************************************************************** */
	public var maxIndexForTime : Int {
		var maxIndex = Int(Rate.MAX_TIME)                       // default for non-seconds
		if units == .seconds {
			if allowPause { maxIndex += 1 }						// make room for pause
			if minimumSeconds < 1.0 {
				if minimumSeconds < Rate.ONE_HALF { maxIndex += 1 } // make room for 1/8 second
				maxIndex += 1                                       // make room for 1/2 second
			} else {
				// minimum time must be less than MAX_TIME
				maxIndex -= max(0, Int(minimumSeconds)-1)
			}
		} else {
            if      time.unit == .minutes { maxIndex = min(maxIndex, Int((maxTime / Rate.MINUTES).value)) }
			else if time.unit == .hours   { maxIndex = min(maxIndex, Int((maxTime / Rate.HOURS).value)) }
            else if time.unit == .days    { maxIndex = min(maxIndex, Int((maxTime / Rate.DAYS).value)) }
			else if time.unit == .weeks   { maxIndex = min(maxIndex, Int((maxTime / Rate.WEEKS).value)) }
		}
		return maxIndex
	}
	
	//********************************************************************************
	/**
	   Returns a maximum unit index for a scroll wheel based on the active rate.
     
	    - Author:   Michael Griebling
	    - Date:   	2 April 2013
     
     ******************************************************************************** */
	public var maxIndexForUnits : Int {
		var maxIndex = Rate.timeUnits.count // TimeUnitType.week.rawValue+1
		if maxTime < Rate.MaxTimeLimit    { maxIndex -= 1 }
		if maxTime < Rate.MaxDaysLimit    { maxIndex -= 1 }
		if maxTime < Rate.MaxHoursLimit   { maxIndex -= 1 }
		if maxTime < Rate.MaxMinutesLimit { maxIndex -= 1 }
		if allowPause                     { maxIndex += 1 } // make room for blank pause units
		return maxIndex
	}
	
	//********************************************************************************
	/**
	   Returns the time index for a scroll wheel that corresponds to the active rate.
     
	    - Author:   Michael Griebling
	    - Date:   	2 April 2013
     
     ******************************************************************************** */
	public var timeIndex : Int {
		var index = max(0, timeUnits-1)                      // default for non-seconds
		if units == .seconds {
			let time = timeSeconds
			if allowPause {
				if (time == 0) { return 0 }                  // pause
				index += 1
			}
			if minimumSeconds < 1.0 {
				if minimumSeconds < Rate.ONE_HALF {
					if time < Rate.ONE_HALF { return index } // 1/8 second
					index += 1
				}
				if time < 1.0 { return index }               // 1/2 second
				index += 1
			} else {
				index -= Int(floor(minimumSeconds)-1)
			}
		}
		return max(0, index)
	}
	
	//********************************************************************************
	/**
	   Returns a unit index for a scroll wheel that corresponds to the active rate.
     
	    - Author:   Michael Griebling
	    - Date:   	2 April 2013
     
     ******************************************************************************** */
	public var unitIndex : Int {
        var index = Rate.timeUnits.firstIndex { $0 == units } ?? 0   // find units index in timeUnits
		if allowPause && timeSeconds > 0 { index += 1 }         // make room for blank pause units
		return index
	}
	
	//********************************************************************************
	/**
	   Returns a time value string for a given scroll wheel index.
     
	    - Author:   Michael Griebling
	    - Date:   	2 April 2013
     
     ******************************************************************************** */
	public func stringForTimeIndex(_ index: Int) -> String {
		var offset = 1
        var index = index
		if units == .seconds {
			let times = getTimeFractions()
			if index < times.count {
				return times[index]
			} else {
				index -= times.count-1
			}
			offset = max(0, Int(floor(minimumSeconds)-1))
		}
		return String.localizedStringWithFormat("%ld", index+offset)
	}
	
	//********************************************************************************
	/**
	   Returns a unit string for a given scroll wheel index.
     
	    - Author:   Michael Griebling
	    - Date:   	2 April 2013
     
     ******************************************************************************** */
	public func stringForUnitIndex(_ index: Int) -> String {
		let units = timeUnitsArray
		if index < units.count { return units[index] }
		return "???"   // unsupported unit
	}
	

	//********************************************************************************
	/**
	   Sets the active rate value from a scroll wheel's value index.
     
	    - Author:   Michael Griebling
	    - Date:   	2 April 2013
     
     ******************************************************************************** */
	public mutating func setTimeFromTimeIndex(_ index: Int) {
        var index = index
		if index < maxIndexForTime {
			if units == .seconds {
				if allowPause {
					if index == 0 { time = Time(value: 0, unit: .seconds) }  // need to override minimum seconds
					index -= 1
				}
				if minimumSeconds < Rate.ONE_HALF {
					if index == 0 { time = Time(value: Rate.ONE_EIGHTH, unit: .seconds) }
					index -= 1
				}
				if minimumSeconds < 1.0 {
					if index == 0 { time = Time(value: Rate.ONE_HALF, unit: .seconds) }
					index -= 1
				}
				if index >= 0 { time = Time(value: Double(max(0, Int(minimumSeconds-1))+index+1), unit: .seconds) }
			} else {
                time = Time(value: Double(index+1), unit: units)
			}
		}
	}
    
    private static var timeUnits : [TimeUnitType] = [.seconds, .minutes, .hours, .days, .weeks]
	
	//********************************************************************************
	/**
	   Sets the active unit from a scroll wheel's unit index.
     
	    - Author:   Michael Griebling
	    - Date:   	2 April 2013
     
     ******************************************************************************** */
	public mutating func setUnitFromUnitIndex (_ index: Int) {
		if index < maxIndexForUnits {
			var time = max(1, self.time.value)     // preserve time across unit changes
            var unit = self.time.unit
			if allowPause {
				if timeSeconds == 0 { time = 0 }
				else { unit = Rate.timeUnits[max(0, index-1)] }
			} else {
				unit = Rate.timeUnits[index]
			}
            self.time = Time(value: time, unit: unit)
		}
	}

	
	// MARK: - Support for steppers
	
	//********************************************************************************
	/**
	    Returns the maximum step limit for a stepper based on the current rate.
     
	     - Author:   Michael Griebling
	     - Date:   	2 April 2013
     
     ******************************************************************************** */
	public var maxStepIndex : Int { return maxIndexForTime-1 }
	
	//********************************************************************************
	/**
	    Returns a time and unit string based on the stepper *index*.
     
	     - Author:   Michael Griebling
	     - Date:   	2 April 2013
     
     ******************************************************************************** */
	public func stringForStepIndex(_ index: Int) -> String {
        return Rate.useAbbreviations ? shortString : string
	}

	//********************************************************************************
	/**
	    Sets the current rate based on the stepper's value *index*.
     
	     - Author:   Michael Griebling
	     - Date:   	2 April 2013
     
     ******************************************************************************** */
	public mutating func setTimeFromIndex(_ index : Int) { setTimeFromTimeIndex(index) }
	
	// MARK: - String support
	
	//********************************************************************************
	/**
	    Returns an array of legal time strings that are less than one second.
     
	     - Author:   Michael Griebling
	     - Date:   	28 March 2013
     
     ******************************************************************************** */
	private func getTimeFractions() -> [String] {
		var fractions = [String]()
		if allowPause { fractions = [Rate.STR_PAUSE] }
		if units == .seconds {
			if minimumSeconds < Rate.ONE_HALF { fractions.append(Rate.STR_ONE_EIGHTH) }
			if minimumSeconds < 1.0			  { fractions.append(Rate.STR_ONE_HALF) }
		}
		return fractions
	}
	
	//********************************************************************************
	/**
	    Returns the active rate string without units.
     
	     - Author:   Michael Griebling
	     - Date:   	2 April 2013
     
     ******************************************************************************** */
	public func stringFromRate() -> String {
		let num = rawTime
		if num == 0 && self.allowPause { return Rate.STR_PAUSE }
		else if num < 50               { return Rate.STR_ONE_EIGHTH }
		else if num < 100              { return Rate.STR_ONE_HALF }
		return String.localizedStringWithFormat("%ld", Int(time.value))
	}
	
    //********************************************************************************
    /**
        Returns the active units string.
         
         - Author:   Michael Griebling
         - Date:   	2 April 2013
     
     ******************************************************************************** */
	public var stringFromUnits : String {
		return stringFromUnits(units, andTime: timeUnits)
	}
	
    //********************************************************************************
    /**
        Returns the active rate string with units.
         
         - Author:   Michael Griebling
         - Date:   	2 April 2013
     
     ******************************************************************************** */
	public var string : String {
		if rawTime == 0 && allowPause { return stringFromRate() }
		return stringFromRate() + " " + stringFromUnits
	}
	
    //********************************************************************************
    /**
	    Returns the active abbreviated rate string with units.
     
         - Author:   Michael Griebling
         - Date:   	2 April 2013
     
     ******************************************************************************** */
	public var shortString : String {
		if rawTime == 0 && allowPause { return stringFromRate() }
		return stringFromRate() + shortStringFromUnits(units)
	}
	
	// MARK: - NSCoding
	
	private static let kRateTime   = "RateTime"
	private static let kRateUnits  = "RateUnits"
	private static let kRatePause  = "RatePause"
	private static let kMinTime    = "MinimumTime"
	private static let kMaxTime    = "MaximumTime"
	
	//********************************************************************************
	/**
	    Encoder for the rate to be *NSCoding* compliant.
     
	     - Author:   Michael Griebling
	     - Date:   	2 April 2013
     
     ******************************************************************************** */
	public func encodeWithCoder(_ encoder: NSCoder) {
		encoder.encode(self.time.value, forKey:Rate.kRateTime)
        let unitIndex = Rate.timeUnits.firstIndex { $0 == units } ?? 0
		encoder.encode(unitIndex, forKey:Rate.kRateUnits)
		encoder.encode(self.allowPause, forKey:Rate.kRatePause)
		encoder.encode(self.minimumSeconds, forKey:Rate.kMinTime)
		encoder.encode(self.maximumSeconds, forKey:Rate.kMaxTime)
	}
	
	//********************************************************************************
	/**
	    Decoder for the rate to be *NSCoding* compliant.
     
	     - Author:   Michael Griebling
	     - Date:   	2 April 2013
     
     ******************************************************************************** */
	public init (coder: NSCoder) {
		let time = coder.decodeDouble(forKey: Rate.kRateTime)
		let units = Rate.timeUnits[coder.decodeInteger(forKey: Rate.kRateUnits)]
        self.time = Time(value: time, unit: units)
		allowPause = coder.decodeBool(forKey: Rate.kRatePause)
        minTime = Time(value: coder.decodeDouble(forKey: Rate.kMinTime), unit: .seconds)
        maxTime = Time(value: coder.decodeDouble(forKey: Rate.kMaxTime), unit: .seconds)
	}

}

extension Rate : Comparable {
    
    public static func == (lhs: Rate, rhs: Rate) -> Bool { return lhs.rawTime == rhs.rawTime }
    public static func < (lhs: Rate, rhs: Rate)  -> Bool { return lhs.rawTime < rhs.rawTime }
 
}


extension Rate :  CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String { return string }
    public var debugDescription: String { return description }
    
}

