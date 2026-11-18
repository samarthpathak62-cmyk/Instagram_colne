#!/usr/bin/env python3
"""Read-only smoke check of the public client contract; no user or admin key."""

import json
import re
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


CONSTANTS = (
    Path(__file__).resolve().parents[1]
    / "lib/core/constants/supabase_constants.dart"
).read_text()
URL = re.search(r"supabaseUrl\s*=\s*'([^']+)'", CONSTANTS)[1]
KEY = re.search(r"supabasePublishableKey\s*=\s*'(sb_publishable_[^']+)'", CONSTANTS)[1]
PUBLIC_USER = "id,username,profile_picture_url"
POST = (
    "id,author_id,type,media_urls,description,caption,created_at,"
    f"author:users!posts_author_id_fkey({PUBLIC_USER}),likes(count),comments(count)"
)


def get(label, path, query=None, *, expected=200):
    suffix = f"?{urlencode(query)}" if query else ""
    # The locked Flutter SDK supplies the publishable key in both headers
    # until a signed-in user's access token replaces the Bearer value.
    request = Request(
        f"{URL}{path}{suffix}",
        headers={"apikey": KEY, "Authorization": f"Bearer {KEY}"},
    )
    try:
        with urlopen(request, timeout=15) as response:
            if response.status != expected:
                raise RuntimeError(f"{label}: expected HTTP {expected}; got {response.status}")
            result = json.load(response)
    except HTTPError as error:
        if error.code != expected:
            result = json.loads(error.read())
            # Only report the API error code, not user data or response content.
            raise RuntimeError(f"{label}: HTTP {error.code}, API code {result.get('code')}") from None
        result = None
    except URLError as error:
        raise RuntimeError(f"{label}: Supabase endpoint unreachable ({error.reason})") from None
    print(f"{label}: HTTP {expected}")
    return result


def rest(label, table, fields, **filters):
    return get(label, f"/rest/v1/{table}", {"select": fields, "limit": 1, **filters})


def main():
    settings = get("Veyro Auth settings", "/auth/v1/settings")
    if not settings.get("external", {}).get("email"):
        raise RuntimeError("Veyro does not have email auth enabled")
    rest(
        "Profiles with follower and post counts",
        "users",
        "id,username,full_name,bio,profile_picture_url,posts(count),"
        "followers:followers!followers_following_id_fkey(count),"
        "following:followers!followers_follower_id_fkey(count)",
    )
    rest("Legacy feed and explore post projection", "posts", POST)
    rest(
        "Posts with group and reaction information",
        "posts",
        f"{POST},group_id,group:veyro_groups(name),reaction_counts:veyro_reaction_counts(reaction,total)",
    )
    rest("Public groups directory", "veyro_groups", "id,name,category")
    get(
        "Group membership details require sign-in",
        "/rest/v1/veyro_group_members",
        {"select": "group_id,user_id", "limit": 0},
        expected=401,
    )
    rest(
        "Posts with viewer-like embed",
        "posts",
        f"{POST},liked_by_user:likes(user_id)",
        **{"liked_by_user.user_id": "eq.00000000-0000-0000-0000-000000000000"},
    )
    rest(
        "Stories with media and author",
        "stories",
        f"user_id,author:users!stories_user_id_fkey({PUBLIC_USER}),"
        "items:story_items!inner(id,media_url,media_type,created_at)",
    )
    get("Profile email is not public", "/rest/v1/users", {"select": "email", "limit": 0}, expected=401)
    private = {
        "saved_posts": f"id,post:posts({POST})",
        "chats": f"id,first_user:users!chats_user1_id_fkey({PUBLIC_USER}),"
                 f"second_user:users!chats_user2_id_fkey({PUBLIC_USER}),unread:messages(count)",
        "messages": "id",
        "notifications": "id",
    }
    for table, fields in private.items():
        if rest(f"Anonymous {table} access", table, fields) != []:
            raise RuntimeError(f"Anonymous response returned private rows from {table}")
    get("Per-user settings are not public", "/rest/v1/settings", {"select": "id", "limit": 0}, expected=401)
    print("Veyro Auth, REST embeds and anonymous access checks passed.")


if __name__ == "__main__":
    main()
