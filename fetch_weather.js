const fs = require('fs');
const path = require('path');

const locationFilePath = path.join(__dirname, 'config.json');
const configData = JSON.parse(fs.readFileSync(locationFilePath, 'utf-8'));
const locationData = configData.weather_settings;
const currentLocation = locationData.current_location;
const coords = locationData.locations[currentLocation];

if (!coords) {
  console.error('Location not found in config:', currentLocation);
  process.exit(1);
}

const { lat, lon } = coords;

const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max,wind_speed_10m_max,wind_direction_10m_dominant,uv_index_max,sunrise,sunset&hourly=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,is_day&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch&timezone=auto`;

// Weather code descriptions mapping
const weatherCodeMap = {
    0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Fog", 48: "Depositing rime fog", 51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle",
    61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain", 71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow",
    77: "Snow grains", 80: "Slight rain showers", 81: "Moderate rain showers", 82: "Violent rain showers",
    85: "Slight snow showers", 86: "Heavy snow showers", 95: "Thunderstorm", 96: "Thunderstorm with slight hail", 99: "Thunderstorm with heavy hail"
};

const getDirection = (degree) => {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return directions[Math.round(degree / 45) % 8];
};

async function fetchWeather() {
    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
        const data = await response.json();

        // Extract daily data for bottom list (next 6 days)
        const dailyForecast = data.daily.time.slice(1, 7).map((date, i) => {
            const idx = i + 1;
            return {
                dayName: new Date(date).toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', timeZone: 'UTC' }),
                high: Math.round(data.daily.temperature_2m_max[idx]),
                low: Math.round(data.daily.temperature_2m_min[idx]),
                condition: weatherCodeMap[data.daily.weather_code[idx]] || "Unknown",
                precipChance: data.daily.precipitation_probability_max[idx],
                windSpeed: Math.round(data.daily.wind_speed_10m_max[idx]),
                windDir: getDirection(data.daily.wind_direction_10m_dominant[idx])
            };
        });

        // Extract day/night data for today (Top Block)
        const todayDateStr = data.daily.time[0];
        const hourlyTimes = data.hourly.time;
        
        // Find approximate 2PM (14:00) and 10PM (22:00) index for today
        const dayIdx = hourlyTimes.findIndex(t => t === `${todayDateStr}T14:00`);
        const nightIdx = hourlyTimes.findIndex(t => t === `${todayDateStr}T22:00`);

        const getHourlyData = (idx) => ({
            temp: Math.round(data.hourly.temperature_2m[idx]),
            condition: weatherCodeMap[data.hourly.weather_code[idx]] || "Unknown",
            humidity: data.hourly.relative_humidity_2m[idx],
            windSpeed: Math.round(data.hourly.wind_speed_10m[idx]),
            windDir: getDirection(data.hourly.wind_direction_10m[idx])
        });

        const dayData = dayIdx >= 0 ? getHourlyData(dayIdx) : getHourlyData(14);
        const nightData = nightIdx >= 0 ? getHourlyData(nightIdx) : getHourlyData(22);

        const formatTime = (isoString) => {
            const date = new Date(isoString);
            return date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
        };

        const todaySummary = {
            location: currentLocation,
            date: new Date(todayDateStr).toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', timeZone: 'UTC' }),
            sunrise: formatTime(data.daily.sunrise[0]),
            sunset: formatTime(data.daily.sunset[0]),
            uvIndex: data.daily.uv_index_max[0],
            day: dayData,
            night: nightData,
            high: Math.round(data.daily.temperature_2m_max[0]),
            low: Math.round(data.daily.temperature_2m_min[0])
        };

        const weatherData = {
            today: todaySummary,
            forecast: dailyForecast
        };

        fs.writeFileSync(path.join(__dirname, 'weather_data.json'), JSON.stringify(weatherData, null, 2));
        console.log(`Successfully saved weather_data.json for ${currentLocation}.`);

    } catch (error) {
        console.error('Failed to fetch weather data:', error);
    }
}

fetchWeather();
