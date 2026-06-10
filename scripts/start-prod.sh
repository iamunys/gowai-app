cd .. && flutter run --dart-define="ENV=PROD"

##build bundle and ios : 
flutter build appbundle --release --dart-define="ENV=PROD"
flutter build ios --dart-define="ENV=PROD" 




flutter clean && flutter build appbundle --release --dart-define="ENV=PROD"

flutter clean && flutter build ios --dart-define="ENV=PROD" && open ios/Runner.xcworkspace



#While upload to production dont forget to change :

#claude claudeModel.
#claude token limit.