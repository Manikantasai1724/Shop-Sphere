# ShopSphere

ShopSphere is a Flutter product catalog backed by the live [DummyJSON Products API](https://dummyjson.com/docs/products).

## Features

- Home dashboard with featured products and API-driven categories
- Paginated two-column catalog with pull-to-refresh, sorting, and category filters
- Debounced API search
- Product details with image gallery and availability information
- Persistent wishlist using SharedPreferences
- Material 3 UI, cached images, loading, empty, retry, and error states

## Stack

Flutter/Dart, Dio, Riverpod, GoRouter, SharedPreferences, and CachedNetworkImage.

## API endpoints

`/products?limit=12&skip=n`, `/products/{id}`, `/products/search?q=query`,
`/products/categories`, and `/products/category/{slug}`.

## Run

```bash
flutter pub get
flutter run
```

## Download the Android APK

Every push to `main` runs the GitHub Actions workflow in
`.github/workflows/build-apk.yml`. Open the workflow run, download the
`ShopSphere-APK` artifact, unzip it if needed, and install the APK matching
your Android device. On a typical ARM64 phone, use `app-arm64-v8a-release.apk`.

Validate with:

```bash
dart format lib test
flutter analyze
flutter test
```

The application source is organized around models, API access, Riverpod controllers, and screen/widget sections in `lib/main.dart`. This keeps the sample easy to run while retaining clear separation between remote data, state, and presentation.
