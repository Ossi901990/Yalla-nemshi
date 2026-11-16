# Fonts Setup Guide

## Overview
The app now uses professional typography with:
- **Poppins** for headlines and bold text
- **Inter** for body text and UI

## Required Font Files

Place these font files in `assets/fonts/` directory:

### Poppins Family
- `Poppins-Regular.ttf` (weight: 400)
- `Poppins-Medium.ttf` (weight: 500)
- `Poppins-SemiBold.ttf` (weight: 600)
- `Poppins-Bold.ttf` (weight: 700)

### Inter Family
- `Inter-Regular.ttf` (weight: 400)
- `Inter-Medium.ttf` (weight: 500)
- `Inter-SemiBold.ttf` (weight: 600)
- `Inter-Bold.ttf` (weight: 700)

## Download Instructions

### Poppins Font
1. Go to [Google Fonts - Poppins](https://fonts.google.com/specimen/Poppins)
2. Download all weights (400, 500, 600, 700)
3. Extract and copy the `.ttf` files to `assets/fonts/`

### Inter Font
1. Go to [Google Fonts - Inter](https://fonts.google.com/specimen/Inter)
2. Download all weights (400, 500, 600, 700)
3. Extract and copy the `.ttf` files to `assets/fonts/`

## Alternative: Quick Download
- Download from [fonts.google.com](https://fonts.google.com)
- Search for "Poppins" and "Inter"
- Click "Download family" for each
- Extract and place in `assets/fonts/`

## Verify Setup
After adding fonts, run:
```bash
flutter pub get
flutter run
```

If fonts don't appear, try:
```bash
flutter clean
flutter pub get
flutter run
```

## Typography System

### Headlines (Poppins Bold)
- `displayLarge`: 32px, bold (App title)
- `displayMedium`: 28px, bold
- `displaySmall`: 24px, bold
- `headlineLarge`: 22px, semibold
- `headlineMedium`: 20px, semibold
- `headlineSmall`: 18px, semibold

### Body Text (Inter Regular)
- `bodyLarge`: 16px, regular
- `bodyMedium`: 14px, regular
- `bodySmall`: 12px, regular

### UI Elements (Inter Medium/SemiBold)
- `titleLarge`: 16px, semibold (Section headers)
- `titleMedium`: 14px, medium
- `titleSmall`: 12px, medium
- `labelLarge`: 14px, medium (Buttons, tags)
- `labelMedium`: 12px, medium
- `labelSmall`: 11px, medium

## Usage in Code

```dart
// Headline
Text('Walk Title', style: Theme.of(context).textTheme.headlineLarge)

// Body Text
Text('Description', style: Theme.of(context).textTheme.bodyMedium)

// Labels/Tags
Text('Private Walk', style: Theme.of(context).textTheme.labelMedium)
```

## Font Family Direct Usage

If you need to specify fonts directly:

```dart
// Poppins
Text('Title', style: TextStyle(fontFamily: 'Poppins', fontSize: 22))

// Inter
Text('Body', style: TextStyle(fontFamily: 'Inter', fontSize: 14))
```
