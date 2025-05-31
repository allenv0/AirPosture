# AirPosture Codebase Structure

```mermaid
graph TD
    A[AirPostureApp] --> B[Core Functionality]
    A --> C[Data Models]
    A --> D[UI Components]
    A --> E[Utilities]
    
    B --> B1[HeadphoneMotionManager]
    B1 --> B1a[Motion Processing]
    B1 --> B1b[Posture Analysis]
    B1 --> B1c[Device Connection]
    
    C --> C1[Session]
    C --> C2[SessionStore]
    C2 --> C2a[Data Persistence]
    C2 --> C2b[Session Management]
    
    D --> D1[ContentView]
    D1 --> D1a[HeadVisualization]
    D1 --> D1b[PitchGraphView]
    D1 --> D1c[OrientationRow]
    
    D --> D2[SessionHistoryView]
    D2 --> D2a[SessionHistoryViewModel]
    D2 --> D2b[SessionData]
    D2 --> D2c[Charts]
    
    E --> E1[Extensions]
    E1 --> E1a[Clamped Values]
    E1 --> E1b[Pulse Effect]
```

## Component Descriptions

### Core Functionality
- **HeadphoneMotionManager**: Central class for motion data processing
  - Motion Processing: Handles raw sensor data
  - Posture Analysis: Calculates posture metrics
  - Device Connection: Manages AirPods connectivity

### Data Models
- **Session**: Represents a tracking session
- **SessionStore**: Manages session persistence and retrieval

### UI Components
- **ContentView**: Main application screen
  - HeadVisualization: 3D head representation
  - PitchGraphView: Posture timeline visualization
  - OrientationRow: Axis value displays
  
- **SessionHistoryView**: Historical data presentation
  - ViewModel: Handles data processing
  - Charts: Visualizes session metrics

### Utilities
- **Extensions**: Helper functionality
  - Clamped Values: Ensures values stay within ranges
  - Pulse Effect: Visual alert animation