# Security Remediation

Tracking doc for the security review of NotifiApp (Allim). Findings are grouped
by what has been **fixed & is safe to deploy now**, what is **staged for the
next app release**, and what remains **open**.

The overarching problem: Firestore security rules are the only real trust
boundary (any client can bypass the app and hit Firestore directly), but the
data model keys identity on **usernames**, while rules can only check the
authenticated **email**. Several collections therefore gated everything on
"is signed in" ≈ "anybody with an account."

---

## 1. Fixed — safe to deploy now (no app release required)

These are in `firestore.rules` and `functions/index.js` and can be deployed
independently of any app update.

| Area | Change | File |
|------|--------|------|
| **Message sender spoofing** | `messages` create now requires `get(users/{senderId}).email == auth.email`, so a user can't forge messages as someone else. Uses the same username→email lookup the `favorite_tags` rules already rely on. | `firestore.rules` |
| **Global store catalog vandalism** | `stores` create/update/delete locked to the owner email. The app only ever *reads* this collection, so this is non-breaking. | `firestore.rules` |
| **Store logo vandalism** | `stores_logos` create/update/delete locked to the owner email (previously any authenticated user could write, and the collection is global — a logo shows for every user with that store). The app only *reads* it (`uploadStoreLogo`/`deleteStoreLogo` are owner/admin seed tools, never called from the app UI), so this is non-breaking. Mirrored in `firestore.rules.pending`. | `firestore.rules` |
| **OpenAI key shipped in binary** | Added `openAIChat` callable that proxies OpenAI with a server-side secret. (The app switch to it ships next release — see §2.) | `functions/index.js` |
| **Logo.dev secret key could ship in binary** | `Info.plist` referenced `$(LOGO_DEV_SECRET_KEY)`, so the secret would embed in the binary if ever populated. Added `logoBrandSearch` callable that proxies the Logo.dev Brand Search API with a server-side secret, and dropped the `Info.plist` reference. (In practice the secret was never set locally, so none shipped — see §2a-2. The publishable `LOGO_DEV_TOKEN` stays embedded — it's safe.) | `functions/index.js` |
| **`functions/.env` tracked in git** | Removed from tracking and added to `functions/.gitignore`. (It only held email addresses — no secret leaked — but it shouldn't be tracked.) | `functions/.gitignore` |

### Deploy steps (now)

```bash
# 1. Set the secrets used by the new proxies
firebase functions:secrets:set OPENAI_API_KEY
firebase functions:secrets:set LOGO_DEV_SECRET_KEY

# 2. Deploy rules + functions
firebase deploy --only firestore:rules,functions
```

> **Note on the `stores` lockdown:** if you have an admin/seed tool that writes
> the catalog while signed in as a *non-owner* account, it will now be denied.
> The app itself does not write `stores`, so normal users are unaffected.

---

## 2. Staged — code is on the branch, ships with the next app build

The read-privacy fixes need the app to start writing identity fields, so they
can't deploy until a new build is live. All the code is prepared:

### 2a. OpenAI proxy — client switch
- `OpenAIService.swift` now calls the `openAIChat` Cloud Function instead of
  hitting OpenAI directly. The `OPENAI_API_KEY` entry was removed from
  `Info.plist` so it's no longer embedded in the binary.
- **After the new build is live: rotate the old OpenAI key** — treat any key
  previously shipped in the app as compromised. Also delete `OPENAI_API_KEY`
  from your local `Secrets.xcconfig`.

### 2a-2. Logo.dev Brand Search proxy — client switch
- `StoreLogoProvider.swift` now calls the `logoBrandSearch` Cloud Function
  instead of hitting `api.logo.dev/search` directly with the secret. The
  `LOGO_DEV_SECRET_KEY` entry was removed from `Info.plist` so it can never be
  embedded in the binary. The publishable `LOGO_DEV_TOKEN` stays (safe to embed).
- **Note:** `LOGO_DEV_SECRET_KEY` was never actually populated in
  `Secrets.xcconfig`, so `$(LOGO_DEV_SECRET_KEY)` resolved to an empty string and
  no secret was ever shipped — **nothing to rotate here.** A side effect is that
  the Brand Search fallback (the catch-all for stores not in the built-in domain
  map) was silently disabled. Setting the secret server-side
  (`firebase functions:secrets:set LOGO_DEV_SECRET_KEY`) is what turns that
  fallback on — now routed securely through the proxy.

### 2b. Messaging read-privacy (`participantEmails`)
- `MessagingService.swift` now writes a `participantEmails` array on
  conversation create, and keeps it in sync on member add/remove
  (`resolveParticipantEmails`).
- The strict rules that consume it live in **`firestore.rules.pending`** (a
  complete, deployable rules file — not yet wired into `firebase.json`).

**Cutover order (do NOT skip step order or messaging breaks on old builds):**

1. Ship the app build containing the `MessagingService` changes; wait until
   ~all active users have updated.
2. Backfill existing conversations (once, from the owner account):
   ```
   Functions.functions().httpsCallable("backfillMessagingIdentity")()
   ```
   Returns `{ updated, skipped, total }`. Idempotent — safe to re-run.
3. Swap the strict rules in and deploy:
   ```bash
   # point firebase.json -> firestore.rules at firestore.rules.pending
   # (or copy its contents over firestore.rules), then:
   firebase deploy --only firestore:rules
   ```

### 2c. Notification sender verification (`senderEmail`) — push spoofing fix

Closes §3b below. Staged the same way as 2b:

- `OnMyWayNotificationService.swift` and `SharedReminderNotificationService.swift`
  now write a `senderEmail` field (the Firebase Auth email) on every
  notification doc they create.
- **Live `firestore.rules`** (deployable now, backward compatible): when
  `senderEmail` is present on create it must equal `request.auth.token.email`;
  docs without it (legacy builds) are still accepted.
- `functions/index.js`: `onMyWayNotification` / `sharedReminderNotification`
  now resolve the sender's display name from the `users` collection via the
  verified `senderEmail` (`resolveSenderName`) instead of trusting the
  client-supplied `senderName`; the client value is only a fallback for
  legacy docs.
- **`firestore.rules.pending`** now *requires* `senderEmail` on create for
  both collections. This adds deploy precondition 3 to the pending file: the
  build writing `senderEmail` must be adopted first, or older builds will be
  unable to send these notifications.

Net effect: as soon as the new build + live rules are out, a spoofed push can
no longer carry an arbitrary sender identity through new-format docs, and the
push body uses a server-verified name. Full enforcement (rejecting legacy
no-`senderEmail` docs) lands with the pending rules cutover.

---

## 3. Still open — needs design/app work (documented, not yet coded)

These were left as follow-ups because a correct fix requires data-model changes
beyond the messaging work above.

### 3a. Reminders are world-readable / world-writable
`reminders` read/update/delete are still `auth != null`. They can't be locked
down cleanly today because shared-store recipients reference the **owner's**
`user_store` id (`sourceUserStoreId`), so ownership isn't derivable in rules.

**Recommended fix:** denormalize an `ownerEmail` (and, for "can edit" shares,
an `editorEmails` array) onto each reminder at write time. Then:
- `read`: `auth.email == ownerEmail || auth.email in editorEmails`
- `update/delete`: same, scoped to editors.
This touches the reminder create/share paths in `StoresViewModel` /
`MessagingService` and needs a backfill, similar to §2b.

### 3b. Notification create is unauthenticated-sender (push spoofing)
**Fixed — staged as §2c.** The app now writes `senderEmail`, live rules verify
it when present, the Cloud Functions resolve the sender name from it, and the
pending rules require it outright. Fully closed once the §2c build is adopted
and `firestore.rules.pending` is deployed.

### 3c. All user documents readable
`users` read is `auth != null`, exposing every user's email/name/fcmToken.
Needed for username/email lookups, so it can't be fully closed, but consider
moving friend/user search behind a Cloud Function that returns only the minimal
fields, then restricting direct `users` reads to `auth.email == resource.email`.

### 3d. Logo.dev **secret** key in the binary
**Fixed — staged as §2a-2.** Added the `logoBrandSearch` Cloud Function (holds
the secret server-side), switched `StoreLogoProvider.swift` to call it, and
removed `LOGO_DEV_SECRET_KEY` from `Info.plist`. (The `LOGO_DEV_TOKEN` is a
*publishable* token and stays embedded.) In practice the secret was never
populated in `Secrets.xcconfig`, so nothing was actually shipped or needs
rotating — the proxy simply lets the Brand Search fallback run securely if the
secret is set server-side.

---

## Quick reference — files changed in this pass

- `firestore.rules` — sender check + stores lockdown + `stores_logos` lockdown (deploy now)
- `firestore.rules.pending` — strict messaging read-privacy rules + `stores_logos` lockdown (deploy after §2)
- `functions/index.js` — `openAIChat` + `logoBrandSearch` proxies + `backfillMessagingIdentity`
- `functions/.gitignore` — ignore `.env`
- `Geolocation_v1.0.0/Services/OpenAIService.swift` — use proxy
- `Geolocation_v1.0.0/Services/StoreLogoProvider.swift` — use `logoBrandSearch` proxy
- `Geolocation_v1.0.0/Services/MessagingService.swift` — write `participantEmails`
- `Geolocation_v1.0.0/Info.plist` — drop embedded `OPENAI_API_KEY` + `LOGO_DEV_SECRET_KEY`
- `Secrets.xcconfig.template` — drop `OPENAI_API_KEY` + `LOGO_DEV_SECRET_KEY`, annotate Logo.dev token
