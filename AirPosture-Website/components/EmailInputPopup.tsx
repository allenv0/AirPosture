import { useState, useEffect } from 'react';
import styles from '../styles/EmailInputPopup.module.css';

interface EmailInputPopupProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (email: string) => void;
}

function EmailInputPopup({ isOpen, onClose, onSubmit }: EmailInputPopupProps) {
  const [email, setEmail] = useState('');
  const [isValid, setIsValid] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);

  useEffect(() => {
    if (isOpen) {
      setEmail('');
      setIsValid(true);
      setIsSubmitting(false);
      setIsSuccess(false);
    }
  }, [isOpen]);

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };

    if (isOpen) {
      document.addEventListener('keydown', handleEscape);
      document.body.style.overflow = 'hidden';
    }

    return () => {
      document.removeEventListener('keydown', handleEscape);
      document.body.style.overflow = 'unset';
    };
  }, [isOpen, onClose]);

  const validateInput = (input: string) => {
    return input.trim().length > 0;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!validateInput(email)) {
      setIsValid(false);
      return;
    }

    setIsSubmitting(true);
    
    try {
      await onSubmit(email);
      setIsSuccess(true);
      setTimeout(() => {
        onClose();
      }, 2000);
    } catch (error) {
      setIsValid(false);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleEmailChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setEmail(e.target.value);
    if (!isValid) {
      setIsValid(true);
    }
  };

  if (!isOpen) return null;

  return (
    <div className={styles.overlay}>
      <div className={styles.popup}>
        <button className={styles.closeButton} onClick={onClose} aria-label="Close">
          ×
        </button>
        
        <div className={styles.content}>
          <h2 className={styles.title}>
            Join Waitlist
          </h2>
          <p className={styles.description}>
            Public beta is full. Leave your email and I'll invite you when a spot opens up.
          </p>
          
          {!isSuccess ? (
            <form onSubmit={handleSubmit} className={styles.form} noValidate>
              <div className={styles.inputGroup}>
                <input
                  type="email"
                  value={email}
                  onChange={handleEmailChange}
                  placeholder="Enter your email"
                  className={`${styles.emailInput} ${!isValid ? styles.error : ''}`}
                  disabled={isSubmitting}
                  autoFocus
                />
                  {!isValid && (
                    <span className={styles.errorMessage}>
                      Please enter your email to join the waitlist
                    </span>
                  )}
              </div>
              
              <button
                type="submit"
                className={styles.submitButton}
                disabled={isSubmitting || !email.trim()}
              >
                {isSubmitting ? 'Joining...' : 'Join Waitlist'}
              </button>
            </form>
          ) : (
            <div className={styles.successMessage}>
              <div className={styles.successIcon}>✓</div>
              <h3>You're on the waitlist!</h3>
              <p>We'll send you updates and an invitation as soon as spots open up.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default EmailInputPopup;