## Live Activity setup

The Flutter side and the SwiftUI extension files are already prepared.

To finish enabling the feature in Xcode:

1. Open `ios/Runner.xcworkspace`.
2. Add a new `Widget Extension` target named `DocYaPacienteLiveActivity`.
3. Point that target to the files inside `ios/DocYaPacienteLiveActivity/`.
4. Embed the extension in `Runner`.
5. Enable `App Groups` on both `Runner` and the widget extension using:
   - `group.com.docya.paciente.liveactivities`
6. Keep `Push Notifications` enabled on `Runner`.
7. Confirm `NSSupportsLiveActivities = YES` in both `Runner` and the widget extension.
8. Use deployment target `iOS 16.1+` for the widget extension.

After that, `MedicoEnCaminoScreen` will start and update the Live Activity automatically.
