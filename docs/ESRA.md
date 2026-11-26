# Yalla Nemshi: where we are (short version)

*There's also a one-page explainer of the app for anyone new:
`WHAT_IS_YALLA_NEMSHI.md`.*

*Last updated: 24 November 2026. This is the simple version of `HANDOFF.md`.*

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
| Friend requests and friend profiles | ✅ Works |
| Reporting and blocking someone | ✅ Works (after two fixes) |
| Notifications, profile changes, hidden photo buttons | ⏳ Quick re-check still to do |

## Problems we found and fixed

**Privacy and safety**
- **Everyone could see everyone's email address.** Emails are now hidden from other users.
- Notifications are protected: people can only send them for real events (for
  example, you can't fake a "walk cancelled" message), and blocked people can't send
  you any.
- **Blocking didn't really block.** It showed an error, and the blocked person could
  still send you a new friend request. Now a blocked person can't send you friend
  requests or messages. They just see a polite "not accepting" message and aren't
  told they're blocked. (They can still join your public walks. That's on the list.)

**Things that were broken**
- The **Create Walk** screen crashed because of a leftover tab ("Free walk") that had
  been removed.
- **Editing your profile** (name, bio) only saved on your own phone, so nobody else saw it.
- **Starring a walk (☆ "interested") was never saved.** It disappeared every time the
  app restarted. Now it's saved to your account and stays.
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
2. ✅ **All this work is now saved into the main version** of the app (23 November).
3. **New design for the app:** the **home screen is built** in the new style, with a
   light and a dark version (there's now an Appearance switch in Settings). We also
   tested it on 7 phone sizes, from the smallest to the biggest, and with larger
   text settings, and fixed everything that didn't fit. It's now in the
   main version of the app. The **walk page** (what you see when you open a walk) is
   now also redesigned and in the main version. The **create walk** page is
   redesigned too and in the main version. The **walks list** (your walks and
   walks nearby) is redesigned too and in the main version; "My walks" now also
   shows walks you joined, not only ones you host. There's now also a **map of walks**
   (switch between list and map; it also shows the walks you host), using free OpenStreetMap maps for now. Google
   Maps needs a credit card on the account, so **we'll switch back to Google Maps once
   we pay for the plan**. The map is in the main version now. The **profile page**
   is redesigned too (photo, your level, this week's goal, colourful stats, and a tidy
   list of settings at the bottom); it's in the main version now. The **calendar tab** (it used to just say "Coming soon") is now **My
   calendar**: all the walks you host, joined or starred, day by day, with a two-week
   strip at the top. We decided not to build a separate screen for big events for now,
   since a big event is just a walk with more people. Also in the main version. The **chats** (walk group chat and messages with a
   friend) have the new look too, and the group chat now shows **who wrote each
   message**, which it didn't before. Also in the main version. That's all the main
   screens done; the smaller ones (settings, friends, notifications and so on) come next.
4. **Quick re-checks:** notifications, profile changes, hidden photo buttons.
5. **Test GPS tracking on a real phone** (it's hard to test on a computer).
6. Decide what blocking should do for **walks** (for example, hide your walks from
   people you blocked).
7. Later:
   - make the biggest screens' code simpler, so it's easier to change;
   - protect the Google Maps keys in the Google Cloud settings.

## Decisions we made

- Build for the **free plan now**, with paid features ready to switch on when we publish.
- Notifications are **inside the app only** for now. No pop-ups.
- **Every walker gets their own GPS route** (not just the host).
- **Address search** (typing an address with suggestions) is postponed because it costs
  money per search. People pick the place on the map instead.
- **Offline maps** aren't possible with Google Maps.
