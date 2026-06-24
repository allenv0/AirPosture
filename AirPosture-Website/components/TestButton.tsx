import testButtonStyles from "../styles/testButton.module.css";

export function TestButton() {
  return (
    <a
      href="https://testflight.apple.com/join/ATvtBUZH"
      target="_blank"
      rel="noopener noreferrer"
      className={testButtonStyles.testButton}
    >
       Download TestFlight
    </a>
  );
};
