# ReflectAI

A secure, AI-powered journaling and personal reflection application built with Flutter and Firebase.

## Setup Instructions

### 1. Flutter Frontend
1. Install Flutter SDK.
2. Create a new Flutter project: `flutter create reflect_ai`
3. Copy the contents of this repository into the new project.
4. Add the required dependencies to your `pubspec.yaml`:
   - `riverpod` (state management)
   - `go_router` (navigation)
   - `firebase_core`
   - `firebase_auth`
   - `cloud_firestore`
   - `google_sign_in`
   - `http` (for cloud functions)

### 2. Firebase Backend
1. Initialize Firebase in your project: `firebase init`
2. Navigate to the `functions` directory: `cd functions`
3. Install backend dependencies: `npm install`
4. Deploy functions: `firebase deploy --only functions`
5. Deploy security rules: `firebase deploy --only firestore`

## Architecture
- `lib/`: Flutter frontend code (feature-based architecture).
- `functions/`: TypeScript Cloud Functions for secure AI and data management.
- `firebase/`: Firestore rules and project configuration.
