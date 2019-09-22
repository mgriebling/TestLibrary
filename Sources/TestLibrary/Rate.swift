//********************************************************************************
//
// This source is Copyright (c) 2013 by Solinst Canada.  All rights reserved.
//
//********************************************************************************
/**
* \file    Rate.swift
* \details A general-purpose rate object that has units of seconds, minutes,
*          hours, and days.  Methods exist to convert the rate to a string
*          and read/save the rate from/to an encoded stream.  Convenience
*          methods provide an interface to steppers and scroll wheels.
* \author  Michael Griebling
* \date   22 June 2014
*/
//********************************************************************************

import Foundation

public enum TimeUnitType : Int {
	case Sec=0, Min, Hour, Day, Week
}

public struct Rate {
	
	public static let MAX_TIME   =  99
	public static let HUNDREDS   = 100
	public static let ONE_EIGHTH = (1.0/8.0)
	public static let ONE_HALF   = (1.0/2.0)
	public static let MINUTES	  = (60.0)
	public static let HOURS	  = (60.0*MINUTES)
	public static let DAYS		  = (24.0*HOURS)
	public static let WEEKS	  = (7.0*DAYS)
	
	public static let scale : [NSTimeInterval] = [1.0, MINUTES, HOURS, DAYS, WEEKS]    // for units of seconds, minutes, hours, days, and weeks with seconds base
	
	public static let STR_PAUSE       = NSLocalizedString("Pause", comment: "Schedule pause")
	static let STR_ONE_EIGHTH  = NSLocalizedString("⅛", comment: "1/8 second")
	static let STR_ONE_HALF    = NSLocalizedString("½", comment: "1/2 second")
	
	// MARK: - Basic attributes
	
	public var allowPause: Bool				// sets a pause for time <= 0
	public var units: TimeUnitType				// 'units' for 'time'
	public var timeSeconds: NSTimeInterval		// time in fractional seconds
	
	//********************************************************************************
	/**
	* \details Get/set the minimum time limit to \e minimumSeconds.  The maximum value
	*          of the minimum is limited to \e MAX_TIME weeks.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public var minimumSeconds: NSTimeInterval {
		didSet (oldMinimum) {
			// disallow minimums above MAX_TIME weeks
			if minimumSeconds < Double(Rate.MAX_TIME)*Rate.WEEKS { minimumSeconds = oldMinimum }
			if minimumSeconds > maximumSeconds { maximumSeconds = oldMinimum }
		}
	}
	
	//********************************************************************************
	/**
	* \details Set the maximum time limit to \e maximumSeconds.  The maximum value
	*          is limited to \e MAX_TIME weeks.
	* \author  Michael Griebling
	* \date   	8 April 2013
	*/
	//********************************************************************************
	public var maximumSeconds: NSTimeInterval {
		didSet (oldMaximum) {
			// disallow maximums above MAX_TIME weeks
			if maximumSeconds <= Double(Rate.MAX_TIME)*Rate.WEEKS { maximumSeconds = oldMaximum }
		}
	}
	
	// MARK: - Default constructors
	
	//********************************************************************************
	/**
	* \details Initialize a LLRate object with a given \e time and \e units.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public init (time: Int, andUnits units: TimeUnitType) {
		// convert time to seconds
		self.init(interval: Double(time) * Rate.scale[units.rawValue])
		self.units = units
	}
	
	//********************************************************************************
	/**
	* \details Initialize a LLRate object with a given \e rawTime in hundredths of
	*          seconds.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public init (var rawTime: Int64) {
		if rawTime < 0 { rawTime = 0 }
		self.init(interval: Rate.getSecondsFromRawTime(rawTime))
		self.units = getUnitsForRawTime(rawTime)
	}

	//********************************************************************************
	/**
	* \details Designated initializer for the LLRate object.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public init (interval: NSTimeInterval) {
		timeSeconds = interval
		minimumSeconds = Rate.ONE_EIGHTH
		maximumSeconds = Double(Rate.MAX_TIME) * Rate.WEEKS
		units = .Sec
		allowPause = false
	}
	
	
	// MARK: - Utility routines
	
	//********************************************************************************
	/**
	* \details Returns a preferred time unit for the raw time \e num.
	* \author  Michael Griebling
	* \date   	2 April 2013
	*/
	//********************************************************************************
	public func getUnitsForRawTime(var num: Int64) -> TimeUnitType {
		var unit: TimeUnitType = .Sec            // default is seconds
		num /= Int64(Rate.HUNDREDS)
		if num == 0 { return unit }
		if ((num % 60) == 0 || num > Int64(Rate.MAX_TIME)) {
			unit = .Min                  // assume units are minutes
			num /= 60;
			if ((num % 60) == 0 || num > Int64(Rate.MAX_TIME)) {
				unit = .Hour             // assume units are in hours
				num /= 60;
				if ((num % 24) == 0 || num > Int64(Rate.MAX_TIME)) {
					unit = .Day
					num /= 24;
					if ((num % 7) == 0 || num > Int64(Rate.MAX_TIME)) {
						unit = .Week
						num /= 7;
					}
				}
			}
		}
		return unit;
	}
	
	//********************************************************************************
	/**
	* \details Converts a \e rawTime in hundredths of seconds to an \e NSTimeInterval
	*          in seconds.  Note: 1/8 second is correctly handled.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public static func getSecondsFromRawTime(rawTime: Int64) -> NSTimeInterval {
		var time = NSTimeInterval(rawTime)
		if (rawTime > 0) {
			if (rawTime < Int64(Rate.HUNDREDS)/2) { time = Rate.ONE_EIGHTH }   // 1/8 sampling rate
			else { time = Double(rawTime) / Double(Rate.HUNDREDS) }
		}
		return time;
	}
	
	//********************************************************************************
	/**
	* \details Gets a raw time in hundredths of seconds from the \e seconds time.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public func getRawTimeFromSeconds(seconds: NSTimeInterval) -> Int64 {
		return Int64(floor(seconds * Double(Rate.HUNDREDS)))
	}
	
	//********************************************************************************
	/**
	* \details Set the rate from the \e rawTime.  The internal units are determined
	*          based on the magnitude of the raw time.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public mutating func setRawTime(rawTime: Int64) {
		units = getUnitsForRawTime(rawTime)
		timeSeconds = Rate.getSecondsFromRawTime(rawTime)
	}
	
	public static let dateComponentsFormatter: NSDateComponentsFormatter = {
		let formatter = NSDateComponentsFormatter()
		formatter.unitsStyle = .Full
		return formatter
	}()
	
	//********************************************************************************
	/**
	* \details Returns a units string for any \e TimeUnitType in \e units with a
	*          plural extension based on the \e time.  An abbreviated string is
	*		   returned when \e abbreviated is \e true.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public func stringFromUnits(units: TimeUnitType, andTime time: Int, abbreviated: Bool = false) -> String {
		let formatter = Rate.dateComponentsFormatter
		let components = NSDateComponents()
		if abbreviated { formatter.unitsStyle = .Abbreviated }
		switch units {
		case .Sec: components.second = time
		case .Min: components.minute = time
		case .Hour: components.hour = time
		case .Day: components.day = time
		case .Week: components.weekOfMonth = time
		}
		if let string = formatter.stringFromDateComponents(components) {
			// remove numbers and spaces from the string
			return string.stringByTrimmingCharactersInSet(NSCharacterSet.decimalDigitCharacterSet())
				.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
		}
		return ""
	}
	
	//********************************************************************************
	/**
	 * \details Returns a short version of the units string for any \e TimeUnitType
	 *          in \e units.
	 * \author  Michael Griebling
	 * \date   	28 March 2013
	 */
	//********************************************************************************
	public func shortStringFromUnits(units: TimeUnitType) -> String {
		return stringFromUnits(units, andTime: 1, abbreviated: true)
	}
	
	// MARK: - Class-based constructors

	//********************************************************************************
	/**
	* \details Factory method to create a rate with a specific \e time and \e units.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public static func rateWithTime(time: Int, andUnits units: TimeUnitType) -> Rate {
		return Rate(time: time, andUnits: units)
	}

	//********************************************************************************
	/**
	* \details Factory method to create a rate with a \e rawTime in hundredths of
	*          seconds.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public static func rateWithRawTime(rawTime: Int64) -> Rate {
		return Rate(rawTime: rawTime)
	}
	
	//********************************************************************************
	/**
	* \details Factory method to create a rate with a specific \e interval in
	*          seconds
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public static func rateWithTimeInterval(interval: NSTimeInterval) -> Rate {
		return Rate(interval: interval)
	}
	
	// MARK: - Getters/Setters
	
	//********************************************************************************
	/**
	* \details Setter to set the rate's time from \e timeSeconds.  The internal
	*          time is clamped to the rate's minimum time.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public mutating func setTimeSeconds (var time: NSTimeInterval) {
		// clamp to minimum time
		if time < self.minimumSeconds { time = self.minimumSeconds }
		else if time > self.maximumSeconds { time = self.maximumSeconds }
		if time > Double(Rate.MAX_TIME) {
			// re-evaluate the units we're using
			setRawTime(Int64(time*Double(Rate.HUNDREDS)))
		} else {
			timeSeconds = time
		}
	}
	
	//********************************************************************************
	/**
	* \details Get/set the rate's internal time scaled by the active units.  For example,
	*          if the internal time = 180 seconds and the time units are minutes,
	*          the returned value would be three.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public var time: Int {
		get {
			// get the current time assuming display units are in use
			let result = timeSeconds / Rate.scale[units.rawValue]
			return Int(round(result))
		}
		set (newTime) {
			timeSeconds = Double(newTime) * Rate.scale[units.rawValue]
		}
	}

	//********************************************************************************
	/**
	* \details Set the rate based on the \e time and \e units where
	*          \f$1\leq {time} \leq 99\f$.
	* \author  Michael Griebling
	* \date   	28 March 2013
	*/
	//********************************************************************************
	public mutating func setTime (time: Int, andUnits units: TimeUnitType) {
		self.units = units
		self.time = min(max(1, time), Rate.MAX_TIME)    // clamp between 1 and 99
	}
	
	//********************************************************************************
	/**
	 * \details Returns an array of time unit strings with a possibly blank initial
	 *          position for the pause.
	 * \author  Michael Griebling
	 * \date   	2 April 2013
	 */
	//********************************************************************************
	public var timeUnitsArray : [String] {
		var labels = [String]()
		if allowPause { labels = [""] }     // no units for pause
		labels.append(stringFromUnits(.Sec, andTime:time))
		if maximumSeconds > Rate.MINUTES { labels.append(stringFromUnits(.Min, andTime:time)) }
		if maximumSeconds > Rate.HOURS   { labels.append(stringFromUnits(.Hour, andTime:time)) }
		if maximumSeconds > Rate.DAYS	 { labels.append(stringFromUnits(.Day, andTime:time)) }
		if maximumSeconds > Rate.WEEKS	 { labels.append(stringFromUnits(.Week, andTime:time)) }
		return labels;
	}
	
	public var rawTime: Int64 { return getRawTimeFromSeconds(timeSeconds) }	// raw time in 1/100 of a second
	
	//********************************************************************************
	/**
	 * \details Returns \e YES iff \e rate is equal this object's rate.
	 * \author  Michael Griebling
	 * \date   	2 April 2013
	 */
	//********************************************************************************
	public func isEqualToRate (rate: Rate) -> Bool {
		return rawTime == rate.rawTime
	}
	
	// MARK: - Support for scrollwheels
	
	//********************************************************************************
	/**
	* \details Returns the maximum time index for a scroll wheel based on the active
	*          rate.
	* \author  Michael Griebling
	* \date   	2 April 2013
	*/
	//********************************************************************************
	public var maxIndexForTime : Int {
		var maxIndex = Rate.MAX_TIME;                           // default for non-seconds
		if units == .Sec {
			if allowPause { maxIndex++ }						// make room for pause
			if (self.minimumSeconds < 1.0) {
				if minimumSeconds < Rate.ONE_HALF { maxIndex++ } // make room for 1/8 second
				if minimumSeconds < 1.0			  { maxIndex++ } // make room for 1/2 second
			} else {
				// minimum time must be less than MAX_TIME
				maxIndex -= Int(minimumSeconds)
			}
		} else {
			if maximumSeconds <= Double(Rate.MAX_TIME)*Rate.MINUTES { maxIndex = Int(self.maximumSeconds / Rate.MINUTES) }
			else if maximumSeconds <= Double(Rate.MAX_TIME)*Rate.HOURS { maxIndex = Int(self.maximumSeconds / Rate.HOURS) }
			else if maximumSeconds <= Double(Rate.MAX_TIME)*Rate.DAYS { maxIndex = Int(self.maximumSeconds / Rate.DAYS) }
			else if maximumSeconds <= Double(Rate.MAX_TIME)*Rate.WEEKS { maxIndex = Int(self.maximumSeconds / Rate.WEEKS) }
		}
		return maxIndex;
	}
	
	//********************************************************************************
	/**
	* \details Returns a maximum unit index for a scroll wheel based on the active
	*          rate.
	* \author  Michael Griebling
	* \date   	2 April 2013
	*/
	//********************************************************************************
	public var maxIndexForUnits : Int {
		var maxIndex = TimeUnitType.Week.rawValue+1
		if maximumSeconds < Double(Rate.MAX_TIME)*Rate.WEEKS   { maxIndex-- }
		if maximumSeconds < Double(Rate.MAX_TIME)*Rate.DAYS    { maxIndex-- }
		if maximumSeconds < Double(Rate.MAX_TIME)*Rate.HOURS   { maxIndex-- }
		if maximumSeconds < Double(Rate.MAX_TIME)*Rate.MINUTES { maxIndex-- }
		if allowPause { maxIndex++ }                // make room for blank pause units
		return maxIndex;
	}
	
	//********************************************************************************
	/**
	* \details Returns the time index for a scroll wheel that corresponds to the
	*          active rate.
	* \author  Michael Griebling
	* \date   	2 April 2013
	*/
	//********************************************************************************
	public var timeIndex : Int {
		var index = max(0, time-1);							// default for non-seconds
		if units == .Sec {
			let time = timeSeconds
			if allowPause {
				if (time == 0) { return 0 }					// pause
				index++;
			}
			if minimumSeconds < 1.0 {
				if minimumSeconds < Rate.ONE_HALF {
					if time < Rate.ONE_HALF { return index } // 1/8 second
					index++
				}
				if minimumSeconds < 1.0 {
					if (time < 1.0) { return index }		// 1/2 second
					index++
				}
			} else {
				index -= Int(floor(self.minimumSeconds)-1)
			}
		}
		return max(0, index)
	}
	
	//********************************************************************************
	/**
	* \details Returns a unit index for a scroll wheel that corresponds to the
	*          active rate.
	* \author  Michael Griebling
	* \date   	2 April 2013
	*/
	//********************************************************************************
	public var unitIndex : Int {
		var index = units.rawValue
		if allowPause && timeSeconds > 0 { index++ }    // make room for blank pause units
		return index
	}
	
	//********************************************************************************
	/**
	* \details Returns a time value string for a given scroll wheel index.
	* \author  Michael Griebling
	* \date   	2 April 2013
	*/
	//********************************************************************************
	public func stringForTimeIndex(var index: Int) -> String {
		var offset = 1
		if units == .Sec {
			let times = getTimeFractions()
			if (index < times.count) {
				return times[index];
			} else {
				index -= times.count-1
			}
			offset = max(0, Int(floor(self.minimumSeconds)-1))
		}
		return String.localizedStringWithFormat("%ld", index+offset)
	}
	
	//********************************************************************************
	/**
	* \details Returns a unit string for a given scroll wheel index.
	* \author  Michael Griebling
	* \date   	2 April 2013
	*/
	//********************************************************************************
	public func stringForUnitIndex(index: Int) -> String {
		let units = timeUnitsArray
		if index < units.count { return units[index] }
		return "???"   // unsupported unit
	}
	

	//********************************************************************************
	/**
	* \details Sets the active rate value from a scroll wheel's value index.
	* \author  Michael Griebling
	* \date   	2 April 2013
	*/
	//********************************************************************************
	public mutating func setTimeFromTimeIndex(var index: Int) {
		if index < maxIndexForTime {
			if units == .Sec {
				if allowPause {
					if index == 0 { timeSeconds = 0 }  // need to override minimum seconds
					index--
				}
				if minimumSeconds < Rate.ONE_HALF {
					if (index == 0) { timeSeconds = Rate.ONE_EIGHTH }
					index--
				}
				if minimumSeconds < 1.0 {
					if index == 0 { timeSeconds = Rate.ONE_HALF }
					index--
				}
				if index >= 0 { timeSeconds = Double(max(0, Int(minimumSeconds-1))+index+1) }
			} else {
				self.time = index+1
			}
		}
	}
	
	//********************************************************************************
	/**
	* \details Sets the active unit from a scroll wheel's unit index.
	* \author  Michael Griebling
	* \date   	2 April 2013
	*/
	//********************************************************************************
	public mutating func setUnitFromUnitIndex (index: Int) {
		if index < maxIndexForUnits {
			var time = max(1, self.time)     // preserve time across unit changes
			if allowPause {
				if timeSeconds == 0 { time = 0 }
				else { self.units = TimeUnitType(rawValue: max(0, index-1))! }
			} else {
				self.units = TimeUnitType(rawValue: index)!
			}
			self.time = time
		}
	}

	
	// MARK: - Support for steppers
	
	//********************************************************************************
	/**
	 * \details Returns the maximum step limit for a stepper based on the current
	 *          rate.
	 * \author  Michael Griebling
	 * \date   	2 April 2013
	 */
	//********************************************************************************
	public var maxStepIndex : Int { return maxIndexForTime }
	
	//********************************************************************************
	/**
	 * \details Returns a time and unit string based on the stepper \e index.
	 * \author  Michael Griebling
	 * \date   	2 April 2013
	 */
	//********************************************************************************
	public func stringForStepIndex(index: Int) -> String {
		return string
	}

	//********************************************************************************
	/**
	 * \details Sets the current rate based on the stepper's value \e index.
	 * \author  Michael Griebling
	 * \date   	2 April 2013
	 */
	//********************************************************************************
	public mutating func setTimeFromIndex(index : Int) {
		setTimeFromTimeIndex(index)
	}
	
	// MARK: - String support
	
	//********************************************************************************
	/**
	 * \details Returns an array of legal time strings that are less than one second.
	 * \author  Michael Griebling
	 * \date   	28 March 2013
	 */
	//********************************************************************************
	public func getTimeFractions() -> [String] {
		var fractions = [String]()
		if allowPause { fractions = [Rate.STR_PAUSE] }
		if units == .Sec {
			if minimumSeconds < Rate.ONE_HALF { fractions.append(Rate.STR_ONE_EIGHTH) }
			if minimumSeconds < 1.0			  { fractions.append(Rate.STR_ONE_HALF) }
		}
		return fractions
	}
	
	//********************************************************************************
	/**
	 * \details Returns the active rate string without units.
	 * \author  Michael Griebling
	 * \date   	2 April 2013
	 */
	//********************************************************************************
	public func stringFromRate() -> String {
		let num = rawTime
		if num == 0 && self.allowPause { return Rate.STR_PAUSE }
		else if num < 50               { return Rate.STR_ONE_EIGHTH }
		else if num < 100              { return Rate.STR_ONE_HALF }
		return String.localizedStringWithFormat("%ld", time)
	}
	
	var stringFromUnits : String {
		return ""
	}
	
	public var string : String {
		if rawTime == 0 && allowPause { return stringFromRate() }
		return stringFromRate() + " " + stringFromUnits
	}
	
	public var shortString : String {
		if rawTime == 0 && allowPause { return stringFromRate() }
		return stringFromRate() + shortStringFromUnits(units)
	}
	
	// MARK: - NSCoding
	
	static let kRateTime   = "RateTime"
	static let kRateUnits  = "RateUnits"
	static let kRatePause  = "RatePause"
	static let kMinTime    = "MinimumTime"
	static let kMaxTime    = "MaximumTime"
	
	//********************************************************************************
	/**
	 * \details Encoder for the rate to be \e NSCoding compliant.
	 * \author  Michael Griebling
	 * \date   	2 April 2013
	 */
	//********************************************************************************
	func encodeWithCoder(encoder: NSCoder) {
		encoder.encodeDouble(self.timeSeconds, forKey:Rate.kRateTime)
		encoder.encodeInteger(self.units.rawValue, forKey:Rate.kRateUnits)
		encoder.encodeBool(self.allowPause, forKey:Rate.kRatePause)
		encoder.encodeDouble(self.minimumSeconds, forKey:Rate.kMinTime)
		encoder.encodeDouble(self.maximumSeconds, forKey:Rate.kMaxTime)
	}
	
	//********************************************************************************
	/**
	 * \details Decoder for the rate to be \e NSCoding compliant.
	 * \author  Michael Griebling
	 * \date   	2 April 2013
	 */
	//********************************************************************************
	init (coder: NSCoder) {
		timeSeconds = coder.decodeDoubleForKey(Rate.kRateTime)
		units = TimeUnitType(rawValue: coder.decodeIntegerForKey(Rate.kRateUnits))!
		allowPause = coder.decodeBoolForKey(Rate.kRatePause)
		minimumSeconds = coder.decodeDoubleForKey(Rate.kMinTime)
		maximumSeconds = coder.decodeDoubleForKey(Rate.kMaxTime)
	}


}
