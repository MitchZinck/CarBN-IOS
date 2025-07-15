# CarBN - Car Collection & Trading App

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/ca/app/carbn/id6742416359)

CarBN is an innovative iOS app that lets you scan, collect, and trade virtual cars with friends. Discover rare vehicles, build your dream collection, and engage with a community of car enthusiasts.

## Features

### 🚗 Car Scanning & Collection
- **AI-Powered Recognition**: Scan real cars using your camera to identify and collect them
- **Detailed Car Profiles**: View comprehensive specifications including horsepower, top speed, acceleration, and more
- **High-Quality Images**: Upgrade to premium images for your favorite cars
- **Rarity System**: Discover and collect rare vehicles with different rarity levels

### 👥 Social Features
- **Friend System**: Connect with other car enthusiasts and view their collections
- **Global & Friends Feed**: See recent scans and trades from the community
- **Like System**: Show appreciation for friends' car discoveries and trades
- **Real-time Notifications**: Stay updated on friend requests, trades, and likes

### 🔄 Trading System
- **Car Trading**: Propose and negotiate trades with friends
- **Trade History**: Track your completed trades and collection growth
- **Smart Matching**: Find friends with cars you want and vice versa

### 💎 Subscription Tiers
- **Free Tier**: 6 scan credits to get started
- **Basic**: 30 scans per month
- **Standard**: 60 scans per month  
- **Premium**: 100 scans per month

### 🔐 Secure Authentication
- Sign in with Google or Apple ID
- Secure token-based authentication
- Profile management with custom avatars

## Technical Stack

### Frontend (iOS)
- **Framework**: SwiftUI
- **Architecture**: MVVM with observable objects
- **Authentication**: Google Sign-In & Sign in with Apple
- **Image Handling**: Custom caching and async loading
- **UI Components**: Native SwiftUI with custom styling

### Backend Integration
- **API**: RESTful Go backend
- **Authentication**: JWT token-based
- **Image Processing**: AI-powered car recognition
- **Real-time Features**: Feed updates and notifications

## Development Setup

### Prerequisites
- Xcode 15.0+
- iOS 16.0+ deployment target
- Valid Apple Developer account
- Google Cloud Platform account (for Google Sign-In)

### Configuration
1. Clone the repository
2. Create `Info.plist` from `Info.plist.example`
3. Add your Google Sign-In configuration:
   ```xml
   <key>GIDClientID</key>
   <string>YOUR_GOOGLE_CLIENT_ID</string>
   ```
4. Configure backend API endpoints in `APIConstants.swift`
5. Build and run the project

### Dependencies
- GoogleSignIn: Authentication
- No external package dependencies - uses native iOS frameworks

## Contributing

This is a closed-source project. For bug reports or feature requests, please contact the development team.

## Privacy & Security

- User data is encrypted in transit and at rest
- No personal data is shared without explicit consent
- Images are processed securely for car recognition
- Authentication tokens are stored securely in iOS Keychain

## Support

For support, feature requests, or bug reports, please contact us through the App Store or visit our website.

## License

Copyright © 2025 CarBN. All rights reserved.
