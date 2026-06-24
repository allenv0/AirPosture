import { APP_STORE_LINK } from "../utils/links";
import styles from "../styles/Home.module.css";

const TESTFLIGHT_LINK = "https://testflight.apple.com/join/ATvtBUZH";

interface DownloadButtonProps {
  onClick?: () => void;
  href?: string;
  showSubtitle?: boolean;
}

function DownloadButton({ onClick, href, showSubtitle }: DownloadButtonProps) {
  const link = href || TESTFLIGHT_LINK;

  return (
    <div
      style={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: "4px",
      }}
    >
      <a
        href={link}
        target="_blank"
        rel="noopener noreferrer"
        className={styles.downloadIcon}
      >
         Download iOS Beta
      </a>
    </div>
  );
}

export default DownloadButton;
