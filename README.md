# AirPosture



<p align="center">
<img src="App-Assets/A1.png" width="200" height="200" />
<h1 align="center">AirPosture</h1>
<h3 align="center">Turn your AirPods into a posture coach on macOS. A macOS app that uses your AirPods' sensors to catch bad posture in real time.</h3> 
</p>

## Demo

<div align="center">
    <img src="App-Assets/Air.gif" alt="demo" width="700" />
</div>
Sure! Here’s a concise and polished **README** in English summarizing all the steps you performed:

---

## README: How to Set Up and Run the Project on macOS

1. **Install Homebrew (if not already installed):**

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

   Follow the prompts and enter your password when requested.

2. **Add Homebrew to your PATH:**

   ```bash
   echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
   eval "$(/opt/homebrew/bin/brew shellenv)"
   ```

3. **Verify Homebrew installation:**

   ```bash
   brew --version
   ```

4. **Install XcodeGen using Homebrew:**

   ```bash
   brew install xcodegen
   ```

5. **Generate the Xcode project from the project configuration file:**

   ```bash
   xcodegen
   ```

6. **Open the generated Xcode project:**

   ```bash
   open AirPostureApp.xcodeproj
   ```

7. **If prompted, download the required iOS 18.4 simulator in Xcode:**

   * Go to `Xcode → Settings → Components`
   * Download the iOS 18.4 Simulator

8. **Build and run the app in Xcode** by selecting the desired simulator and clicking the **Run** button.



## Acknowledgments

- Built using [headtracker](https://github.com/ctxzz/HeadTrackerApp)
