import { PropsWithChildren } from 'react';
import styles from '../styles/Base.module.css'

function Base(props:
     PropsWithChildren<{}>) {
    const {children} = props;
    return (
        <div className={styles.base}>
            <div className={styles.page}>
                {children}
            </div>
        </div>
    )
}

export default Base;
