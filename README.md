# HighPrioritySheet

A SwiftUI modifier to present a sheet above the current presentation stack, regardless of context.

## Instalation

HighPrioritySheet is available via Swift Package Manager.

```swift
dependencies: [
  .package(url: "https://github.com/mtzaquia/HighPrioritySheet.git", from: "1.0.0"),
],
```

## Usage

The API intentionally mimicks the native `.sheet(...)` modifier. The key difference here is that the high priority
sheet will always be presented on the top-most context - if the native sheet is presented, it will be presented over it,
otherwise it will be presented from the context it is attached.

```swift
import HighPrioritySheet
import SwiftUI

struct ContentView: View {
  @State private var sheet: UUID?
  @State private var highPrioritySheet: UUID?

  var body: some View {
    VStack {
      Button("Present sheet") {
        sheet = UUID()
      }

      Button("Present high priority sheet") {
        highPrioritySheet = UUID()
      }
    }
    .sheet(item: $sheet) { value in
      VStack {
        Text(value.uuidString)

        Button("Present high priority sheet") {
          highPrioritySheet = UUID()
        }
      }
    }
    .highPrioritySheet(item: $highPrioritySheet) { value in
      Text(value.uuidString)
    }
  }
}
```

To host the presentation from a key overlay `UIWindow` in the same scene, pass
`presentationHost: .overlayWindow`:

```swift
.highPrioritySheet(
  item: $highPrioritySheet,
  presentationHost: .overlayWindow
) { value in
  Text(value.uuidString)
}
```

## License

Copyright (c) 2026 @mtzaquia

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
