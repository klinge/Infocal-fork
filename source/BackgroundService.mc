using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.Communications as Comms;
using Toybox.Application as App;

(:background)
class BackgroundService extends Sys.ServiceDelegate {
	
	(:background_method)
	function initialize() {
		Sys.ServiceDelegate.initialize();
	}

	// Read pending web requests, and call appropriate web request function.
	// This function determines priority of web requests, if multiple are pending.
	// Pending web request flag will be cleared only once the background data has been successfully received.
	(:background_method)
	function onTemporalEvent() {
		var pendingWebRequests = App.getApp().getProperty("PendingWebRequests");
		System.println("Started onTemporalEvent, pendingWebRequests is: " + pendingWebRequests);
		//check if there are pending web requests
		if (pendingWebRequests.keys().size() > 0) {
			//then check what type of web request it is
			if (pendingWebRequests["OpenWeatherMapCurrent"] != null) {
				
				//System.println("getting weather!");
				var api_key = App.getApp().getProperty("OpenWeatherMapApi");
				
				if (api_key.length() == 0) {
					api_key = "333d6a4283794b870f5c717cc48890b5"; // default apikey
				}
				
				Sys.println("OWM key " + api_key);
				var owmStation = App.getApp().getProperty("OpenWeatherMapSelect");
				//station = 0 means we should get weather from coordinates
				if(owmStation != 0) {
					getWeatherForStation(owmStation, api_key);
				} else {
					getWeatherForCoords(api_key);
				}
			}
			if (pendingWebRequests["GetSLDepartures"] != null) {
				System.println("Calling getting SL departures!");
				getSLDepartures();
			} 
		}
		else {
			Sys.println("onTemporalEvent() called with no pending web requests!");
		}
	}

	(:background_method)
	function getSLDepartures() {
		//TODO use gps position to get nearest station and then get departures from that.. 
		var station = "9509";
		var apiKey = "43db3f9f91e541a68ffbb1f35784c813";
		var timeDuration = "20";
		
		makeWebRequest(
			"https://api.sl.se/api2/realtimedeparturesV4.json",
			{
				"siteid" => station,
				"timewindow" => timeDuration,
				"key" => apiKey,
				"bus" => "false",
				"tram" => "false"
			},
			method(:onReceiveSLData)
		);
	}

	(:background_method)
	function getWeatherForStation(owm_station, api_key) {
		System.println("Getting data for station: " + owm_station);
		makeWebRequest(
			"https://api.openweathermap.org/data/2.5/weather",
			{
				"id" => owm_station,
				"appid" => api_key,
				"units" => "metric" // Celcius.
			},
			method(:onReceiveOpenWeatherMapCurrent)
		);
	}

	(:background_method)
	function getWeatherForCoords(api_key) {
		System.println("Getting data for last known coordinates");
		makeWebRequest(
			"https://api.openweathermap.org/data/2.5/weather",
			{
				"lat" => Application.getApp().getProperty("LastLocationLat"),
				"lon" => Application.getApp().getProperty("LastLocationLng"),
				"appid" => api_key,
				"units" => "metric" // Celcius.
			},
			method(:onReceiveOpenWeatherMapCurrent)
		);
	}
	/* 
	 *  CALLBACK FUNCTIONS
	 */
	(:background_method)
	function onReceiveOpenWeatherMapCurrent(responseCode, data) {
		var result;
		
		// Useful data only available if result was successful.
		// Filter and flatten data response for data that we actually need.
		// Reduces runtime memory spike in main app.
		if (responseCode == 200) {
			result = {
				"cod" => data["cod"],
				"lat" => data["coord"]["lat"],
				"lon" => data["coord"]["lon"],
				"dt" => data["dt"],
				"temp" => data["main"]["temp"],
				"tempFeelsLike" => data["main"]["feels_like"],
				"tempMin" => data["main"]["temp_min"],
				"tempMax" => data["main"]["temp_max"],
				"humidity" => data["main"]["humidity"],
				"windSpeed" => data["wind"]["speed"],
				"windDirect" => data["wind"]["deg"],
				"icon" => data["weather"][0]["icon"],
				"des" => data["weather"][0]["main"],
				"name" => data["name"],
				"sunrise" => data["sys"]["sunrise"],
				"sunset" => data["sys"]["sunset"]
			};

		// HTTP error: do not save.
		} else {
			result = {
				"httpError" => responseCode
			};
		}

		Bg.exit({
			"OpenWeatherMapCurrent" => result
		});
	}

	(:background_method)
	function onReceiveSLData(responseCode, data) {
		var result = {}; 
		// Useful data only available if result was successful.
		// Filter and flatten data response for data that we actually need.
		if (responseCode == 200) {
			var filteredData = data["ResponseData"]["Trains"];
			var tempRow = {};
			var rowsArray = [];
			var numRows = ( filteredData.size() > 4 ) ? 4 : filteredData.size(); //do not return more than 4 departures

			for(var i = 0; i < numRows; i++) {
				tempRow = {
					"time" => filteredData[i]["ExpectedDateTime"],
					"line" =>filteredData[i]["LineNumber"],
					"dest" => filteredData[i]["Destination"],
					"displayTime" => filteredData[i]["DisplayTime"]
				};
				rowsArray.add(tempRow);
			}
			result.put("CurrentDepartures", rowsArray);
		} 
		else {  //HTTP error
			var errorMessage = "";
			if(data != null) {
				errorMessage = data["StatusCode"];
			}
			result = {
				"httpError" => responseCode,
				"message" => errorMessage
			};
		}
		Background.exit( 
			{ "SLDepartures" => result } 
		);
	
	}

	// helper method to make actual web requests..
	(:background_method)
	function makeWebRequest(url, params, callback) {
		var options = {
			:method => Comms.HTTP_REQUEST_METHOD_GET,
			:headers => {
					"Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
			:responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON
		};

		Comms.makeWebRequest(url, params, options, callback);
	}
}
