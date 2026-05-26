import fs from 'node:fs/promises';
import process from 'node:process';
import {fileURLToPath} from 'node:url';

const TIME_ZONE = 'America/Los_Angeles';
const HENDERSON = {
  latitude: 36.0395,
  longitude: -114.9817,
};
const FETCH_TIMEOUT_MS = 8000;

const WEATHER_CODE_LABELS = new Map([
  [0, 'Clear'],
  [1, 'Mostly Sunny'],
  [2, 'Partly Cloudy'],
  [3, 'Cloudy'],
  [45, 'Foggy'],
  [48, 'Foggy'],
  [51, 'Light Drizzle'],
  [53, 'Drizzle'],
  [55, 'Heavy Drizzle'],
  [61, 'Light Rain'],
  [63, 'Rain'],
  [65, 'Heavy Rain'],
  [71, 'Light Snow'],
  [73, 'Snow'],
  [75, 'Heavy Snow'],
  [80, 'Light Showers'],
  [81, 'Showers'],
  [82, 'Heavy Showers'],
  [95, 'Thunderstorms'],
  [96, 'Thunderstorms With Hail'],
  [99, 'Thunderstorms With Hail'],
]);

function argValue(name, fallback = undefined) {
  const prefix = `${name}=`;
  const found = process.argv.find((arg) => arg.startsWith(prefix));
  return found ? found.slice(prefix.length) : fallback;
}

function roundTemp(value) {
  return Number.isFinite(value) ? Math.round(value) : null;
}

function conditionLabel(code) {
  return WEATHER_CODE_LABELS.get(Number(code)) || 'Conditions unavailable';
}

function localParts(date, timeZone = TIME_ZONE) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);

  return Object.fromEntries(parts.map((part) => [part.type, part.value]));
}

function localIsoMinute(date, timeZone = TIME_ZONE) {
  const parts = localParts(date, timeZone);
  return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}`;
}

function localTimeValue(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(value || '');
  if (!match) return Number.NaN;
  const [, year, month, day, hour, minute] = match.map(Number);
  return Date.UTC(year, month - 1, day, hour, minute);
}

function closestHourlyTemperature(data, reportTime) {
  const times = data?.hourly?.time || [];
  const temperatures = data?.hourly?.temperature_2m || [];
  const weatherCodes = data?.hourly?.weather_code || data?.hourly?.weathercode || [];
  const reportLocalTime = localTimeValue(localIsoMinute(reportTime));

  let closest = null;
  for (let index = 0; index < times.length; index += 1) {
    const temperature = temperatures[index];
    const hourlyTime = localTimeValue(times[index]);
    if (!Number.isFinite(temperature) || !Number.isFinite(hourlyTime)) continue;

    const distance = Math.abs(hourlyTime - reportLocalTime);
    if (!closest || distance < closest.distance) {
      closest = {
        temperature,
        weatherCode: weatherCodes[index],
        source: `hourly.temperature_2m closest to ${localIsoMinute(reportTime)}`,
        distance,
      };
    }
  }

  return closest;
}

function currentTemperature(data, reportTime) {
  if (Number.isFinite(data?.current?.temperature_2m)) {
    return {
      temperature: data.current.temperature_2m,
      weatherCode: data.current.weather_code ?? data.current.weathercode,
      source: 'data.current.temperature_2m',
    };
  }

  if (Number.isFinite(data?.current_weather?.temperature)) {
    return {
      temperature: data.current_weather.temperature,
      weatherCode: data.current_weather.weathercode,
      source: 'data.current_weather.temperature',
    };
  }

  const hourly = closestHourlyTemperature(data, reportTime);
  if (hourly) return hourly;

  return {
    temperature: null,
    weatherCode: null,
    source: 'unavailable',
  };
}

export function buildWeatherSection(data, reportTime = new Date()) {
  const current = currentTemperature(data, reportTime);
  const dailyHigh = roundTemp(data?.daily?.temperature_2m_max?.[0]);
  const dailyLow = roundTemp(data?.daily?.temperature_2m_min?.[0]);
  const dailyCondition = conditionLabel(data?.daily?.weather_code?.[0] ?? data?.daily?.weathercode?.[0]);
  const currentCondition = conditionLabel(current.weatherCode ?? data?.daily?.weather_code?.[0]);
  const currentTemp = roundTemp(current.temperature);
  const reportGenerationTime = localIsoMinute(reportTime);

  console.error(
    `[weather-debug] currentTemperatureSource=${current.source}; currentTemperature=${currentTemp ?? 'unavailable'}; dailyHigh=${dailyHigh ?? 'unavailable'}; dailyLow=${dailyLow ?? 'unavailable'}; reportGenerationTime=${reportGenerationTime} ${TIME_ZONE}`,
  );

  const currentLine =
    currentTemp === null
      ? `- **Current Conditions:** ${currentCondition}. (Weather)`
      : `- **Current Conditions:** ${currentTemp}°F and ${currentCondition}. (Weather)`;

  const forecastLine =
    dailyHigh === null || dailyLow === null
      ? `- **High / Low:** Unavailable. ${dailyCondition}. (Weather)`
      : `- **High / Low:** ${dailyHigh}°F / ${dailyLow}°F. (Weather)`;

  return `${currentLine}\n${forecastLine}`;
}

export async function fetchWeather() {
  const params = new URLSearchParams({
    latitude: String(HENDERSON.latitude),
    longitude: String(HENDERSON.longitude),
    current: 'temperature_2m,weather_code',
    hourly: 'temperature_2m,weather_code',
    daily: 'weather_code,temperature_2m_max,temperature_2m_min',
    temperature_unit: 'fahrenheit',
    wind_speed_unit: 'mph',
    timezone: TIME_ZONE,
    forecast_days: '2',
  });

  const url = `https://api.open-meteo.com/v1/forecast?${params}`;
  let lastError;

  for (let attempt = 1; attempt <= 3; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

    try {
      const response = await fetch(url, {signal: controller.signal});
      if (response.ok) return response.json();

      lastError = new Error(`Open-Meteo request failed: ${response.status} ${response.statusText}`);
    } catch (error) {
      lastError = error;
    } finally {
      clearTimeout(timeout);
    }

    if (attempt < 3) {
      await new Promise((resolve) => setTimeout(resolve, attempt * 750));
    }
  }

  throw lastError;
}

export async function loadWeatherData({fixturePath} = {}) {
  return fixturePath
    ? JSON.parse(await fs.readFile(fixturePath, 'utf8'))
    : await fetchWeather();
}

async function main() {
  const fixturePath = argValue('--fixture');
  const reportTime = new Date(argValue('--at', new Date().toISOString()));
  const data = await loadWeatherData({fixturePath});

  console.log(buildWeatherSection(data, reportTime));
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}