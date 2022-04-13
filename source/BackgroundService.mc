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
		System.println("Started onTemporalEvent..");
		var pendingWebRequests = App.getApp().getProperty("PendingWebRequests");
		//check if there are pending web requests
		if (pendingWebRequests != null) {
			//then check what type of web request it is
			if (pendingWebRequests["OpenWeatherMapCurrent"] != null) {
				
				System.println("getting weather!");
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
			else {
				System.println("Not implemented -getting SL departures!");
				//getSLDepartures();
			} 
		}
		else {
			Sys.println("onTemporalEvent() called with no pending web requests!");
		}
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
