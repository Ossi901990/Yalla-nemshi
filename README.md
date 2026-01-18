# yalla_nemshi

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# Yalla Nemshi

A social walking app that helps users organize, join, and manage walks
with strong privacy and community-focused design.
Private Walks & Invite System
Overview

Yalla Nemshi supports Open and Private point-to-point walks.
Privacy is enforced at the database level (Firestore rules), not only in the UI.

This ensures that private walks remain inaccessible even if someone:

guesses a walk ID

inspects network traffic

tries to query Firestore directly

Walk Visibility Modes
Open Walk

Visible in Nearby Walks

Users can request to join

Host must approve requests

Private Walk

Not visible anywhere in the app

Only the host and explicitly allowed users can view the walk

Enforced using Firestore Security Rules

Phase 1: NoBlaze (Testing Phase – No Billing)
Why this phase

Avoid enabling billing during early testing

Keep backend simple

Still enforce real privacy

How privacy works

Firestore rules allow reading a walk only if:

the user is the host, or

the user has an access document at
/walks/{walkId}/allowed/{uid}

This means private walks are truly private, not just hidden in the UI.

Invite flow (NoBlaze)

Since Cloud Functions are not used in this phase, invites are manual:

Invitee copies their User UID from their profile

Invitee sends UID to host (WhatsApp, message, etc.)

Host pastes UID into the walk’s Invite section

App writes:

/walks/{walkId}/allowed/{inviteeUid}


Invitee gains access instantly

Pros (NoBlaze)

✅ No billing required

✅ Strong privacy

✅ Simple setup

✅ Ideal for testing

Cons (NoBlaze)

❌ No “tap to join” from WhatsApp/QR

❌ Manual invite approval

Phase 2: Blaze (Production Phase – Billing Enabled)
Why upgrade later

To provide a smoother user experience:

Share via WhatsApp or QR

Tap link → instant access

No UID sharing needed

Planned Blaze invite flow

Host creates private walk → share code/link generated (expires after 7 days)

Host shares link via WhatsApp / QR

Invitee taps link

App calls Cloud Function:

redeemInviteCode(walkId, shareCode)


Function verifies invite, checks expiry, and writes:

/walks/{walkId}/allowed/{inviteeUid}


Firestore rules allow access

Benefits (Blaze)

✅ Best UX

✅ Still truly private

✅ Supports invite expiry, limits, logging

Migration note

The security model does not change between NoBlaze and Blaze.
Only the way allowed users are added changes.

This allows safe migration at any time.

🔐 Version 2 — Security & Privacy Section (Formal / Report-ready)
Security Model for Private Walks
Design Principle

Private walks must remain inaccessible to unauthorized users even if application-level controls fail. Therefore, access control is enforced using Firestore Security Rules, not UI logic.

Data Access Rules

A walk document can be read only if:

the requester is authenticated, and

one of the following is true:

the walk is open

the requester is the walk host

the requester is listed under
/walks/{walkId}/allowed/{uid}

This prevents unauthorized access via:

direct Firestore queries

guessed document IDs

intercepted network requests

Invite Handling (Testing Phase)

During testing, automated invite redemption is disabled to avoid backend billing.

Access is granted manually by the host through:

copying a user’s UID

writing an allowed access document

This approach maintains strong security while reducing infrastructure complexity.

Future Enhancement (Production Phase)

In production, invite redemption will be handled via a server-side Cloud Function using Firebase Admin SDK. This enables:

secure invite code verification

automated access granting

enhanced audit and control features

Security Guarantees

Private walks are not discoverable

Access is explicitly granted and revocable

Chat access remains restricted to confirmed participants

Security does not rely on obscurity or client-side enforcement