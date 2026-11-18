# Veyro

## Overview
Veyro is a Flutter social app for Android and the web. Both clients use the same **Veyro Social Platform** Supabase project for accounts, social data, and media.

The orbit-V logo and violet palettes are shared across the website and app. The vector master is [`assets/brand/veyro_mark.svg`](assets/brand/veyro_mark.svg). To regenerate the launcher, splash, and browser icons, install `Pillow` and `resvg-py` and run `python3 tool/generate_veyro_icons.py`. Manrope is bundled locally under its [SIL Open Font License](assets/fonts/manrope/OFL.txt). Existing application IDs, web paths, and sign-in callbacks are unchanged.

---

## Social features

- **Home:** Compact story rings and Text, Photo, and Reel composer shortcuts sit above the feed. Latest is chronological. Following includes people you follow plus your posts, and keeps the last visible posts on a failed refresh. Wide layouts include a discovery panel with topics found in the loaded feed.
- **Post actions:** Like, save, write or delete your own comments, and share a post by link or direct message. Repost once to your timeline, undo a repost, or publish a quote with your own text. Quotes link back to the original and keep your text if the original is deleted. Post owners can edit the text or delete the post. Saved posts are private and can be sorted or removed.
- **Reels and stories:** Browse real video posts vertically in Reels, with next/previous buttons on desktop. Add image or video stories, navigate or pause playback, and see which story items you've viewed in the current app session.
- **Explore and profiles:** Search post text and usernames. View profile text/photo/video filters and follower/following lists. Follow or message another person from their profile.
- **Messages and activity:** Start a conversation from the inbox. Visible chats refresh periodically if realtime delivery is unavailable. A shared Veyro post opens directly in the app from a message. New follows, likes and comments generate **in-app** activity; open, mark read, or dismiss it. This does not send push notifications.
- **Accounts:** Sign up, log in, edit your profile, and change theme/language and activity preferences. Veyro uses its own accounts; it does not import accounts or feeds from other networks.

Feature code is under `lib/features/` with data, domain and presentation layers. Shared navigation and branding sit in `lib/features/common_widgets/`. Flutter integration, browser smoke tests and database checks are in `test/` and `tool/`.

## How to Run the Project
1. **Install Flutter** using the version in [`.fvmrc`](.fvmrc) so your local SDK matches CI. Android builds use JDK 21 (required by the Android release lint tooling).
2. **Clone the repository:**
   ```bash
   git clone <repo-url>
   cd Instagram_colne
   ```
3. **Install dependencies:**
   ```bash
   flutter pub get --enforce-lockfile
   ```
4. **Run the Android app or the website.** Both are already configured for Veyro:
   ```bash
   flutter run
   # Web: use the fixed origin configured for local development in Veyro Auth.
   flutter run -d chrome --web-hostname localhost --web-port 3000
   ```

---

## CI and GitHub Pages

Run the Flutter checks from the repository root:

```bash
flutter pub get --enforce-lockfile
git ls-files -z -- '*.dart' | xargs -0 dart format --output=none --set-exit-if-changed
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
```

CI exercises signed-in interactions in desktop and mobile Chrome against a fixture backend and checks the same REST projections in a disposable Postgres + PostgREST instance, including the old APK’s Following request, viewer flags, quotes and repost ownership. The suites do not create live accounts or content. To run the isolated SQL suite separately:

```bash
npm install --no-save --prefix /tmp/veyro-sql @electric-sql/pglite@0.5.16
NODE_PATH=/tmp/veyro-sql/node_modules node tool/test_social_schema.cjs
```

Flutter generates `lib/generated/` from the translation files in `lib/l10n/` during dependency setup. Edit the `.arb` files rather than the generated Dart files. When changing dependencies or the Flutter version, run `flutter pub get` without `--enforce-lockfile` and commit the resulting `pubspec.lock`.

For deployment, set **Settings → Pages → Build and deployment → Source** to **GitHub Actions**. Pushes to `main` deploy automatically; a manual Pages workflow run from another branch builds the artifact without deploying it.

---

## Veyro Supabase

- **Project:** Veyro Social Platform (`klhczdgjewbmwkktmgzp`). [`SupabaseConstants`](lib/core/constants/supabase_constants.dart) holds the shared project URL and publishable client key. Neither the app nor the website needs a service-role key.
- **Database:** The [Veyro integration migration](supabase/migrations/20261118052414_connect_veyro_clients.sql) is already applied to this project. The [social actions migration](supabase/migrations/20261118064846_veyro_social_actions.sql) is also applied; it adds the server-filtered Following timeline, owner-only comment deletion, text validation, and in-app activity triggers. The [Following compatibility patch](supabase/migrations/20261118072705_veyro_following_rest.sql) fixes embedded viewer filters on the old RPC used by installed APKs and gives new builds a security-invoker view. The [post shares migration](supabase/migrations/20261118073110_veyro_post_shares.sql) adds original-post references, duplicate repost protection and shallow previews. All are applied to the shared project; none replaces the website/admin tables. Client reads of `public.users` must select specific public columns; the `email` column is not exposed. Chats, messages, saved posts, notifications, and app preferences are scoped to the signed-in user by row-level security.
- **Media:** `profile-images` (5 MiB), `post-media` and `story-media` (50 MiB each) serve public social media. Only signed-in users can upload to their own folders. Story items older than 24 hours are filtered out of the story list. Story expiry and deleting a post do not currently purge the storage object.
- **Auth:** Email confirmation remains enabled. Allowed signup callbacks include the [GitHub Pages site](https://samarthpathak62-cmyk.github.io/Instagram_colne/), the existing Vercel branch preview, and `com.instagramcolne.veyro://auth-callback/` for Android/iOS. The shared Auth Site URL was left unchanged. Allowlist the exact HTTPS URL for any new deployment under **Authentication → URL Configuration**. Open a web confirmation link on the same browser for automatic sign-in, or sign in manually after confirming.
- **Email delivery:** Veyro has no custom SMTP configured. Supabase's [default SMTP service](https://supabase.com/docs/guides/auth/auth-smtp) is limited to project-team addresses. Configure custom SMTP in Veyro before enabling public signup; do not disable verification to work around it.

### Verify the connection

```bash
python3 tool/check_veyro.py
```

This read-only smoke check uses the same publishable key as the clients and checks Auth settings, real PostgREST projections, and anonymous privacy rules without printing profile data. For an authenticated check, use a confirmed test account: sign in to the Android app and web app with it, publish a small test photo from one, reload the other and check that the same post and profile appear. Use a second confirmed test account to verify follows, activity delivery and private messages; check that shared links open the right post after sign-in. Remove any disposable content when done.

### Vercel

The existing `instagram_colne-web` project uses `web` as its Root Directory. Keep **Include source files outside of the Root Directory** enabled, so [`web/vercel.json`](web/vercel.json) can run the [pinned Flutter build](tool/build_vercel.sh) and deploy `web/dist`. Do not deploy the uncompiled `web/` source directory. Add the exact production origin (including its trailing slash) to Veyro's Auth redirect allowlist if it differs from the allowed URLs above.

---

## Main Technologies
- **Flutter** (UI, navigation, state management)
- **Bloc** (business logic, state)
- **Supabase** (PostgreSQL, Auth, Storage, Realtime)
- **Dart** (language)
- **Localization** (arb, intl)

---

## Special Notes
- The codebase follows Clean Architecture (data/domain/presentation)
- Each feature is in its own folder for modularity
- Supports multiple languages (en/ar)
- Easily extensible and customizable
- You can add new features easily by creating a new folder in features

---

## Contact
For any questions or further development, contact the maintainer or open an Issue in the repository.
