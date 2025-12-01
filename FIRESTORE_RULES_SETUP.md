# Firestore Security Rules Setup

## Problem
The admin cannot open the Content Moderation (Report Review) screen because Firestore denies read permission on the `reports` collection.

## Root Cause
Your current Firestore Security Rules don't allow admins to read the `reports` collection.

## Solution
Apply the new Firestore Security Rules below to your Firebase project.

### Step 1: Open Firebase Console Security Rules
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Firestore Database** > **Rules** tab
4. Replace the entire existing rules with the rules provided below

### Step 2: Updated Security Rules

Copy and paste the entire contents of `firestore.rules` (in this repo) into the Firebase Console Rules editor:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Default: deny all unless specified
    
    // Allow users to read/write their own documents
    match /users/{userId} {
      allow read: if request.auth.uid == userId;
      allow write: if request.auth.uid == userId;
      
      // Allow admins to read all users
      allow read: if request.auth.uid != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Events collection - allow authenticated users to read, club/admin to write
    match /events/{eventId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'club' || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
      allow update, delete: if request.auth != null && (resource.data.createdBy == request.auth.uid || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
    }
    
    // Reports collection - allow users to submit reports, admins to read/update
    match /reports/{reportId} {
      // Users can create reports
      allow create: if request.auth != null;
      
      // Users can read their own reports
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
      
      // Admins can read all reports and update status/notes
      allow read, update: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    // Clubs collection
    match /clubs/{clubId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && resource.data.createdBy == request.auth.uid;
    }
    
    // Categories collection - allow read for all, write for admins
    match /categories/{categoryId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### Step 3: Publish the Rules
1. Click **Publish** in the Firebase Console
2. Confirm the change

### Step 4: Test the Fix
1. In the app, sign out and sign back in as your admin user
2. Navigate to **Admin Dashboard** > **Moderate** tab
3. Click **Open** on the "Review Reports" card
4. You should now see pending reports without permission errors

## What Changed
The new rules allow:
- **Users**: Submit reports (create), read their own reports
- **Admins**: Read all reports, update report status and notes
- **All authenticated users**: Read events and clubs
- **Admins**: Write/update users and categories

## If You Still Get Permission Denied
1. Verify your user's Firestore `users/{uid}` document has `role: "admin"`
2. Sign out and back in (so AuthService refreshes role)
3. Check browser/device console for error logs (Firebase prints them)
4. Verify the rules were published (Firestore Rules tab should show the new rules)

## Security Notes
- These rules check the user's `role` field in the `users` collection
- Ensure each authenticated user has a `users/{uid}` document (the app creates one on login)
- For production, you may want to add additional checks (e.g., `status` field, rate limiting)
