# DAT SDK for iOS v0.4 — Full Reference

> Source: https://wearables.developer.meta.com/llms.txt?full=true

## Section 1: Guides

### Setup

#### Overview

The Wearables Device Access Toolkit supports iOS and Android mobile platforms, with the same OS version requirements as the Meta AI app (iOS 15.2+ and Android 10+).

Xcode 14.0+ is supported for iOS. Android Studio Flamingo or newer is supported for Android.

#### Hardware requirements

Currently, the SDK supports the Ray-Ban Meta glasses (Gen 1 and Gen 2) and Meta Ray-Ban Display glasses. You can test with a simulated device using Mock Device Kit, or directly with a device. Detailed version support of the Meta AI app and glasses firmware is located in the Version Dependencies page.

#### Setting up your glasses

To set up your glasses for development:

1. Ensure your Meta AI app version is v254+.
2. Ensure your glasses software is version v20+ for Ray-Ban Meta glasses or v21+ for Meta Ray-Ban Display glasses. Follow the instructions below to verify your current version.
3. Connect your glasses to the Meta AI app.
4. Enable developer mode (instructions below).

##### Verify glasses software version

1. In the Meta AI app, go to the Devices tab (the glasses icon at the bottom of the app), and select your device.
2. Tap the gear icon to open Device settings.
3. Tap General > About > Version.
4. You should have the minimum supported version or above installed on your glasses, as outlined in the version dependencies documentation.
5. If your version is below minimum support requirements, update your glasses software.

##### Enable developer mode in the Meta AI app

1. On your iOS or Android device, select Settings > App Info, and then tap the App version number five times to display the toggle for developer mode.
2. Select the toggle to enable Developer Mode.
3. Click Enable to confirm.

### Integration overview

#### Overview

The Wearables Device Access Toolkit lets your mobile app integrate with supported AI glasses. An integration establishes a session with the device so your app can access supported sensors on the user's glasses. Users start a session from your app, and then interact through their glasses. They can:

* Speak to your app through the device's microphones
* Send video or photos from the device's camera
* Pause, resume, or stop the session by tapping the glasses, taking them off, or closing the hinges
* Play audio to the user through the device's speakers

#### Supported device

Ray-Ban Meta (Gen 1 and Gen 2) and Meta Ray-Ban Display glasses are supported by the Meta Wearables Device Access Toolkit.

#### Integration lifecycle

1. **Registration**: The user connects your app to their wearable device by tapping a call-to-action in your app. This is a one-time flow. After registration, your app can identify and connect to the user's device when your app is open. The flow deeplinks the user to the Meta AI app for confirmation, then returns them to your app.
2. **Permissions**: The first time your app attempts to access the user's camera, you must request permission. The user can allow always, allow once, or deny. Your app deeplinks the user to the Meta AI app to confirm the requested permission, and then Meta AI returns them to your app. Microphone access uses the Hands-Free Profile (HFP), so you request those permissions through iOS or Android platform dialogs.
3. **Session**: After registration and permissions, the user can start a session. During a session, the user engages with your app on their device.

#### Sessions

All integrations with Meta AI glasses run as sessions. Only one session can run on a device at a time, and certain features are unavailable while your session is active. Users can pause, resume, or stop your session by closing the hinges, taking the glasses off (when wear detection is enabled), or tapping the glasses. Learn more in Session lifecycle.

#### Key components

`MWDATCore` is the foundation for your integration. It handles:
- App registration with the user's device and registration state
- Device discovery and management
- Permission requests and state management
- Telemetry

`MWDATCamera` handles camera access and:
- Resolution and frame rate selection
- Starting a video stream and sending/listening for pause, resume, and stop signals
- Receiving frames from devices
- Capturing a single frame during a stream and delivering it to your app
- Photo format

##### Microphones and speakers

Use mobile platform functions to access the device over Bluetooth. To use the device's microphones for input, use HFP (Hands-Free Profile). Audio is streamed as 8 kHz mono from the device to your app.

##### App management

After registration, your app appears in the user's App Connections list in the Meta AI app, where permissions can be unregistered or managed.

### Integrate Wearables Device Access Toolkit into your iOS app

#### Overview

This guide explains how to add Wearables Device Access Toolkit registration, streaming, and photo capture to an existing iOS app. For a complete working sample, compare with the provided sample app.

#### Prerequisites

Complete the environment, glasses, and GitHub configuration steps in Setup.

Your integration must use a registered bundle identifier. To register or manage bundle IDs, see Apple's Register an App ID and Bundle IDs documentation.

#### Step 1: Add info properties

In your app's `Info.plist` or using Xcode UI, insert the required keys so the Meta AI app can callback to your app and discover the glasses. `AppLinkURLScheme` is required so that the Meta AI app can callback to your application.

Add the `MetaAppID` key to provide the Wearables Device Access Toolkit with your application ID - omit or use `0` for it if you are using Developer Mode. Published apps receive a dedicated value from the Wearables Developer Center.

**Note**: If you pre-process `Info.plist`, the `://` suffix will be stripped unless you add the `-traditional-cpp` flag. See Apple Technical Note TN2175.

```xml
<!-- Configure custom URL scheme for Meta AI callbacks -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myexampleapp</string>
    </array>
  </dict>
</array>

<!-- Allow Meta AI (fb-viewapp) to call the app -->
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>fb-viewapp</string>
</array>

<!-- External Accessory protocol for Meta Wearables -->
<key>UISupportedExternalAccessoryProtocols</key>
<array>
  <string>com.meta.ar.wearable</string>
</array>

<!-- Background modes for Bluetooth and external accessories -->
<key>UIBackgroundModes</key>
<array>
  <string>bluetooth-peripheral</string>
  <string>external-accessory</string>
</array>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Needed to connect to Meta Wearables</string>

<!-- Wearables Device Access Toolkit configuration -->
<key>MWDAT</key>
<dict>
  <key>AppLinkURLScheme</key>
  <string>myexampleapp://</string>
  <key>MetaAppID</key>
  <string>0</string>
</dict>
```

#### Step 2: Add the SDK Swift package

Add the SDK through Swift Package Manager.

1. In Xcode, select **File** > **Add Package Dependencies...**
2. Search for `https://github.com/facebook/meta-wearables-dat-ios` in the top right corner.
3. Select `meta-wearables-dat-ios`.
4. Set the version to one of the available versions.
5. Click **Add Package**.
6. Select the target to which you want to add the package.
7. Click **Add Package**.

Import the required modules in any Swift files that use the SDK.

```swift
import MWDATCamera
import MWDATCore
```

#### Step 3: Initialize the SDK

Call `Wearables.configure()` once when your app launches.

```swift
func configureWearables() {
  do {
    try Wearables.configure()
  } catch {
    assertionFailure("Failed to configure Wearables SDK: \(error)")
  }
}
```

#### Step 4: Launch registration from your app

Register your application with the Meta AI app either at startup or when the user wants to turn on your wearables integration.

```swift
func startRegistration() throws {
  try Wearables.shared.startRegistration()
}

func startUnregistration() throws {
  try Wearables.shared.startUnregistration()
}

func handleWearablesCallback(url: URL) async throws {
  _ = try await Wearables.shared.handleUrl(url)
}
```

Observe registration and device updates.

```swift
let wearables = Wearables.shared

Task {
  for await state in wearables.registrationStateStream() {
    // Update your registration UI or model
  }
}

Task {
  for await devices in wearables.devicesStream() {
    // Update the list of available glasses
  }
}
```

#### Step 5: Manage camera permissions

Check permission status before streaming and request access if necessary.

```swift
var cameraStatus: PermissionStatus = .denied
...
cameraStatus = try await wearables.checkPermissionStatus(.camera)
...
cameraStatus = try await wearables.requestPermission(.camera)
```

#### Step 6: Start a camera stream

Create a `StreamSession`, observe its state, and display frames. You can use an auto device selector to make smart decision for the user to select a device. This example uses `AutoDeviceSelector` to make a decision for the user. Alternatively, you can use a specific device selector, `SpecificDeviceSelector`, if you provide a UI for the user to select a device.

You can request resolution and frame rate control using `StreamSessionConfig`. Valid `frameRate` values are `2`, `7`, `15`, `24`, or `30` FPS. `resolution` can be set to:

- `high`: 720 x 1280
- `medium`: 504 x 896
- `low`: 360 x 640

`StreamSessionState` transitions through `stopping`, `stopped`, `waitingForDevice`, `starting`, `streaming`, and `paused`.

Register callbacks to collect frames and state events.

```swift
// Let the SDK auto-select from available devices
let deviceSelector = AutoDeviceSelector(wearables: wearables)
let config = StreamSessionConfig(
  videoCodec: VideoCodec.raw,
  resolution: StreamingResolution.low,
  frameRate: 24)
streamSession = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)

let stateToken = session.statePublisher.listen { state in
  Task { @MainActor in
    // Update your streaming UI state
  }
}

let frameToken = session.videoFramePublisher.listen { frame in
  guard let image = frame.makeUIImage() else { return }
  Task { @MainActor in
    // Render the frame in your preview surface
  }
}

Task { await session.start() }
```

Resolution and frame rate are constrained by the Bluetooth Classic connection between the user's phone and their glasses. To manage limited bandwidth, an automatic ladder reduces quality as needed. It first lowers the resolution by one step (for example, from High to Medium). If bandwidth remains constrained, it then reduces the frame rate (for example, 30 to 24), but never below 15 fps.

The image delivered to your app may appear lower quality than expected, even when the resolution reports "High" or "Medium." This is due to per-frame compression that adapts to available Bluetooth Classic bandwidth. Requesting a lower resolution, a lower frame rate, or both can yield higher visual quality with less compression loss.

#### Step 7: Capture and share photos

Listen for `photoDataPublisher` events and handle the returned `PhotoData`. Then, when a stream session is active, call `capturePhoto`.

```swift
_ = session.photoDataPublisher.listen { photoData in
  let data = photoData.data
  // Convert to UIImage or hand off to your storage layer
}

session.capturePhoto(format: .jpeg)
```

### Session lifecycle

#### Overview

The Wearables Device Access Toolkit runs work inside sessions. Meta glasses expose two experience types:

- **Device sessions** grant sustained access to device sensors and outputs.
- **Transactions** are short, system-owned interactions (for example, notifications or "Hey Meta").

When your app requests a device session, the glasses grant or revoke access as needed, the app observes state, and the system decides when to change it.

#### Device session states

`SessionState` is device-driven and delivered asynchronously through `StateFlow`.

| State     | Meaning                                  | App expectation                       |
|-----------|------------------------------------------|---------------------------------------|
| `STOPPED` | Session is inactive and not reconnecting | Free resources. Wait for user action. |
| `RUNNING` | Session is active and streaming data     | Perform live work.                    |
| `PAUSED`  | Session is temporarily suspended         | Hold work. Paths may resume.          |

**Note:** `SessionState` does not expose the reason for a transition.

#### Common device session transitions

The device can change `SessionState` when:

- The user performs a system gesture that opens another experience.
- Another app or system feature starts a device session.
- The user removes or folds the glasses, disconnecting Bluetooth.
- The user removes the app from the Meta AI companion app.
- Connectivity between the companion app and the glasses drops.

#### Pause and resume

When `SessionState` changes to `PAUSED`:

- The device keeps the connection alive.
- Streams stop delivering data while paused.
- The device resumes streaming by returning to `RUNNING`.

Your app should not attempt to restart a device session while it is paused.

#### Device availability

Use device metadata to detect availability. Hinge position is not exposed, but it influences connectivity.

Expected effects:

- Closing the hinges disconnects Bluetooth, stops active streams, and forces `SessionState` to `STOPPED`.
- Opening the hinges restores Bluetooth when the glasses are nearby, but does not restart the device session. Start a new session after `metadata.available` becomes `true`.

### Permissions and registration

#### Overview

The Wearables Device Access Toolkit separates app registration and device permissions. All permission grants occur through the Meta AI app. Permissions work across multiple linked wearables.

Camera permissions are granted at the app level. However, each device will need to confirm permissions specifically, in turn allowing your app to support a set of devices with individual permissions.

#### Registration

Your app registers with the Meta AI app to be a permitted integration. This establishes the connection between your app and the glasses platform. Registration happens once through Meta AI app with glasses connected. Users see your app name in the list of connected apps. They can unregister anytime through the Meta AI app. You can also implement an unregistration flow if desired.

#### Device permissions

After registration, request specific permissions. The Meta AI app runs the permission grant flow. Users choose **Allow once** (temporary) or **Allow always** (persistent).

- Without registration, permission requests fail.
- With registration but no permissions, your app connects but cannot access camera.

#### Multi-device permission behavior

Users can link multiple glasses to Meta AI. The toolkit handles this transparently.

##### How it works

Users can have multiple pairs of glasses. Permission granted on any linked device allows your app to use that feature. When checking permissions, Wearables Device Access Toolkit queries all connected devices. If any device has the permission granted, your app receives "granted" status.

##### Practical implications

You don't track which specific device has permissions. Permission checks return granted if _any_ connected device has approved. If all devices disconnect, permission checks will indicate unavailability. Users manage permissions per device in the Meta AI app.

#### Distribution and registration

Testing vs. production have different permission requirements. When developer mode is activated, registration is always allowed. When a build is distributed, users must be in the proper release channel to get the app. This is controlled by the `MWDAT` application ID.

### Use device microphones and speakers

#### Overview

Device audio uses two Bluetooth profiles:

- A2DP (Advanced Audio Distribution Profile) for high-quality, output-only media
- HFP (Hands-Free Profile) for two-way voice communication

#### Integrating sessions with HFP

Wearables Device Access Toolkit sessions share microphone and speaker access with the system Bluetooth stack on the glasses.

#### iOS sample code

```swift
// Set up the audio session
let audioSession = AVAudioSession.sharedInstance()
try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth])
try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
```

**Note:** When planning to use HFP and streaming simultaneously, ensure that HFP is fully configured before initiating any streaming session that requires audio functionality.

```swift
func startStreamSessionWithAudio() async {
  // Set up the HFP audio session
  startAudioSession()

  // Instead of waiting for a fixed 2 seconds, use a state-based coordination that waits for HFP to be ready
  try? await Task.sleep(nanoseconds: 2 * NSEC_PER_SEC)

  // Start the stream session as usual
  await streamSession.start()
}
```

### Mock Device Kit

#### Overview

Mock Device Kit is a component of the Device Access Toolkit that helps you build and test integrations for Meta glasses, without the need to access the actual hardware.

This kit provides a simulated device that mirrors the capabilities and behavior of Meta glasses, including camera, media streaming, permissions, and device state changes. You can use it to test your app integrations in a virtual environment.

#### Mock Device Kit in the CameraAccess sample

To connect to a simulated device using the sample app:

1. Tap the **Debug icon** on your mobile device. You will see the Mock Device Kit menu open.
2. Tap **Pair RayBan Meta**. A Mock Device card is then added to the view.
3. Swipe down the **Mock Device Kit** menu. The new device should now be available.

#### Changing state

Now that your mock device is paired, you can alter the state of your virtual device:

- To simulate powering on the glasses, tap **PowerOn**. The device must change to "Connected" on the main screen.
- To simulate unfolding the glasses, tap **Unfold**. The device is now ready for streaming.
- To simulate putting on the glasses, tap **Don**.

**Note**: CameraAccess automatically checks camera permissions when you start streaming. If permission isn't granted, the app redirects to Meta AI to complete the flow.

#### Simulating media streaming

To test your app's media handling capabilities, you can configure the Mock Device Kit with sample media files that simulate video streaming and photo capture from the glasses.

##### Streaming video

1. Set your mock device to **Unfold**.
2. Click **Select video** and select any supported video. This video will be used as mock streaming video.

    **Note**: Android doesn't transcode video automatically. Any video used here must be in h265 format. To transcode a video to h265, you can use FFmpeg. For example:

    ```bash
    ffmpeg -hwaccel videotoolbox -i input_video.mp4 -c:v hevc_videotoolbox -c:a aac_at -tag:v hvc1 -vf "scale=540:960" output_video.mov
    ```

##### Image capture

1. Tap **Select image** and select any supported photo. This photo will be used as a mock capture result.
2. Go to the main screen, navigate to the device, and start streaming. You can try capture here as well.

### iOS testing with Mock Device Kit

#### Overview

Use this guide when your iOS project already integrates the Wearables Device Access Toolkit and you need to test without physical glasses.

#### Set up Mock Device Kit in XCTest

Create a reusable base rule or test class that configures Mock Device Kit, grants permissions, and resets state.

```swift
import XCTest
import MetaWearablesDAT

@MainActor
class MockDeviceKitTestCase: XCTestCase {
    private var mockDevice: MockRaybanMeta?
    private var cameraKit: MockCameraKit?

    override func setUp() async throws {
        try await super.setUp()
        try? Wearables.configure()
        mockDevice = MockDeviceKit.shared.pairRaybanMeta()
        cameraKit = mockDevice?.getCameraKit()
    }

    override func tearDown() async throws {
        MockDeviceKit.shared.pairedDevices.forEach { device in
            MockDeviceKit.shared.unpairDevice(device)
        }
        mockDevice = nil
        cameraKit = nil
        try await super.tearDown()
    }
}
```

#### Configure camera feeds for streaming tests

Mock camera feeds let you verify streaming and capture workflows without video hardware.

##### Provide a mock video feed

```swift
guard let device = MockDeviceKit.shared.pairRaybanMeta() else { return }
let camera = device.getCameraKit()
await camera.setCameraFeed(fileURL: videoURL)
```

##### Provide a captured photo

```swift
guard let device = MockDeviceKit.shared.pairRaybanMeta() else { return }
let camera = device.getCameraKit()
await camera.setCapturedImage(fileURL: imageURL)
```

### Onboarding and organization management

Wearables Developer Center manages the full lifecycle of wearables integrations, from development and testing to app sharing. It oversees integration projects, versions, and release channels.

#### One organization per company

**Important:** Each company must have only **one** Managed Meta Account (MMA) organization in Admin Center. **Do not create a new MMA organization if one already exists for your company.**

#### Key terms

| Term                           | Definition                                                                     |
|--------------------------------|--------------------------------------------------------------------------------|
| **Managed Meta Account (MMA)** | A Meta account managed by an organization admin for secure access and control. |
| **Admin Center**               | A portal for managing IT tasks related to people management and security.      |
| **Organization**               | Represents your company in Admin Center                                        |
| **Team**                       | A group within Wearables Developer Center representing your project team.      |

### Manage projects

Once you have onboarded, you can create a project or manage existing ones in Meta Wearables Developer Center.

#### Application ID integration

To register your application successfully (without using Developer Mode), you must include the Wearables Application ID in your app's manifest and pass it in the registration call.

#### Product listing

**App name and icon**:
- Provide your app's name and an icon (PNG or JPEG).
- Separate icons for dark and light mode are supported.
- Maximum supported dimensions: 200x200 pixels.

#### Permissions

If your app or project needs access to device functionality like the camera, you must provide a justification in the **Permissions** tab. Currently, the only permission is camera, but new device capabilities will be added in future iterations.

### Set up versions and release channels

#### Understand versions

- **Major (e.g., 2.3.4 to 3.0.0):** Significant changes or API revisions
- **Minor (e.g., 2.3.4 to 2.4.0):** New features, backwards compatible
- **Patch (e.g., 2.3.4 to 2.3.5):** Bug fixes and minor improvements

#### Release channel options

- **Invite-only channels:** All release channels for Device Access Toolkit are currently invite-only.
- **Limitations:** Up to 3 channels per integration, max 100 users per channel.
- Testers may accept or decline invitations and can remove themselves at any time.

### Known issues

| Issue | Workaround |
|---|---|
| If there isn't an internet connection present, your app may fail to connect with the Wearables Developer Access Toolkit, and you may not be able to register your app in developer mode. | An internet connection is required for registration. |
| Streams that are started with the glasses doffed are paused when they glasses are donned. | None at this time. You can unpause by tapping the side of your glasses. |
| `DeviceStateSession` (iOS) and `DeviceSession` (Android) are not reliable in combination with a camera stream session. | Avoid using `DeviceStateSession` (iOS) and `DeviceSession` (Android) at this time. Their omission will not affect camera functionality. |
| **[iOS-only]** Meta Ray-Ban Display glasses don't play "Experience paused"/"Experience started" when pausing or resuming the session using captouch gestures. | This issue will be resolved in a future SDK release. |

### Version Dependencies

#### 0.4.0

| App/Firmware | Support |
|---|---|
| Meta AI App (Android) | V254 |
| Meta AI App (iOS) | V254 |
| Ray-Ban Meta glasses | V20 |
| Meta Ray-Ban Display glasses | V21 |

#### 0.3.0

| App/Firmware | Support |
|---|---|
| Meta AI App (Android) | V249 |
| Meta AI App (iOS) | V249 |
| Ray-Ban Meta glasses | V20 |

---

## Section 2: API Reference

### DecoderError (enum)
Errors that can occur during media decoding operations.

### PhotoCaptureFormat (enum)
Supported formats for capturing photos from Meta Wearables devices.

### StreamSession

A class for managing media streaming sessions with Meta Wearables devices. Handles video streaming and photo capture.

**Functions:**
- `start()` — Starts video streaming from the device.
- `stop()` — Stops video streaming and releases all resources.
- `capturePhoto(format:)` — Captures a still photo during streaming.

**Properties:**
- `streamSessionConfig` — The configuration used for this streaming session.
- `state` — The current state of the streaming session.
- `statePublisher` — Publisher for streaming session state changes.
- `videoFramePublisher` — Publisher for video frames received from the streaming session.
- `photoDataPublisher` — Publisher for photo data captured during the streaming session.
- `errorPublisher` — Publisher for errors that occur during the streaming session.

### StreamingResolution (enum)
Valid Live Streaming resolutions. 9:16 aspect ratio.
- `high`: 720 x 1280
- `medium`: 504 x 896
- `low`: 360 x 640

### PhotoData

A photo captured from a Meta Wearables device.

**Properties:**
- `data` — The photo data in the specified format.
- `format` — The format of the captured photo data.

### StreamSessionConfig

Configuration for a media streaming session. Defines video codec, resolution, and frame rate.

**Properties:**
- `videoCodec` — The video codec to use for streaming.
- `resolution` — The resolution at which to stream video content.
- `frameRate` — The target frame rate for the streaming session. Valid values: 2, 7, 15, 24, 30.

### StreamSessionError (enum)
Errors that can occur during streaming sessions.

### StreamSessionState (enum)
Represents the current state of a streaming session: `stopping`, `stopped`, `waitingForDevice`, `starting`, `streaming`, `paused`.

### VideoCodec (enum)
Specifies the video codec to use for streaming.

### VideoFrame

Represents a single frame of video data.

**Functions:**
- `makeUIImage()` — Converts the video frame to a UIImage for display or processing.

**Properties:**
- `sampleBuffer` — Provides access to the underlying video sample buffer.

### VideoFrameSize

**Properties:**
- `width` — The width of the video frame in pixels.
- `height` — The height of the video frame in pixels.

### Announcer

A protocol for objects that can announce events to registered listeners.

**Functions:**
- `listen(callback:)` — Registers a listener for events of type T.

### AnyListenerToken

A token that can be used to cancel a listener subscription. When the token is no longer referenced, the subscription is automatically cancelled.

**Functions:**
- `cancel()` — Cancels the listener subscription asynchronously.

### AutoDeviceSelector

A device selector that automatically selects the best available device. Selects the first connected device by default.

**Functions:**
- `activeDeviceStream()` — Creates a stream of active device changes.

**Properties:**
- `activeDevice` — The currently active device identifier.

### Device

AI glasses accessible through the Wearables Device Access Toolkit.

**Functions:**
- `nameOrId()` — Returns the device name if available, otherwise returns the device identifier.
- `addLinkStateListener(callback:)` — Adds a listener for link state changes.
- `addCompatibilityListener(callback:)` — Adds a listener for compatibility changes.
- `deviceType()` — Returns the type of this device (e.g., Ray-Ban Meta).
- `compatibility()` — Returns true if the device version is compatible.

**Properties:**
- `identifier` — The unique identifier for this device.
- `name` — The human-readable device name, or empty string if unavailable.
- `linkState` — The current connection state of the device.

### DeviceSelector (protocol)

Protocol for selecting which device should be used for operations.

**Functions:**
- `activeDeviceStream()` — Creates a stream of active device changes.

**Properties:**
- `activeDevice` — The currently active device identifier, if any.

### DeviceState

Represents the current state of a device, including battery and hinge information.

**Properties:**
- `batteryLevel` — Battery level as a percentage (0-100).
- `hingeState` — The current state of the device's hinge mechanism.

### DeviceStateSession

Manages a session for monitoring device state changes.

**Functions:**
- `start()` — Starts the device state session.
- `stop()` — Stops the device state session.

**Properties:**
- `state` — The current state of the device session.

### DeviceType (enum)
Types of Meta Wearables devices supported.

### HingeState (enum)
Physical state of the device's hinge mechanism.

### LinkState (enum)
Connection state between a device and the toolkit.

### Permission (enum)
Types of permissions that can be requested from AI glasses.

### PermissionError (enum)
Errors during permission requests.

### PermissionStatus (enum)
Status of a permission request.

### RegistrationError (enum)
Error conditions during registration.

### RegistrationState (enum)
Current state of user registration with the Meta Wearables platform.

### SessionState (enum)
Current state of a device session: `STOPPED`, `RUNNING`, `PAUSED`.

### SpecificDeviceSelector

A device selector that always selects a specific, predetermined device.

**Functions:**
- `activeDeviceStream()` — Creates a stream that immediately yields the specific device and then completes.

**Properties:**
- `activeDevice` — The currently active device identifier.

### UnregistrationError (enum)
Error conditions during unregistration.

### Wearables (enum)
The entry point for configuring and accessing the toolkit.
- `Wearables.configure()` — Initialize the SDK (call once at app launch).
- `Wearables.shared` — Access the `WearablesInterface` singleton.

### WearablesError (enum)
Errors during SDK configuration.

### WearablesHandleURLError (enum)
Errors during URL handling.

### WearablesInterface

The primary interface for the toolkit.

**Functions:**
- `addRegistrationStateListener(callback:)` — Listen for registration state changes (immediately called with current state).
- `registrationStateStream()` — Creates an `AsyncStream` for registration state.
- `startRegistration()` — Initiates registration with AI glasses.
- `handleUrl(url:)` — Handles callback URLs from Meta AI app.
- `startUnregistration()` — Initiates unregistration.
- `addDevicesListener(callback:)` — Listen for device list changes.
- `devicesStream()` — Creates an `AsyncStream` for device list.
- `deviceForIdentifier(id:)` — Fetch the Device object for a given identifier.
- `checkPermissionStatus(permission:)` — Check if a permission is granted.
- `requestPermission(permission:)` — Request a permission on AI glasses.
- `addDeviceSessionStateListener(device:callback:)` — Listen for session state changes for a specific device.

**Properties:**
- `registrationState` — Current registration state.
- `devices` — Current list of available devices.

### MockDevice

**Functions:**
- `powerOn()` — Powers on the mock device.
- `powerOff()` — Powers off the mock device.
- `don()` — Simulates putting on (donning) the device.
- `doff()` — Simulates taking off (doffing) the device.

**Properties:**
- `deviceIdentifier` — The unique device identifier.

### MockCameraKit

A suite for mocking camera functionality.

**Functions:**
- `setCameraFeed(fileURL:)` — Sets the camera feed from a video file.
- `setCapturedImage(fileURL:)` — Sets the captured image from an image file.

### MockDeviceKit (enum)
Entry-point for managing simulated Meta Wearables devices.
- `MockDeviceKit.shared` — The singleton interface.

### MockDeviceKitError (enum)
Errors when using MockDeviceKit.

### MockDeviceKitInterface

Interface for managing mock devices.

**Functions:**
- `pairRaybanMeta()` — Pairs a simulated Ray-Ban Meta device.
- `unpairDevice(device:)` — Unpairs a simulated device.

**Properties:**
- `pairedDevices` — List of all currently paired mock devices.

### MockDisplaylessGlasses (protocol)

Simulates displayless smart glasses behavior.

**Functions:**
- `fold()` — Simulates folding the glasses closed.
- `unfold()` — Simulates unfolding the glasses open.
- `getCameraKit()` — Gets the suite for mocking camera functionality.

### MockRaybanMeta (protocol)

Simulates Ray-Ban Meta smart glasses behavior. Inherits from MockDisplaylessGlasses.
