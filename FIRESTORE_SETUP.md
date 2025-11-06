# Firestore Setup Guide

This document explains how to configure Firestore for the NotifiApp to work properly.

## Issue: "User data not found" in ProfileView

If you're seeing "User data not found" in the ProfileView, it means your Firestore document wasn't created during signup. This can happen due to:

1. **Missing Firestore Security Rules** - The app couldn't write to Firestore during signup
2. **Missing Firestore Index** - The app can't query users by email
3. **Incomplete Signup** - Signup was interrupted before the Firestore document was created

## Solution: Configure Firestore

### Step 1: Update Firestore Security Rules

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **georeminder-pilot**
3. Navigate to **Firestore Database** → **Rules**
4. Copy and paste the rules from `firestore.rules` file in this repository
5. Click **Publish**

The key rules needed:
```
allow read: if request.auth != null;
allow create: if request.auth != null;
```

### Step 2: Create Firestore Index for Email Queries

The ProfileView queries users by email field. Firestore requires an index for this:

1. In Firebase Console, go to **Firestore Database** → **Indexes**
2. Click **Create Index**
3. Set the following:
   - **Collection ID**: `users`
   - **Fields to index**:
     - Field: `email`, Mode: `Ascending`
   - **Query scope**: `Collection`
4. Click **Create**

**OR** let Firestore auto-create the index:
1. Run the app and try to view your profile
2. Check the Xcode console for an error message with a URL
3. Click the URL to auto-create the required index
4. Wait 1-2 minutes for the index to build

### Step 3: Re-signup if Needed

If your user account was created before fixing the Firestore rules:

1. **Sign Out** from the app
2. **Sign Up again** with a new username (or delete your Firebase Auth user first)
3. The signup should now properly create your Firestore document

## Debugging

### Check Console Logs

The app now includes detailed logging. Open Xcode console while running the app:

**During Signup:**
```
SignupViewModel: Creating user document with ID: username
SignupViewModel: User data to save: [email, name, userId, joined]
SignupViewModel: User 'username' created successfully in Firestore
```

**During Profile Load:**
```
ProfileViewModel: Fetching user with email: user@email.com
ProfileViewModel: Query returned 1 documents
ProfileViewModel: Found user data: [...]
```

If you see errors in the console, they will indicate the specific problem.

### Verify Data in Firebase Console

1. Go to Firebase Console → Firestore Database → Data
2. Check if the `users` collection exists
3. Check if your user document exists (document ID should be your username)
4. Verify the document has fields: `userId`, `name`, `email`, `joined`

## Common Issues

### "Missing or insufficient permissions"
- **Cause**: Firestore security rules not deployed
- **Fix**: Deploy the `firestore.rules` from this repo (see Step 1 above)

### "User data not found"
- **Cause**: Firestore document not created during signup
- **Fix**: Re-signup after deploying security rules (see Step 3 above)

### "The query requires an index"
- **Cause**: Missing Firestore index for email field
- **Fix**: Create the index (see Step 2 above)

## Need Help?

If you're still experiencing issues:
1. Check the Xcode console for error messages
2. Verify your Firebase configuration in `GoogleService-Info.plist`
3. Ensure you're using the correct Firebase project
