export default function SupportPage() {
  return (
    <div className="min-h-screen bg-allim-dark text-white">
      <main className="max-w-3xl mx-auto px-6 py-16">
        <a
          href="/"
          className="inline-block text-sm text-allim-muted hover:text-white transition-colors mb-8"
        >
          ← Back to Home
        </a>

        <h1 className="text-3xl md:text-4xl font-bold mb-4">Allim Support</h1>
        <p className="text-allim-muted mb-8">
          Need help with Allim? We&apos;re here for you.
        </p>

        <p className="text-allim-muted mb-8">
          Allim (from the Korean word for &ldquo;alarm&rdquo;) helps you save
          stores, create reminders, and receive alerts when you&apos;re nearby
          so you never forget what to do or buy.
        </p>

        <section className="mb-10">
          <h2 className="text-2xl font-semibold mb-3">Contact Support</h2>
          <ul className="list-disc pl-6 text-allim-muted space-y-2">
            <li>
              <strong className="text-white">Email:</strong>{" "}
              <a
                href="mailto:jjamesubongdev@gmail.com"
                className="hover:text-white underline"
              >
                jjamesubongdev@gmail.com
              </a>
            </li>
            <li>
              <strong className="text-white">Response time:</strong> We
              typically respond within 24-72 hours
            </li>
          </ul>
        </section>

        <section className="mb-10">
          <h2 className="text-2xl font-semibold mb-3">Common Help Topics</h2>

          <h3 className="text-lg font-semibold mt-6 mb-2">
            1) Nearby alerts are not working
          </h3>
          <p className="text-allim-muted mb-2">Please check:</p>
          <ul className="list-disc pl-6 text-allim-muted space-y-1">
            <li>
              Location permission is set to <strong>Always</strong> (or allowed
              in background)
            </li>
            <li>
              <strong>Precise Location</strong> is enabled (recommended)
            </li>
            <li>Notifications are enabled for Allim</li>
            <li>
              Low Power Mode or Focus settings are not suppressing notifications
            </li>
            <li>
              You are within a reasonable distance of the saved store location
            </li>
          </ul>

          <h3 className="text-lg font-semibold mt-6 mb-2">
            2) I&apos;m not receiving reminder notifications
          </h3>
          <ul className="list-disc pl-6 text-allim-muted space-y-1">
            <li>
              Open iOS Settings → Notifications → Allim → Allow Notifications
            </li>
            <li>Restart the app after enabling permissions</li>
            <li>Make sure reminder details are saved correctly</li>
          </ul>

          <h3 className="text-lg font-semibold mt-6 mb-2">
            3) Store location seems incorrect
          </h3>
          <ul className="list-disc pl-6 text-allim-muted space-y-1">
            <li>Edit and re-save the store pin/address</li>
            <li>Confirm map/location access is enabled</li>
            <li>Move closer to the destination and try again</li>
          </ul>

          <h3 className="text-lg font-semibold mt-6 mb-2">
            4) Shared reminders/lists are out of sync
          </h3>
          <ul className="list-disc pl-6 text-allim-muted space-y-1">
            <li>Check internet connection on all devices</li>
            <li>Close and reopen the app</li>
            <li>Ensure all collaborators are using the latest app version</li>
          </ul>
        </section>

        <section className="mb-10">
          <h2 className="text-2xl font-semibold mb-3">Troubleshooting Steps</h2>
          <p className="text-allim-muted mb-3">
            Before contacting support, please try:
          </p>
          <ol className="list-decimal pl-6 text-allim-muted space-y-1">
            <li>Update Allim to the latest version</li>
            <li>Restart your device</li>
            <li>Reopen Allim and test again</li>
          </ol>
        </section>

        <section className="mb-10">
          <h2 className="text-2xl font-semibold mb-3">Contacting Us</h2>
          <p className="text-allim-muted mb-3">
            When you email support, include:
          </p>
          <ul className="list-disc pl-6 text-allim-muted space-y-1">
            <li>Device model (e.g., iPhone 15)</li>
            <li>iOS version</li>
            <li>App version</li>
            <li>A short description of the issue</li>
            <li>Screenshots (if possible)</li>
          </ul>
          <p className="text-allim-muted mt-3">
            This helps us resolve your issue faster.
          </p>
        </section>

        <section className="mb-10">
          <h2 className="text-2xl font-semibold mb-3">Privacy</h2>
          <p className="text-allim-muted">
            For information on how we handle data, please visit our Privacy
            Policy:{" "}
            <a
              href="https://github.com/kor3a/allim-privacy-policy"
              target="_blank"
              rel="noopener noreferrer"
              className="hover:text-white underline"
            >
              Privacy Policy
            </a>
          </p>
        </section>
      </main>
    </div>
  );
}
