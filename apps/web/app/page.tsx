import { APP_NAME } from '@bookclass/shared';

export default function HomePage() {
  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', padding: '2rem' }}>
      <h1>{APP_NAME}</h1>
      <p>Customer and admin surfaces land here.</p>
    </main>
  );
}
