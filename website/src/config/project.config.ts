import { REPOSITORY_URL as repository, SITE_DESCRIPTION, SITE_NAME } from './branding';

/** Single source of truth for the one project this site presents. */
export const project = {
  name: SITE_NAME,
  eyebrow: 'ANDROID REMOTE FOR FEISHIN',
  headline: 'Your music, from the couch.',
  summary:
    'Feishin Remote turns your Android phone into a remote for the Feishin player on your computer. Browse the library, manage the queue and control playback; the audio keeps playing on your computer.',
  description: SITE_DESCRIPTION,
  repository,
  /** The APK is attached to each GitHub release. */
  downloadUrl: `${repository}/releases/latest`,
  issuesUrl: `${repository}/issues/new`,
  feishinUrl: 'https://github.com/jeffvli/feishin',
  versionLabel: 'Free and open source',
  requirement:
    'Needs Feishin desktop with Remote enabled. Library browsing and queue tools need Feishin 1.16.0 or newer.',
  screenshots: [
    {
      file: 'playing.webp',
      label: 'Now Playing',
      alt: 'Now Playing with artwork, favorite, rating and transport controls',
    },
    {
      file: 'library.webp',
      label: 'Library',
      alt: 'Searchable track list with a mini player and navigation bar',
    },
    {
      file: 'queue.webp',
      label: 'Queue',
      alt: 'The live desktop queue with the current track highlighted',
    },
  ],
  benefits: [
    {
      number: '01',
      icon: 'disc-3',
      title: 'Now Playing',
      description:
        'Artwork, favorites, ratings, volume, shuffle and repeat for whatever your computer is playing.',
    },
    {
      number: '02',
      icon: 'library',
      title: 'Search and browse',
      description:
        'Find tracks, albums, playlists and internet radio, then play now, next or last. Start Track Radio or add songs to a playlist.',
    },
    {
      number: '03',
      icon: 'list-music',
      title: 'Live queue',
      description: 'See the desktop queue, jump to a track, reorder, remove or clear it.',
    },
    {
      number: '04',
      icon: 'smartphone',
      title: 'Android media controls',
      description:
        'Notification, lock screen, headset and Bluetooth buttons control Feishin on your computer.',
    },
    {
      number: '05',
      icon: 'server',
      title: 'Saved servers',
      description:
        'Keep several Feishin computers. Passwords are encrypted with Android Keystore, and dropped connections reconnect on their own.',
    },
    {
      number: '06',
      icon: 'palette',
      title: 'Light and dark themes',
      description: 'Pick a theme and optionally match the accent colour you use in Feishin.',
    },
  ],
  steps: [
    {
      label: 'Enable Remote in Feishin',
      detail:
        'Open Settings → Window, turn on Remote control server, and optionally set a username and password.',
    },
    {
      label: 'Install the app',
      detail: 'Download the APK from the latest release and install it on your Android phone.',
    },
    {
      label: 'Connect',
      detail:
        "Enter your computer's address, such as http://192.168.1.20:4333, save the server and tap Connect.",
    },
  ],
  faqs: [
    {
      question: 'Does music play on my phone?',
      answer:
        'No. Feishin keeps playing on your computer; the app only sends commands to it and shows what is playing.',
    },
    {
      question: 'Which Feishin version do I need?',
      answer:
        'Any version with Remote control server supports basic playback. Browsing, playlists, radio and queue management need Feishin 1.16.0 or newer.',
    },
    {
      question: 'Do my phone and computer need to be on the same network?',
      answer:
        'Yes, the phone must reach the Feishin Remote port, 4333 by default. Use a trusted network, or put Feishin behind an HTTPS proxy you control.',
    },
    {
      question: 'Is it on Google Play?',
      answer:
        'Not yet. Each GitHub release has a signed APK with SHA-256 checksums. Installing a newer APK upgrades the app and keeps your saved servers.',
    },
    {
      question: 'What does the app collect?',
      answer:
        'Nothing. It has no accounts, analytics, advertising or tracking, and it only talks to the Feishin server you enter.',
    },
  ],
} as const;
