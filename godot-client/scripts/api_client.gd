extends Node

const BASE_URL = "http://localhost:8000"

# Fetch location data
func get_location(location_id: int):
	var url = BASE_URL + "/locations/" + str(location_id)
	print("Requesting: ", url)
	
	var http = HTTPRequest.new()
	add_child(http)
	
	var error = http.request(url)
	if error != OK:
		push_error("HTTP Request failed with error: ", error)
		return null
	
	var result = await http.request_completed
	var response_code = result[1]
	var body = result[3]
	
	print("Response code: ", response_code)
	print("Response body: ", body.get_string_from_utf8())
	
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		return json
	else:
		push_error("API returned status code: ", response_code)
	
	http.queue_free()
	return null

# Fetch planet data
func get_planet(planet_id: int):
	var url = BASE_URL + "/locations?planet_id=" + str(planet_id)
	# Similar HTTP request logic...
	pass
