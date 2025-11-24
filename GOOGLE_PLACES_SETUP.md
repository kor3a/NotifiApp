# Google Places API Setup Guide

This guide will help you set up Google Places API to fetch real store photos in the NotifiApp.

## Step 1: Get Your API Key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Places API**:
   - Go to "APIs & Services" > "Library"
   - Search for "Places API"
   - Click on it and press "Enable"
4. Create an API Key:
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "API Key"
   - Copy your API key

## Step 2: Restrict Your API Key (Recommended)

To prevent unauthorized usage:

1. Click on your API key in the Credentials page
2. Under "Application restrictions":
   - Select "iOS apps"
   - Add your bundle identifier (e.g., `com.yourcompany.NotifiApp`)
3. Under "API restrictions":
   - Select "Restrict key"
   - Check "Places API"
4. Click "Save"

## Step 3: Add Your API Key to the App

Open the file: `Geolocation_v1.0.0/Services/GooglePlacesService.swift`

Find this line:
```swift
private let apiKey = "YOUR_GOOGLE_PLACES_API_KEY"
```

Replace `YOUR_GOOGLE_PLACES_API_KEY` with your actual API key:
```swift
private let apiKey = "AIzaSyD..."  // Your actual API key here
```

## Step 4: Enable Billing (Required)

Google Places API requires billing to be enabled:

1. Go to "Billing" in the Google Cloud Console
2. Link a billing account to your project
3. Note: Google provides $200 free credit per month, which covers most app usage

## Pricing Information

- **Places API - Nearby Search**: $32 per 1000 requests
- **Places API - Photo**: $7 per 1000 requests
- **Free tier**: First $200 of usage per month is free

For a typical user checking ~10 stores per day:
- Daily cost: $0.39
- Monthly cost: ~$12 (well within the free tier)

## Testing

After setting up:

1. Run the app on a simulator or device
2. Search for a store location
3. Select a store from the map
4. You should see a real photo of the store in the LocationDetailsView
5. Check the console logs for any errors like:
   - "Error fetching place photo: ..."
   - Network errors
   - API key issues

## Troubleshooting

### "API key not valid" error
- Make sure you copied the entire API key
- Check that Places API is enabled in your Google Cloud project
- Verify the API key restrictions match your app's bundle ID

### No photos appearing
- Some locations may not have photos in Google's database
- Check console logs for specific error messages
- Verify your internet connection

### "Quota exceeded" error
- You've exceeded your free tier limit
- Check your usage in the Google Cloud Console
- Consider increasing your budget or optimizing API calls

## Security Best Practices

1. **Never commit your API key to version control**
   - Add `GooglePlacesService.swift` to `.gitignore` if it contains your key
   - Or use environment variables/configuration files

2. **Use API key restrictions**
   - Always restrict by iOS bundle ID
   - Restrict to only the APIs you need

3. **Monitor usage**
   - Set up billing alerts in Google Cloud Console
   - Review usage regularly

## Alternative: Use Environment Variables

For better security, consider using a configuration file:

1. Create `Config.plist` (add to .gitignore)
2. Add your API key there
3. Read it in code:
```swift
private let apiKey: String = {
    guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
          let config = NSDictionary(contentsOfFile: path),
          let key = config["GooglePlacesAPIKey"] as? String else {
        fatalError("Google Places API key not found")
    }
    return key
}()
```

## Support

For more information:
- [Google Places API Documentation](https://developers.google.com/maps/documentation/places/web-service/overview)
- [Pricing Details](https://developers.google.com/maps/billing-and-pricing/pricing)
