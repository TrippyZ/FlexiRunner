class FlexiRunnerApp extends Toybox.Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    //! Return the initial view of your application here
    function getInitialView() {
        return [ new FlexiRunnerView() ];
    }
}


class FlexiRunnerView extends Toybox.WatchUi.DataField {

	hidden var hrZones;
	hidden var hrZone = 0.0;
	hidden var unitP;
	hidden var unitD;

	hidden var hrDisplay = 0;
	//! 0 => Direct heart rate in bpm
	//! 1 => Heart rate decimal zone (e.g. 3.5)
	//! 2 => Both bpm and zone

	hidden var bottomLeftData = 1;	//! Data to show in bottom left field
	hidden var bottomRightData = 0;	//! Data to show in bottom right field
	//! Paces enum:
	//! 0 => (overall) average pace
	//! 1 => Moving (running) pace
	//! 2 => Lap pace
	//! 3 => Lap moving (running) pace
	//! 4 => Last lap pace
	//! 5 => Last lap moving (running) pace

	hidden var timerDisplayLimit = 3599;	//! If the timer is less than this, display it as mm:ss, otherwise h:mm(ss). Two values make sense: 3599 for 59:59 or 5999 for 99:59
	
	hidden var mTimerRunning = false;
	
	hidden var stoppedSeconds = 0;
	hidden var movingSpeed = 0.0;

	hidden var targetSpeed = 0.0;
	hidden var targetPaceMetric = 0;	//! Which average pace metric should be used as the reference for deviation of the current pace? (see above)
	hidden var paceDeviation = null;

	hidden var mTimerTime = 0;
	hidden var mElapsedTime = 0;
	hidden var mElapsedDistance = 0.0;
	hidden var mCurrentSpeed = 0.0;	
	hidden var mAverageSpeed = 0.0;
	hidden var mCurrentHeartRate = 0;
	hidden var mCurrentCadence = 0;

	hidden var laps = 1;
	hidden var lastLapDistMarker = 0.0;
    hidden var lastLapTimeMarker = 0;

    hidden var lapTimerTime = 0;
	hidden var lapStoppedSeconds = 0;
	hidden var lapMovingSpeed = 0.0;
	hidden var lapElapsedDistance = 0.0;
	hidden var lapSpeed = 0.0;

	hidden var lastLapTimerTime = 0;
	hidden var lastLapMovingSpeed = 0.0;
	hidden var lastLapElapsedDistance = 0.0;
	hidden var lastLapSpeed = 0.0;  

    function initialize() {
        DataField.initialize();  
        
 		hrZones = UserProfile.getHeartRateZones(UserProfile.getCurrentSport());
 		var mApp = Application.getApp();
 		hrDisplay 				= mApp.getProperty("pHR");	 
 		targetPaceMetric		= mApp.getProperty("pPace");
 		bottomLeftData			= mApp.getProperty("pFL");
 		bottomRightData			= mApp.getProperty("pFR");
 		timerDisplayLimit		= mApp.getProperty("pTimer");
 
        if (System.getDeviceSettings().paceUnits == System.UNIT_METRIC) {
        	unitP = 1000.0;
        } else { //if (System.getDeviceSettings().paceUnits == System.UNIT_STATUTE) {
        	unitP = 1609.344;
        }
        
        if (System.getDeviceSettings().distanceUnits == System.UNIT_METRIC) {
        	unitD = 1000.0;
        } else { //if (System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE) {
        	unitD = 1609.344;
        }

    }


    //! The given info object contains all the current workout
    //! information. Calculate a value and save it locally in this method.
    function compute(info) {

		if (info.timerTime != null) {
			//! N.B. info.timerTime is converted from milliseconds to seconds here
			mTimerTime = info.timerTime / 1000;
			lapTimerTime = mTimerTime - lastLapTimeMarker;
		} else {
			mTimerTime = 0;
			lapTimerTime = 0;			
		}

		if (info.elapsedTime != null) {
			mElapsedTime = info.elapsedTime / 1000;
		} else {
			mElapsedTime = 0;
		}
    	
    	if (info.currentSpeed != null) {
    		mCurrentSpeed = info.currentSpeed;
    	} else {
    		mCurrentSpeed = 0.0;
    	}

    	if (mTimerRunning && mCurrentSpeed < 1.8) { //! Speed below which the moving time timer is paused (1.8 m/s = 9:15 min/km, ~15:00 min/mi)
			//! Simple non-moving time calculation - relies on compute() being called every second
			stoppedSeconds++;
			lapStoppedSeconds++;
		}

    	
    	if (info.currentHeartRate != null) {
    		mCurrentHeartRate = info.currentHeartRate;
			if (hrZones != null) {		
		    	if (mCurrentHeartRate < hrZones[0]) {
					hrZone = mCurrentHeartRate / hrZones[0].toFloat();
				} else if (mCurrentHeartRate < hrZones[1]) {
					hrZone = 1 + (mCurrentHeartRate - hrZones[0]) / (hrZones[1] - hrZones[0]).toFloat();
				} else if (mCurrentHeartRate < hrZones[2]) {
					hrZone = 2 + (mCurrentHeartRate - hrZones[1]) / (hrZones[2] - hrZones[1]).toFloat();
				} else if (mCurrentHeartRate < hrZones[3]) {
					hrZone = 3 + (mCurrentHeartRate - hrZones[2]) / (hrZones[3] - hrZones[2]).toFloat();
				} else if (mCurrentHeartRate < hrZones[4]) {
					hrZone = 4 + (mCurrentHeartRate - hrZones[3]) / (hrZones[4] - hrZones[3]).toFloat();
				} else {
					hrZone = 5 + (mCurrentHeartRate - hrZones[4]) / (hrZones[5] - hrZones[4]).toFloat();
				}
			} else {
				hrZone = 0.0;
			}
    	} else {
    		mCurrentHeartRate = 0;
    		hrZone = 0.0;
    	}
    		
    	if (info.currentCadence != null) {
    		mCurrentCadence = info.currentCadence;
    	} else {
    		mCurrentCadence = 0;
    	}    	
    	
    	if (info.elapsedDistance != null) {
    		mElapsedDistance = info.elapsedDistance;
			lapElapsedDistance 	= mElapsedDistance - lastLapDistMarker;
    	} else {
    		mElapsedDistance = 0.0;
    		lapElapsedDistance 	= 0;
    	}
    	
    	if (lapTimerTime > 0 && lapElapsedDistance > 0) {
    		lapSpeed = lapElapsedDistance / lapTimerTime;
    	} else {
    		lapSpeed = 0.0;
    	}

    	if (info.averageSpeed != null) {
    		mAverageSpeed = info.averageSpeed;
    	} else {
    		mAverageSpeed = 0.0;
    	}
    	
    	if (stoppedSeconds == 0) {
    		movingSpeed = mAverageSpeed;
    	} else {
	    	if (mTimerTime > 0 && stoppedSeconds < mTimerTime) {
	    		movingSpeed = mElapsedDistance / (mTimerTime - stoppedSeconds);
	    	} else {
	    		movingSpeed = mAverageSpeed;
	    	}
    	}
    	if (lapStoppedSeconds == 0) {
    		lapMovingSpeed = lapSpeed;
    	} else {
	    	if (lapTimerTime > 0 && lapStoppedSeconds < lapTimerTime) {
	    		lapMovingSpeed = lapElapsedDistance / (lapTimerTime - lapStoppedSeconds);
	    	} else {
	    		lapMovingSpeed = lapSpeed;
	    	}
    	}
    	
    	if (targetPaceMetric == 0) {
			targetSpeed = mAverageSpeed;
		} else if (targetPaceMetric == 1) {
			targetSpeed = movingSpeed;
		} else if (targetPaceMetric == 2) {
			targetSpeed = lapSpeed;
		} else if (targetPaceMetric == 3) {
			targetSpeed = lapMovingSpeed;
		} else if (targetPaceMetric == 4) {
			targetSpeed = lastLapSpeed;
		} else if (targetPaceMetric == 5) {
			targetSpeed = lastLapMovingSpeed;
		}
					
		if (targetSpeed > 0.0 && mCurrentSpeed > 1.8) {	//! Only use the pace colour indicator when running (1.8 m/s = 9:15 min/km, ~15:00 min/mi)
			paceDeviation = (mCurrentSpeed / targetSpeed);
		} else {
			paceDeviation = null;
		}
		/*	
		var stats = System.getSystemStats();
        var memUsed = stats.usedMemory.toString();
        var memTotal = stats.totalMemory.toString();
        var memFree = stats.freeMemory.toString();
        System.println("==================================================");
        System.println("Memory usage: " + memUsed + " / " + memTotal + " (" + memFree + " free)");
		System.println("Timer: " + mTimerTime);
		System.println("Elapsed time: " + mElapsedTime);
		System.println("Stopped seconds: " + stoppedSeconds);
		System.println("Distance: " + mElapsedDistance);
		System.println("Current speed: " + mCurrentSpeed);
		System.println("Average speed: " + mAverageSpeed);
		if (paceDeviation != null) {
			System.println("Pace deviation: " + (paceDeviation * 100).format("%d") + "%");
		} else {
			System.println("Pace deviation: N/A");
		}
		System.println("Average moving (running) speed: " + movingSpeed);
		System.println("Current heart rate: " + mCurrentHeartRate);
		System.println("Current heart rate zone: " + hrZone);
		System.println("Current cadence: " + mCurrentCadence);
		System.println("Laps: " + laps);
		System.println("Lap timer: " + lapTimerTime);
		System.println("Lap stopped seconds: " + lapStoppedSeconds);
		System.println("Lap distance: " + lapElapsedDistance);
		System.println("Lap speed: " + lapSpeed);
		System.println("Lap moving (running) speed: " + lapMovingSpeed);
		System.println("Last lap timer: " + lastLapTimerTime);
		System.println("Last lap distance: " + lastLapElapsedDistance);
		System.println("Last lap speed: " + lastLapSpeed);
		System.println("Last lap moving (running) speed: " + lastLapMovingSpeed);
		System.println("==================================================");
		/**/
		/*
		mCurrentSpeed = 1.8;
		mAverageSpeed = 3.0;
		movingSpeed = 2.8;
		mTimerTime = 11000;
		mElapsedDistance = 24187;
		/**/
    }

    //! Store last lap quantities and set lap markers
    function onTimerLap() {
    	lastLapTimerTime		= lapTimerTime;
    	lastLapElapsedDistance	= lapElapsedDistance;
    	lastLapSpeed			= lapSpeed;
    	lastLapMovingSpeed		= lapMovingSpeed;
    	laps++;
    	lastLapDistMarker 		= mElapsedDistance;
    	lastLapTimeMarker 		= mTimerTime;
    	lapStoppedSeconds 		= 0;
    }

    //! Timer transitions from stopped to running state
    function onTimerStart() {
    	mTimerRunning = true;
    }


    //! Timer transitions from running to stopped state
    function onTimerStop() {
    	mTimerRunning = false;
    }


    //! Timer transitions from paused to running state (i.e. resume from Auto Pause is triggered)
    function onTimerResume() {
    	mTimerRunning = true;
    }


    //! Timer transitions from running to paused state (i.e. Auto Pause is triggered)
    function onTimerPause() {
    	mTimerRunning = false;
    }


    //! Display the value you computed here. This will be called
    //! once a second when the data field is visible.
    function onUpdate(dc) {
    	var nudge = 0;
    	dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.clear();    	

    	//! Draw the HR field separator (if applicable) first, underneath the indicators
    	if (hrDisplay == 2) {
    		dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_WHITE);
        	dc.setPenWidth(2);
        	if (testDoubleDigitSpeed(mCurrentSpeed)) {
				dc.drawLine(0, 93, 64, 93);
			} else {
        		dc.drawLine(0, 93, 70, 93);
        	}
    	}

    	//!
    	//! Draw colour indicators first	
		//!	

		//! HR zone indicator
		if (hrZone < 1.0) {
    		dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);	//! No zone
		} else if (hrZone < 2.0) {
			dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);	//! Warm-up
		} else if (hrZone < 3.0) {
			dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);		//! Easy
		} else if (hrZone < 4.0) {
			dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);		//! Aerobic
		} else if (hrZone < 5.0) {
			dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);		//! Threshold
		} else {
			dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);		//! Maximum
		}
		if (hrDisplay == 2) {
			dc.setPenWidth(18);
			dc.drawArc(111, 93, 106, dc.ARC_CLOCKWISE, 200, 158);
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.fillRectangle(0, 50, 30, 15);
			dc.fillRectangle(0, 122, 30, 15);
		} else {
			dc.fillPolygon([[0, 122],
							[8, 122],
							[6, 116],
							[5, 111],
							[4, 107],
							[4, 96],
							[5, 92],
							[6, 89],
							[7, 88],
							[8, 86],
							[9, 85],
							[12, 83],
							[15, 82],
							[75, 82],
							[75, 65],
							[0, 65]]);
		}

		//! Cadence zone indicator colour (fixed thresholds and colours to match Garmin, with the addition of grey for walking/stopped)
		if (mCurrentCadence > 183) {
			dc.setColor(Graphics.COLOR_PURPLE, Graphics.COLOR_TRANSPARENT);
		} else if (mCurrentCadence >= 174) {
			dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
		} else if (mCurrentCadence >= 164) {
			dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
		} else if (mCurrentCadence >= 153) {
			dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
		} else if (mCurrentCadence >= 120) {
			dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
		}  else {
			dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
		}
		dc.fillPolygon([[215, 122],
						[207, 122],
						[209, 116],
						[210, 111],
						[211, 107],
						[211, 96],
						[210, 92],
						[209, 89],
						[208, 88],
						[207, 86],
						[206, 85],
						[203, 83],
						[200, 82],
						[140, 82],
						[140, 65],
						[215, 65]]);
						
		//! Current pace vs (moving) average pace colour indicator
		if (paceDeviation == null) {
			dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
		} else if (paceDeviation < 0.95) {	//! Maximum % slower deviation of current pace from target considered good
			dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
		} else if (paceDeviation <= 1.05) {	//! Maximum % faster deviation of current pace from target considered good
			dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
		} else {
			dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
		}
		if (testDoubleDigitSpeed(mCurrentSpeed)) {
			dc.fillRectangle(64, 65, 85, 17);
		} else {
			dc.fillRectangle(70, 65, 75, 17);		
		}		

    	//! Draw separator lines
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_WHITE);
        dc.setPenWidth(2);
        //! Horizontal thirds
		dc.drawLine(0, 65, 215, 65);
		dc.drawLine(0, 122, 215, 122);
		//! Top vertical divider
		dc.drawLine(107, 17, 107, 65);
		//! Top curved separator
		dc.drawArc(107, -45, 60, dc.ARC_COUNTER_CLOCKWISE, 180, 0);
		//! Centre vertical dividers
		if (testDoubleDigitSpeed(mCurrentSpeed)) {
			dc.drawLine(64, 65, 64, 122);
			dc.drawLine(149, 65, 149, 122);
		} else {
			dc.drawLine(70, 65, 70, 122);
			dc.drawLine(145, 65, 145, 122);			
		}		
		//! Bottom vertical divider
		dc.drawLine(107, 122, 107, 180);
          
        //!
        //! Draw fields
        //! ===========
        //!
              
        //! Set text colour
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);

		dc.drawText(107, -4, Graphics.FONT_XTINY, System.getClockTime().hour.format("%d") + ":" + System.getClockTime().min.format("%02d"), Graphics.TEXT_JUSTIFY_CENTER);
		
        var fDistance;
        if ((mElapsedDistance/unitD) < 100) {
			fDistance = (mElapsedDistance/unitD).format("%.2f");
		} else {
			fDistance = (mElapsedDistance/unitD).format("%.1f");
		}

		var fTimerHours 	= (mTimerTime / 3600).format("%d");
		var fTimerMins 		= (mTimerTime / 60 % 60).format("%02d");
		var fTimerSecs 		= (mTimerTime % 60).format("%02d");
		var fTimerMinsAbs 	= (mTimerTime / 60).format("%d");
        //! Top row: timer and distance - additional seconds on timer causes distance field to be compressed
    	if (mTimerTime > timerDisplayLimit) {  	
    		//! Format time as h:mm(ss)
    		nudge = (mTimerTime < 7200) ? 0 : 1; //! Less than 2 hours - shift to left slightly since '1' takes up less space than other numbers
			dc.drawText(17 + nudge, 42, Graphics.FONT_NUMBER_MEDIUM, fTimerHours + ":" + fTimerMins, Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
			dc.drawText(80 + nudge, 34, Graphics.FONT_NUMBER_MILD, fTimerSecs, Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
		} else {
			//! Format time as m:ss
			dc.drawText(61, 42, Graphics.FONT_NUMBER_MEDIUM, fTimerMinsAbs + ":" + fTimerSecs, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		}

		dc.drawText(154, 42, Graphics.FONT_NUMBER_MEDIUM, fDistance, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		dc.drawText(156, 17, Graphics.FONT_XTINY,  "Distance", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);	
		dc.drawText(65, 17, Graphics.FONT_XTINY,  "Timer", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);	

		if (mCurrentSpeed < 0.447164) {
			dc.drawLine(68, 117, 85, 117);
			dc.drawLine(86, 117, 103, 117);
			dc.drawLine(111, 117, 128, 117);
			dc.drawLine(129, 117, 146, 117);
			dc.drawText(107, 99, Graphics.FONT_NUMBER_MEDIUM, ":", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		} else {
			if ( (unitP == 1609.344 && mCurrentSpeed < 1.342) || (unitP == 1000.0 && mCurrentSpeed < 0.834) ) {
				dc.drawText(107, 100, Graphics.FONT_NUMBER_MEDIUM, fmtPace(unitP/(Math.round((unitP/mCurrentSpeed) / 5) * 5)), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			} else if (testDoubleDigitSpeed(mCurrentSpeed)) {
				dc.drawText(105, 100, Graphics.FONT_NUMBER_MEDIUM, fmtPace(unitP/(Math.round((unitP/mCurrentSpeed) / 5) * 5)), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			} else {
				dc.drawText(108, 100, Graphics.FONT_NUMBER_MEDIUM, fmtPace(unitP/(Math.round((unitP/mCurrentSpeed) / 5) * 5)), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			}
		}    	
		dc.drawText(107, 72, Graphics.FONT_XTINY,  "Pace", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		
		//! Centre left: heart rate
		var hrBpm = (mCurrentHeartRate > 0) ? mCurrentHeartRate : "--";
		nudge = (mCurrentHeartRate < 200) ? 0 : 2;
		if (testDoubleDigitSpeed(mCurrentSpeed)) {
			nudge -= 3;
		}
		if (hrDisplay == 2) {			
			dc.drawText(37, 77, Graphics.FONT_NUMBER_MILD, hrBpm, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			dc.drawText(38, 106, Graphics.FONT_NUMBER_MILD, hrZone.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			dc.drawText(6, 84, Graphics.FONT_XTINY, "H", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			dc.drawText(6, 97, Graphics.FONT_XTINY, "R", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		} else if (hrDisplay == 1) {
			dc.drawText(37, 100, Graphics.FONT_NUMBER_MEDIUM, hrZone.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			dc.drawText(35, 72, Graphics.FONT_XTINY, "HR Zone", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		} else { //if (hrDisplay == 0) {
			dc.drawText(36 + nudge, 100, Graphics.FONT_NUMBER_MEDIUM, hrBpm, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			dc.drawText(35, 72, Graphics.FONT_XTINY, "HR", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		}
		
		//! Centre right: cadence
		nudge = (mCurrentCadence < 200) ? (mCurrentCadence < 100) ? 2 : 0 : 2;
		if (testDoubleDigitSpeed(mCurrentSpeed)) {
			nudge += 2;
		}
		dc.drawText(175 + nudge, 100, Graphics.FONT_NUMBER_MEDIUM, mCurrentCadence, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER); 
		dc.drawText(179, 72, Graphics.FONT_XTINY,  "Cadence", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER); 

		//! Bottom left
		var fPace = 0;
		var lPace = "";
		if (bottomLeftData == 0) {
			fPace = mAverageSpeed;
			lPace = "Avg. Pace";
		} else if (bottomLeftData == 1) {
			fPace = movingSpeed;
			lPace = "Run. Pace";
		} else if (bottomLeftData == 2) {
			fPace = lapSpeed;
			lPace = "Lap Pace";
		} else if (bottomLeftData == 3) {
			fPace = lapMovingSpeed;
			lPace = "Lap R Pace";
		} else if (bottomLeftData == 4) {
			fPace = lastLapSpeed;
			lPace = "L-1 Pace";
		} else if (bottomLeftData == 5) {
			fPace = lastLapMovingSpeed;
			lPace = "L-1 R Pace";
		}
		if (fPace < 0.447164) {
			dc.drawLine(26, 157, 43, 157);
			dc.drawLine(44, 157, 61, 157);
			dc.drawLine(69, 157, 86, 157);
			dc.drawLine(87, 157, 104, 157);
			dc.drawText(65, 139, Graphics.FONT_NUMBER_MEDIUM, ":", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		} else {
			dc.drawText(64, 142, Graphics.FONT_NUMBER_MEDIUM, fmtPace(fPace), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		}
		dc.drawText(72, 167, Graphics.FONT_XTINY, lPace, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			
		//! Bottom right
		fPace = 0;
		lPace = "";
		if (bottomRightData == 0) {
			fPace = mAverageSpeed;
			lPace = "Avg. Pace";
		} else if (bottomRightData == 1) {
			fPace = movingSpeed;
			lPace = "Run. Pace";
		} else if (bottomRightData == 2) {
			fPace = lapSpeed;
			lPace = "Lap Pace";
		} else if (bottomRightData == 3) {
			fPace = lapMovingSpeed;
			lPace = "Lap R Pace";
		} else if (bottomRightData == 4) {
			fPace = lastLapSpeed;
			lPace = "L-1 Pace";
		} else if (bottomRightData == 5) {
			fPace = lastLapMovingSpeed;
			lPace = "L-1 R Pace";
		}
		if (fPace < 0.447164) {
			dc.drawLine(111, 157, 128, 157);
			dc.drawLine(129, 157, 146, 157);
			dc.drawLine(154, 157, 171, 157);
			dc.drawLine(172, 157, 189, 157);
			dc.drawText(150, 139, Graphics.FONT_NUMBER_MEDIUM, ":", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		} else {
			dc.drawText(150, 142, Graphics.FONT_NUMBER_MEDIUM, fmtPace(fPace), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		}
		dc.drawText(141, 167, Graphics.FONT_XTINY, lPace, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

    }
        
    
    function fmtPace(secs) {
        return ((unitP/secs).toLong() / 60).format("%0d") + ":" + ((unitP/secs).toLong() % 60).format("%02d");
    }

    function testDoubleDigitSpeed(spd) {
    	if (unitP == 1609.344) {
    		return (spd < 2.687);
    	} else {
    		return (spd < 1.669);
    	}
    }

}
