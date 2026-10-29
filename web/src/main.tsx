import '@fontsource-variable/fraunces/opsz.css';
import '@fontsource-variable/instrument-sans';
import '@fontsource-variable/jetbrains-mono';
import './index.css';
import { MotionConfig } from 'framer-motion';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { Landing } from './landing/Landing';
import { Try } from './Try';

// Two routes, no router: vercel.json serves index.html at /try too.
const Page = location.pathname.replace(/\/$/, '') === '/try' ? Try : Landing;

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <MotionConfig reducedMotion="user">
      <Page />
    </MotionConfig>
  </StrictMode>,
);
