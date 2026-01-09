#!/bin/bash

echo "🚀 Starting Rating Seeder (Integration Test)..."
echo "⚠️  Ensure your emulator/device is connected and online."
echo "⚠️  Ensure Firestore Rules for 'app_ratings' are set to 'allow read, write: if true;'"

flutter test integration_test/seed_ratings_test.dart

echo "Done."
