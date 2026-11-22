# Yalla Nemshi: where we are (short version)

*Last updated: 22 November 2026. This is the simple version of `HANDOFF.md`.*

## In one paragraph

We spent two sessions (16 and 22 November) testing the app, fixing what was broken,
and making it safer. Most of the core features now work on the **free Firebase plan**.
A few features need the **paid plan**. We'll pay for it when the app is published, and
those features are ready to switch on. Testing is about halfway done.

## What we tested so far

We test in the web browser with two accounts (one normal window, one private window).

| What | Result |
|---|---|
| Create an open walk, others can see it | ✅ Works |
| Create a private walk, strangers can't see it | ✅ Works |
| Join a private walk with an invite code | ✅ Works |
| Make a new invite code | ✅ Works |
| Walk group chat | ✅ Works |
| Review a walk after it ends; host's rating and profile update | ✅ Works (after a fix) |
| Friends, blocking, notifications, profile changes | ⏳ Not tested yet |

## Problems we found and fixed

**Privacy and safety**
- **Everyone could see everyone's email address.** Emails are now hidden from other users.
- Notifications are protected: people can only send them for real events (for
  example, you can't fake a "walk cancelled" message), and blocked people can't send
  you any.

**Things that were broken**
- The **Create Walk** screen crashed because of a leftover tab ("Free walk") that had
  been removed.
- **Editing your profile** (name, bio) only saved on your own phone, so nobody else saw it.
- **The profile page never changed after a walk.** Walks you hosted or joined weren't
  counted once they ended, your total km and badges never updated, the host's rating
  didn't show, and the name said "Your name". Now each person's app records their
  finished walks, and the profile shows the real numbers, name and photo.
- The walk page didn't show **who joined**, only a count. Now it shows names and pictures.
- **Friend profiles** were empty, because they depended on a paid feature. The app now
  builds them by itself.
- There were **no notifications at all**. Now people get them inside the app when
  someone joins or leaves their walk, a walk is cancelled or starts, or a chat message
  or private message arrives.
- **GPS route tracking** had serious problems:
  - it stopped if you stood still for 10 seconds;
  - it couldn't save long walks;
  - it used so much of the database that one or two walks could use up the whole
    day's free limit.

  Now every walker saves their own route, efficiently.
- Some text in the app showed strange symbols (like `â€™` instead of `'`). Fixed.

**Cleaning**
- Photo upload buttons are **hidden for now**, because they need the paid plan. They
  come back with one switch when we pay.
- Removed old, out-of-date documents and **unused code** (old screens and files nothing
  used anymore, about 2,000 lines, plus desktop app folders we don't need). We checked
  carefully: the app is exactly the same as before, just tidier.

## Not working yet, on purpose (needs the paid plan)

- **Phone notifications** (on the lock screen). Right now you only see notifications
  when you open the app.
- **Uploading photos** (walks, chat, reviews).
- **Walks finishing automatically** and the "walk ended" summary message.

All the steps to turn these on are written down in `HANDOFF.md`, in the section
"When upgrading to the paid Blaze plan".

## What's next

1. **Make invite links work.** Hosts can share an invite link, but tapping it doesn't
   open anything yet. Typing the invite code by hand works fine.
2. **Finish testing:** friends, blocking, notifications, profile changes.
3. **Test GPS tracking on a real phone** (it's hard to test on a computer).
4. When everything passes, **save the work into the main version** of the app.
5. Later:
   - make the biggest screens' code simpler, so it's easier to change;
   - protect the Google Maps keys in the Google Cloud settings.

## Decisions we made

- Build for the **free plan now**, with paid features ready to switch on when we publish.
- Notifications are **inside the app only** for now. No pop-ups.
- **Every walker gets their own GPS route** (not just the host).
- **Address search** (typing an address with suggestions) is postponed because it costs
  money per search. People pick the place on the map instead.
- **Offline maps** aren't possible with Google Maps.
