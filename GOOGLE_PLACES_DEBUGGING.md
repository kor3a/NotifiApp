# Google Places API Debugging Guide

## You're not seeing photos or error messages? Let's debug!

I've added comprehensive logging to help identify the issue. Follow these steps:

## Step 1: Check Console Logs

When you run the app and select a location, you should see detailed console output with emojis. Look for these messages:

### Expected Log Flow:

```
🔄 LocationDetailsView: mapSelection changed
📍 LocationDetailsView: New selection detected, fetching photo...
🏪 LocationDetailsView: fetchStorePhoto called for 'Starbucks'
⏳ LocationDetailsView: Starting photo load...
🚀 GooglePlaces: Starting photo fetch for 'Starbucks'
🔍 GooglePlaces: Searching for 'Starbucks' at 37.7749, -122.4194
🌐 GooglePlaces: Request URL: https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=37.7749,-122.4194&radius=100&keyword=Starbucks&key=***API_KEY***
📡 GooglePlaces: HTTP Status Code: 200
📦 GooglePlaces: Raw Response: {...}
✅ GooglePlaces: API Status: OK
📊 GooglePlaces: Found 5 results
🏪 GooglePlaces: First result: Starbucks Coffee
📸 GooglePlaces: Photos available: 3
✅ GooglePlaces: Photo reference obtained: AUjq9jl...
🖼️ GooglePlaces: Generated photo URL: https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=AUjq9jl...&key=***API_KEY***
✅ GooglePlaces: Photo URL ready to use
✅ LocationDetailsView: Photo URL received: https://maps.googleapis.com/maps/api/place/photo?...
✅ LocationDetailsView: Photo loading completed
```

## Step 2: Common Issues and Solutions

### Issue 1: No Logs at All
**Problem:** Console shows nothing when selecting a location
**Solution:**
- Make sure the view is actually being shown
- Check that `mapSelection` is being set properly
- Verify the app is running in debug mode

### Issue 2: "API Status: REQUEST_DENIED"
**Problem:** API returns REQUEST_DENIED status
**Cause:** API key is invalid or not properly configured
**Solutions:**
- Double-check your API key in `GooglePlacesService.swift` line 16
- Verify Places API is enabled in Google Cloud Console
- Check if billing is enabled
- Make sure there are no extra spaces in the API key

### Issue 3: "API Status: ZERO_RESULTS"
**Problem:** No places found near the coordinates
**Cause:** The search radius is too small or name doesn't match
**Solutions:**
- This is normal for some locations
- Try increasing the radius in `GooglePlacesService.swift` line 27 (currently 100 meters)
- Change `&radius=100` to `&radius=500` or `&radius=1000`

### Issue 4: "Photos available: 0"
**Problem:** Place found but no photos
**Cause:** Some locations don't have photos in Google's database
**Solution:** This is normal - not all places have photos

### Issue 5: "HTTP Status Code: 403"
**Problem:** Forbidden error
**Cause:** API key restrictions or billing issue
**Solutions:**
- Check API key restrictions in Google Cloud Console
- Remove bundle ID restrictions temporarily for testing
- Verify billing is enabled

### Issue 6: No network logs appear
**Problem:** No network activity at all
**Cause:** Function might not be called
**Solution:**
- Look for `🔄 LocationDetailsView: mapSelection changed` in console
- If not present, the onChange isn't triggering
- Try selecting different locations on the map

## Step 3: Test Your API Key Manually

Open this URL in your browser (replace YOUR_API_KEY and coordinates):

```
https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=37.7749,-122.4194&radius=500&keyword=Starbucks&key=YOUR_API_KEY
```

Expected response:
```json
{
  "results": [
    {
      "name": "Starbucks",
      "photos": [
        {
          "photo_reference": "AUjq9jl...",
          "height": 3024,
          "width": 4032
        }
      ],
      ...
    }
  ],
  "status": "OK"
}
```

### Common API Responses:

**REQUEST_DENIED:**
```json
{
  "error_message": "This API project is not authorized to use this API.",
  "status": "REQUEST_DENIED"
}
```
→ Enable Places API in your project

**OVER_QUERY_LIMIT:**
```json
{
  "status": "OVER_QUERY_LIMIT"
}
```
→ Enable billing or wait for quota reset

**INVALID_REQUEST:**
```json
{
  "status": "INVALID_REQUEST"
}
```
→ Check URL parameters

## Step 4: Verify API Key Configuration

1. Open `GooglePlacesService.swift`
2. Check line 16: `private let apiKey = "YOUR_ACTUAL_KEY"`
3. Make sure:
   - No extra quotes
   - No spaces before/after the key
   - The key starts with `AIza`

## Step 5: Check Google Cloud Console

Visit: https://console.cloud.google.com/

1. **APIs & Services > Enabled APIs:**
   - Verify "Places API" is listed
   - If not, enable it

2. **APIs & Services > Credentials:**
   - Click on your API key
   - Check "API restrictions" - should include Places API
   - For testing, try removing "Application restrictions" temporarily

3. **Billing:**
   - Go to Billing section
   - Verify billing account is linked
   - Check you have remaining quota

## Step 6: Still Not Working?

Share the console logs with the developer. Specifically look for:
- The first emoji log that appears (or doesn't appear)
- Any error messages
- The HTTP status code
- The API status (OK, ZERO_RESULTS, REQUEST_DENIED, etc.)

## Quick Fix Checklist

- [ ] API key is correctly copied into `GooglePlacesService.swift`
- [ ] Places API is enabled in Google Cloud Console
- [ ] Billing is enabled in Google Cloud Console
- [ ] No extra spaces or characters in the API key
- [ ] API key restrictions allow your bundle ID (or are disabled for testing)
- [ ] You're testing with well-known locations (Starbucks, McDonald's, etc.)
- [ ] You're seeing console logs when selecting locations
- [ ] Internet connection is working

## Need More Help?

If you're still stuck, run the app and:
1. Select a location on the map
2. Copy ALL console output
3. Share it to identify the exact issue
