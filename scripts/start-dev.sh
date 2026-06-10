cd .. && flutter run --dart-define="ENV=DEV"


flutter clean && rm -rf pubspec.lock &&
cd android && ./gradlew clean &&
cd .. && flutter build appbundle --release --dart-define="ENV=DEV"


flutter clean && rm -rf pubspec.lock &&
 cd android && ./gradlew clean && 
 cd .. && flutter build apk --release --dart-define="ENV=DEV"




 ios :-

 flutter build ios --dart-define="ENV=DEV" && open ios/Runner.xcworkspace
