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
| **OpenAI key shipped in binary** | Added `openAIChat` callable that proxies OpenAI with a server-side secret. (The app switch to it ships next release — see §2.) | `functions/index.js` |
| **`functions/.env` tracked in git** | Removed from tracking and added to `functions/.gitignore`. (It only held email addresses — no secret leaked — but it shouldn't be tracked.) | `functions/.gitignore` |

### Deploy steps (now)

```bash
# 1. Set the OpenAI secret used by the new proxy
firebase functions:secrets:set OPENAI_API_KEY

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
`on_my_way_notifications` and `reminder_change_notifications` let any signed-in
user create a doc with an arbitrary `recipientEmail`/`senderName`; the Cloud
Functions then deliver that attacker-controlled text as a push. Add a
`senderEmail` field set to the caller's email, require
`request.resource.data.senderEmail == request.auth.token.email` on create, and
have the notification functions ignore/trust it accordingly.

### 3c. All user documents readable
`users` read is `auth != null`, exposing every user's email/name/fcmToken.
Needed for username/email lookups, so it can't be fully closed, but consider
moving friend/user search behind a Cloud Function that returns only the minimal
fields, then restricting direct `users` reads to `auth.email == resource.email`.

### 3d. Logo.dev **secret** key still in the binary
`StoreLogoProvider.swift` still reads `LOGO_DEV_SECRET_KEY` from `Info.plist`
for the Brand Search API. (The `LOGO_DEV_TOKEN` is a *publishable* token and is
fine to embed.) Lower value than the OpenAI key, but the correct fix is the same
pattern: a small `logoBrandSearch` Cloud Function holding the secret, with the
app calling it instead. Rotate the secret afterward.

---

## Quick reference — files changed in this pass

- `firestore.rules` — sender check + stores lockdown (deploy now)
- `firestore.rules.pending` — strict messaging read-privacy rules (deploy after §2)
- `functions/index.js` — `openAIChat` proxy + `backfillMessagingIdentity`
- `functions/.gitignore` — ignore `.env`
- `Geolocation_v1.0.0/Services/OpenAIService.swift` — use proxy
- `Geolocation_v1.0.0/Services/MessagingService.swift` — write `participantEmails`
- `Geolocation_v1.0.0/Info.plist` — drop embedded `OPENAI_API_KEY`
- `Secrets.xcconfig.template` — drop `OPENAI_API_KEY`, annotate Logo.dev keys
