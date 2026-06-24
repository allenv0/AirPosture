import DownloadButton from "./DownloadButton";
import Image from "next/image";
import { APP_STORE_LINK } from "../utils/links";
import styles from "../styles/Header.module.css";

function Header() {
  return (
    <header className={styles.header}>
      <a href="/">
        <div className={styles.logo2}>
          <Image alt="" src="/Icon.png" width={128} height={128} />
        </div>
      </a>
      <a href="/">
        <h2 className="silver-gradient-text">AirPosture</h2>
      </a>
      <div className={styles.spacer} />
      <DownloadButton showSubtitle={true} />
    </header>
  );
}

export default Header;
