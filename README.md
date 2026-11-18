# Instagram Clone Flutter App

## Overview
A Flutter social app for Android and the web. Both clients use the same **Veyro Social Platform** Supabase project for accounts, social data, and media.

---

## Features
- User authentication (sign up, login, logout)
- User profiles with bio and profile picture
- Create and browse photo/video posts; like and save posts
- Follow/unfollow users
- Stories (upload, view, progress indicator)
- Real-time chat (DMs)
- Read and manage notifications delivered by the backend
- Explore page (search, trending)
- Favorites (save posts)
- Settings (language, theme, notifications)
- Localization (English/Arabic)
- Error handling, loading indicators, and empty states

---

## Folder Structure
```
lib/
  main.dart
  app.dart
  core/
    constants/
      supabase_constants.dart
      app_constants.dart
      api_constants.dart
    di/
      injection_container.dart
    error/
      failures.dart
      exceptions.dart
    localization/
      localization_helper.dart
      directionality_wrapper.dart
      localization_provider.dart
      app_localization_setup.dart
    usecase/
      usecase.dart
  features/
    activity/
      data/
        activity_repository.dart
      domain/
        entities/
          activity.dart
      presentation/
        screens/
          activity_screen.dart
    arch/
      presentation.zip
    auth/
      data/
      domain/
      presentation/
    chat/
      data/
      domain/
      di/
      presentation/
    common_widgets/
      app_bar.dart
      main_navigation_screen.dart
      user_avatar.dart
      loading_indicator.dart
      error_widget.dart
      empty_state_widget.dart
    explore/
      data/
      domain/
      di/
      presentation/
    favorites/
      data/
      domain/
      di/
      presentation/
    feed/
      data/
      domain/
      di/
      presentation/
    follow/
      data/
      domain/
      presentation/
    notifications/
      data/
        datasources/
          notification_remote_datasource.dart
          notification_remote_datasource_impl.dart
        models/
          notification_model.dart
        repositories/
          notification_repository_impl.dart
      domain/
        entities/
          notification.dart
        repositories/
          notification_repository.dart
        usecases/
          mark_notification_as_read.dart
          delete_notification.dart
          subscribe_to_notifications.dart
          mark_all_notifications_as_read.dart
          get_notifications.dart
      di/
        notification_injection.dart
      presentation/
        bloc/
          notification_event.dart
          notification_state.dart
          notification_bloc.dart
        screens/
          notifications_screen.dart
          notification_screen.dart
        widgets/
          notification_item.dart
    post/
      data/
      domain/
      di/
      presentation/
    profile/
      data/
      domain/
      di/
      presentation/
    settings/
      data/
      domain/
      di/
      presentation/
    story/
      data/
        datasources/
          story_remote_datasource.dart
          story_remote_datasource_impl.dart
        models/
          story_model.dart
        repositories/
          story_repository_impl.dart
      domain/
        entities/
          story.dart
        repositories/
          story_repository.dart
        usecases/
          get_stories.dart
          create_story.dart
          create_story_item.dart
      di/
        story_injection.dart
      presentation/
        bloc/
          story_bloc.dart
          story_event.dart
          story_state.dart
        screens/
          story_view_screen.dart
          create_story_screen.dart
        widgets/
          story_circles_widget.dart
          story_progress_indicator.dart
  generated/
    app_localizations.dart
    app_localizations_en.dart
    app_localizations_ar.dart
  l10n/
    app_en.arb
    app_ar.arb
```

---

## How to Run the Project
1. **Install Flutter** using the version in [`.fvmrc`](.fvmrc) so your local SDK matches CI. Android builds use JDK 21 (required by the Android release lint tooling).
2. **Clone the repository:**
   ```bash
   git clone <repo-url>
   cd instagram_clone
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

Run the same checks as CI from the repository root:

```bash
flutter pub get --enforce-lockfile
git ls-files -z -- '*.dart' | xargs -0 dart format --output=none --set-exit-if-changed
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
```

Flutter generates `lib/generated/` from the translation files in `lib/l10n/` during dependency setup. Edit the `.arb` files rather than the generated Dart files. When changing dependencies or the Flutter version, run `flutter pub get` without `--enforce-lockfile` and commit the resulting `pubspec.lock`.

For deployment, set **Settings → Pages → Build and deployment → Source** to **GitHub Actions**. Pushes to `main` deploy automatically; a manual Pages workflow run from another branch builds the artifact without deploying it.

---

## Veyro Supabase

- **Project:** Veyro Social Platform (`klhczdgjewbmwkktmgzp`). [`SupabaseConstants`](lib/core/constants/supabase_constants.dart) holds the shared project URL and publishable client key. Neither the app nor the website needs a service-role key.
- **Database:** The [Veyro integration migration](supabase/migrations/20261118052414_connect_veyro_clients.sql) is already applied to this project. It extends the existing schema rather than creating a new project or replacing the website/admin tables. Client reads of `public.users` must select specific public columns; the `email` column is not exposed. Chats, messages, saved posts, notifications, and app preferences are scoped to the signed-in user by row-level security.
- **Media:** `profile-images` (5 MiB), `post-media` and `story-media` (50 MiB each) serve public social media. Only signed-in users can upload to their own folders. Story items older than 24 hours are filtered out of the app's story list; that does not delete the uploaded file.
- **Auth:** Email confirmation remains enabled. Allowed signup callbacks include the [GitHub Pages site](https://samarthpathak62-cmyk.github.io/Instagram_colne/), the existing Vercel branch preview, and `com.instagramcolne.veyro://auth-callback/` for Android/iOS. The shared Auth Site URL was left unchanged. Allowlist the exact HTTPS URL for any new deployment under **Authentication → URL Configuration**. Open a web confirmation link on the same browser for automatic sign-in, or sign in manually after confirming.
- **Email delivery:** Veyro has no custom SMTP configured. Supabase's [default SMTP service](https://supabase.com/docs/guides/auth/auth-smtp) is limited to project-team addresses. Configure custom SMTP in Veyro before enabling public signup; do not disable verification to work around it.

### Verify the connection

```bash
python3 tool/check_veyro.py
```

This read-only smoke check uses the same publishable key as the clients and checks Auth settings, real PostgREST projections, and anonymous privacy rules without printing profile data. For an authenticated check, use a confirmed test account: sign in to the Android app and web app with it, publish a small test photo from one, reload the other and check that the same post and profile appear. Use a second test account to verify private message delivery. Remove any disposable content when done.

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
